if BACstack.MixProject.sc_enabled?() do
  defmodule BACnet.Stack.Transport.ScTransport.Management do
    @moduledoc """
    Handles confirmed BACnet management requests for a Secure Connect port.

    The managed port passes inbound confirmed APDUs and their reply references
    to `request/4`. The handler decodes the service using the BACstack service
    codecs and sends responses through the owning client. This preserves the
    request's invoke ID and the reply route, including for segmented responses.
    Who-Is and I-Am are handled by the managed port itself.

    ## Reading objects and authorizing changes

    ReadProperty and ReadPropertyMultiple expose the Device, Network Port,
    and certificate File objects. Network Port reads combine the port's
    configured properties with observations from the running connector and
    local hub. The handler encodes current connection status, peer information,
    recent inbound connection failures, and the validation result for pending
    settings and credentials as BACnet property values. ReadPropertyMultiple
    can return a property-level error alongside other values from the same request.
    For an unknown object, these errors identify the explicitly requested
    properties. A selector-only reference to an unknown object is omitted from
    a mixed acknowledgment. If every reference is of this kind, the service
    returns an `:unknown_object` error.

    The port's authorization function must return `true` for property writes,
    ReinitializeDevice operations, and access to certificate file contents.
    The function receives the decoded service and the source VMAC and network
    address available from the received frame. The TLS certificate on the
    managed port's node connection authenticates its hub. Site authorization
    needs to account for that forwarding relationship.

    ## Staging, certificate enrollment, and activation

    `WriteProperty` stages the Network Port's network number, primary and
    failover hub URIs, reconnect and session timers, hub enable setting, and
    hub accept URIs through the object's change lifecycle. The Command
    property accepts `:discard_changes`, `:validate_changes`, and
    `:generate_csr_file`. The last command requires `:changes_pending` to be
    false. It generates a P-256 key and a PKCS #10 CSR with the active
    certificate's subject. The read-only CSR File exposes the signing request.

    AtomicReadFile and AtomicWriteFile use the File object's stream access
    rules. The operational certificate and the two issuer Files accept
    staged uploads up to 65,536 octets per File. A `WriteProperty` of `0` to
    `:file_size` stages an empty File in any of those writable slots. Private
    keys stay in the port's private storage.

    ReinitializeDevice supports `:activate_changes` and `:warmstart`. The
    managed port's [activation section](`m:BACnet.Stack.Transport.ScTransport.ManagedPort#module-certificate-rotation-and-activation`)
    describes acknowledgment ordering and rollback behavior.
    """

    alias BACnet.Protocol.APDU
    alias BACnet.Protocol.BACnetArray
    alias BACnet.Protocol.BACnetDateTime
    alias BACnet.Protocol.Constants
    alias BACnet.Protocol.ObjectIdentifier
    alias BACnet.Protocol.ObjectsUtility
    alias BACnet.Protocol.ReadAccessResult
    alias BACnet.Protocol.SecureConnect.Settings

    alias BACnet.Protocol.ObjectExecution.Context
    alias BACnet.Protocol.ObjectExecution.Lifecycle
    alias BACnet.Protocol.ObjectTypes.File
    alias BACnet.Protocol.ObjectTypes.NetworkPort

    alias BACnet.Protocol.Services.AtomicReadFile
    alias BACnet.Protocol.Services.AtomicWriteFile
    alias BACnet.Protocol.Services.ReadProperty
    alias BACnet.Protocol.Services.ReadPropertyMultiple
    alias BACnet.Protocol.Services.ReinitializeDevice
    alias BACnet.Protocol.Services.WriteProperty

    alias BACnet.Protocol.Services.Ack.AtomicReadFileAck
    alias BACnet.Protocol.Services.Ack.AtomicWriteFileAck
    alias BACnet.Protocol.Services.Ack.ReadPropertyAck
    alias BACnet.Protocol.Services.Ack.ReadPropertyMultipleAck

    alias BACnet.Stack.Client
    alias BACnet.Stack.Transport.ScTransport.Activation
    alias BACnet.Stack.Transport.ScTransport.Config
    alias BACnet.Stack.Transport.ScTransport.Credentials
    alias BACnet.Stack.Transport.ScTransport.Hosted
    alias BACnet.Stack.Transport.ScTransport.ManagedPort
    alias BACnet.Stack.Transport.ScTransport.Objects
    alias BACnet.Stack.Transport.ScTransport.Store

    @services %{
      read_property: ReadProperty,
      read_property_multiple: ReadPropertyMultiple,
      write_property: WriteProperty,
      atomic_read_file: AtomicReadFile,
      atomic_write_file: AtomicWriteFile,
      reinitialize_device: ReinitializeDevice
    }
    @writable [:network_number | Settings.port_properties()]
    @file_limit 65_536

    @typep source :: %{
             vmac: BACnet.Protocol.SecureConnect.BVLC.vmac(),
             source: BACnet.Protocol.NpciTarget.t() | nil
           }
    @typep object :: BACnet.Protocol.ObjectTypes.Device.t() | NetworkPort.t() | File.t()
    @typep bacnet_error :: {Constants.error_class(), Constants.error_code()}
    @typep state_update :: {:ok, ManagedPort.state()} | {:error, term()}
    @typep dispatch_result ::
             {:ok, APDU.ComplexACK.t() | APDU.SimpleACK.t(), ManagedPort.state()}
             | {:activate, Activation.operation()}
             | {:error, term()}

    @doc """
    Decodes and authorizes a confirmed management request, sends the BACnet
    reply, and returns the managed port state to retain.
    """
    @spec request(ManagedPort.state(), reference(), APDU.ConfirmedServiceRequest.t(), source()) ::
            ManagedPort.state()
    def request(state, ref, apdu, source) do
      case decode(apdu) do
        {:ok, service} -> reply(state, ref, apdu, service, source)
        :error -> reject(state, ref, apdu, :unrecognized_service)
        {:error, _reason} -> reject(state, ref, apdu, :invalid_parameter_data_type)
      end
    end

    @doc """
    Handles a request delegated by the object host when all its targets belong
    to this managed port. The host retains requests for its other objects,
    mixed ReadPropertyMultiple requests, and services it handles itself.
    """
    @spec hosted_request(
            ManagedPort.state(),
            reference(),
            APDU.ConfirmedServiceRequest.t(),
            source()
          ) :: {:ok, ManagedPort.state()} | :unhandled | {:error, :refresh_required}
    def hosted_request(state, ref, apdu, source) do
      with {:ok, service} <- decode(apdu),
           true <- managed_request?(state, service),
           :ok <- check_host_mutation(state, service) do
        {:ok, reply(state, ref, apdu, service, source)}
      else
        {:error, :refresh_required} = error -> error
        _other -> :unhandled
      end
    end

    @spec check_host_mutation(ManagedPort.state(), struct()) :: :ok | {:error, :refresh_required}
    defp check_host_mutation(state, %service{})
         when service in [WriteProperty, AtomicWriteFile, ReinitializeDevice],
         do: Hosted.check_configuration(state.port, state.snapshot)

    defp check_host_mutation(_state, _service), do: :ok

    @spec decode(APDU.ConfirmedServiceRequest.t()) :: {:ok, struct()} | {:error, term()} | :error
    defp decode(apdu) do
      with {:ok, module} <- Map.fetch(@services, apdu.service), do: module.from_apdu(apdu)
    end

    @spec managed_request?(ManagedPort.state(), struct()) :: boolean()
    defp managed_request?(state, %ReadProperty{object_identifier: id}),
      do: managed_object?(state, id)

    defp managed_request?(state, %ReadPropertyMultiple{list: specs}),
      do: Enum.all?(specs, &managed_object?(state, &1.object_identifier))

    defp managed_request?(state, %WriteProperty{object_identifier: id, property_identifier: prop}) do
      case id.type do
        :network_port ->
          id.instance == state.port.object_instance and prop in [:command | @writable]

        :file ->
          prop == :file_size and match?({:ok, _role}, Objects.lookup_file(state, id))

        _other ->
          false
      end
    end

    defp managed_request?(state, %service{object_identifier: id})
         when service in [AtomicReadFile, AtomicWriteFile],
         do: match?({:ok, _role}, Objects.lookup_file(state, id))

    defp managed_request?(_state, %ReinitializeDevice{reinitialized_state: reason}),
      do: reason in [:activate_changes, :warmstart]

    @spec managed_object?(ManagedPort.state(), ObjectIdentifier.t()) :: boolean()
    defp managed_object?(state, id) do
      case Objects.canonical_id(state, id) do
        %ObjectIdentifier{type: :device, instance: instance} ->
          instance == state.device.object_instance

        %ObjectIdentifier{type: :network_port, instance: instance} ->
          instance == state.port.object_instance

        %ObjectIdentifier{type: :file} ->
          match?({:ok, _role}, Objects.lookup_file(state, id))

        _other ->
          false
      end
    end

    @spec reply(
            ManagedPort.state(),
            reference(),
            APDU.ConfirmedServiceRequest.t(),
            struct(),
            source()
          ) :: ManagedPort.state()
    defp reply(state, ref, apdu, service, source) do
      case authorize(state, service, source) do
        :ok ->
          case dispatch(state, service, apdu) do
            {:ok, response, state} ->
              Client.reply(state.client, ref, response)
              state

            {:activate, operation} ->
              activate(state, ref, apdu, operation)

            {:error, {class, code}} ->
              reply_error(state, ref, apdu, class, code)

            {:error, _reason} ->
              reply_error(state, ref, apdu, :services, :operational_problem)
          end

        {:error, :denied} ->
          reply_error(state, ref, apdu, :security, :service_request_denied)
      end
    end

    @spec reject(
            ManagedPort.state(),
            reference(),
            APDU.ConfirmedServiceRequest.t(),
            Constants.reject_reason()
          ) :: ManagedPort.state()
    defp reject(state, ref, apdu, reason) do
      Client.reply(state.client, ref, %APDU.Reject{invoke_id: apdu.invoke_id, reason: reason})
      state
    end

    @spec authorize(ManagedPort.state(), struct(), source()) :: :ok | {:error, :denied}
    defp authorize(_state, %service{}, _source)
         when service in [ReadProperty, ReadPropertyMultiple], do: :ok

    defp authorize(%{authorize: authorize}, service, source) when is_function(authorize, 2) do
      if authorize.(service, source) === true, do: :ok, else: {:error, :denied}
    rescue
      _error -> {:error, :denied}
    catch
      _kind, _reason -> {:error, :denied}
    end

    defp authorize(_state, _service, _source), do: {:error, :denied}

    @spec dispatch(ManagedPort.state(), struct(), APDU.ConfirmedServiceRequest.t()) ::
            dispatch_result()
    defp dispatch(state, %ReadProperty{} = request, apdu) do
      id = Objects.canonical_id(state, request.object_identifier)
      property = request.property_identifier
      index = request.property_array_index

      with {:ok, object} <- Objects.get_object(state, id),
           {:ok, value} <- Objects.read_value(object, id, property, index),
           {:ok, response} <-
             ReadPropertyAck.to_apdu(
               %ReadPropertyAck{
                 object_identifier: id,
                 property_identifier: property,
                 property_array_index: index,
                 property_value: value
               },
               apdu.invoke_id
             ) do
        {:ok, response, state}
      end
    end

    defp dispatch(state, %ReadPropertyMultiple{} = request, apdu) do
      {results, errors} =
        request.list
        |> Enum.map(&Objects.read_access_result(state, &1))
        |> Enum.split_with(&is_struct(&1, ReadAccessResult))

      case {results, errors} do
        {[], [error | _rest]} ->
          error

        {results, _errors} ->
          with {:ok, response} <-
                 ReadPropertyMultipleAck.to_apdu(
                   %ReadPropertyMultipleAck{results: results},
                   apdu.invoke_id
                 ) do
            {:ok, response, state}
          end
      end
    end

    defp dispatch(state, %WriteProperty{} = request, apdu) do
      id = Objects.canonical_id(state, request.object_identifier)

      with {:ok, object} <- Objects.get_object(state, id),
           {:ok, state} <- write_value(state, object, id, request) do
        {:ok, ack(apdu), state}
      end
    end

    defp dispatch(state, %AtomicReadFile{} = request, apdu) do
      with {:ok, role} <- Objects.lookup_file(state, request.object_identifier),
           {:ok, object} <- Objects.file_object(state, role),
           contents = Objects.file_data(state.snapshot, role),
           {:ok, read, eof} <-
             File.prepare_file_read(object, bounded_read(request, apdu), byte_size(contents)),
           {:ok, response} <-
             AtomicReadFileAck.to_apdu(
               %AtomicReadFileAck{
                 eof: eof,
                 stream_access: true,
                 start_position: read.start_position,
                 record_count: nil,
                 data: binary_part(contents, read.start_position, read.requested_count)
               },
               apdu.invoke_id
             ) do
        {:ok, response, state}
      end
    end

    defp dispatch(state, %AtomicWriteFile{} = request, apdu) do
      with {:ok, role} <- Objects.lookup_file(state, request.object_identifier),
           {:ok, object} <- Objects.file_object(state, role),
           contents = Objects.file_data(state.snapshot, role),
           {:ok, write} <- File.prepare_file_write(object, request, byte_size(contents)),
           {:ok, new_contents} <- patch_file(contents, write.start_position, write.data),
           {:ok, state} <- stage_file(state, role, object, new_contents),
           {:ok, response} <-
             AtomicWriteFileAck.to_apdu(
               %AtomicWriteFileAck{
                 stream_access: true,
                 start_position: write.start_position
               },
               apdu.invoke_id
             ) do
        {:ok, response, state}
      end
    end

    defp dispatch(_state, %ReinitializeDevice{reinitialized_state: operation}, _apdu)
         when operation in [:activate_changes, :warmstart],
         do: {:activate, operation}

    defp dispatch(_state, %ReinitializeDevice{}, _apdu),
      do: {:error, {:services, :optional_functionality_not_supported}}

    @spec activate(
            ManagedPort.state(),
            reference(),
            APDU.ConfirmedServiceRequest.t(),
            Activation.operation()
          ) :: ManagedPort.state()
    defp activate(state, ref, apdu, operation) do
      case Activation.run(state, operation, fn -> Client.reply(state.client, ref, ack(apdu)) end) do
        {:ok, updated} ->
          updated

        {:error, {:reply_failed, _reason}, restored} ->
          restored

        {:error, {class, code}, restored} when is_atom(class) and is_atom(code) ->
          reply_error(restored, ref, apdu, class, code)

        {:error, _reason, restored} ->
          reply_error(restored, ref, apdu, :services, :operational_problem)
      end
    end

    @spec reply_error(
            ManagedPort.state(),
            reference(),
            APDU.ConfirmedServiceRequest.t(),
            Constants.error_class(),
            Constants.error_code()
          ) :: ManagedPort.state()
    defp reply_error(state, ref, apdu, class, code) do
      response = %APDU.Error{
        invoke_id: apdu.invoke_id,
        service: apdu.service,
        class: class,
        code: code,
        payload: []
      }

      Client.reply(state.client, ref, response)
      state
    end

    @spec ack(APDU.ConfirmedServiceRequest.t()) :: APDU.SimpleACK.t()
    defp ack(apdu), do: %APDU.SimpleACK{invoke_id: apdu.invoke_id, service: apdu.service}

    @spec write_value(ManagedPort.state(), object(), ObjectIdentifier.t(), WriteProperty.t()) ::
            state_update()
    defp write_value(
           state,
           %NetworkPort{},
           id,
           %WriteProperty{
             property_identifier: :command,
             property_array_index: nil,
             priority: nil
           } = request
         ) do
      case ObjectsUtility.cast_property_to_value(id, :command, request.property_value) do
        {:ok, :discard_changes} -> discard(state)
        {:ok, :validate_changes} -> validate_changes(state)
        {:ok, :generate_csr_file} -> generate_csr(state)
        {:ok, _command} -> {:error, {:property, :optional_functionality_not_supported}}
        _other -> {:error, {:property, :invalid_parameter_data_type}}
      end
    end

    defp write_value(
           state,
           %NetworkPort{} = object,
           id,
           %WriteProperty{
             property_identifier: property,
             priority: nil
           } = request
         )
         when property in @writable do
      with :ok <- writable(object, property),
           {:ok, value} <- decode_write(object, id, request),
           :ok <- validate_value(property, value),
           {:ok, candidate} <- NetworkPort.update_property(object, property, value),
           context = Context.new({:property_write, property, request.property_array_index, nil}),
           {:ok, port} <- Lifecycle.prepare_write(object, candidate, context) do
        pending = Map.put(state.snapshot.pending, property, value)
        Store.persist(%{state | port: port}, %{state.snapshot | pending: pending})
      end
    end

    defp write_value(
           state,
           %File{} = object,
           id,
           %WriteProperty{
             property_identifier: :file_size,
             property_array_index: nil,
             priority: nil
           } = request
         ) do
      with :ok <- writable(object, :file_size),
           {:ok, 0} <-
             ObjectsUtility.cast_property_to_value(id, :file_size, request.property_value),
           {:ok, role} <- Objects.lookup_file(state, id) do
        stage_file(state, role, object, "")
      else
        {:ok, _nonzero} -> {:error, {:property, :value_out_of_range}}
        error -> error
      end
    end

    defp write_value(_state, _object, _id, _request),
      do: {:error, {:property, :write_access_denied}}

    @spec writable(object(), Constants.property_identifier()) :: :ok | {:error, bacnet_error()}
    defp writable(%module{} = object, property) do
      cond do
        not ObjectsUtility.has_property?(object, property) ->
          {:error, {:property, :unknown_property}}

        module.property_writable?(object, property) ->
          :ok

        true ->
          {:error, {:property, :write_access_denied}}
      end
    end

    @spec decode_write(NetworkPort.t(), ObjectIdentifier.t(), WriteProperty.t()) ::
            {:ok, term()} | {:error, bacnet_error()}
    defp decode_write(_object, id, %{property_array_index: nil} = request) do
      cast_write(id, request, false)
    end

    defp decode_write(
           %NetworkPort{sc_hub_function_accept_uris: array},
           id,
           %{
             property_identifier: :sc_hub_function_accept_uris,
             property_array_index: index
           } = request
         )
         when index > 0 do
      with {:ok, value} <- cast_write(id, request, true) do
        case BACnetArray.set_item(array, index, value) do
          {:ok, updated} -> {:ok, updated}
          _error -> {:error, {:property, :invalid_array_index}}
        end
      end
    end

    defp decode_write(_object, _id, _request),
      do: {:error, {:property, :property_is_not_an_array}}

    @spec cast_write(ObjectIdentifier.t(), WriteProperty.t(), boolean()) ::
            {:ok, term()} | {:error, bacnet_error()}
    defp cast_write(id, request, partial) do
      case ObjectsUtility.cast_property_to_value(
             id,
             request.property_identifier,
             request.property_value,
             allow_partial: partial
           ) do
        {:ok, value} -> {:ok, value}
        _error -> {:error, {:property, :invalid_parameter_data_type}}
      end
    end

    @spec validate_value(Constants.property_identifier(), term()) ::
            :ok | {:error, bacnet_error()}
    defp validate_value(property, value)
         when property in [:sc_primary_hub_uri, :sc_failover_hub_uri] do
      case Config.uri(value) do
        {:ok, _uri} -> :ok
        {:error, _reason} -> {:error, {:property, :value_out_of_range}}
      end
    end

    defp validate_value(:sc_hub_function_accept_uris, %BACnetArray{} = array) do
      if Enum.all?(BACnetArray.to_list(array), &match?({:ok, %URI{}}, Config.uri(&1))),
        do: :ok,
        else: {:error, {:property, :value_out_of_range}}
    end

    defp validate_value(_property, _value), do: :ok

    @spec discard(ManagedPort.state()) :: state_update()
    defp discard(state) do
      with {:ok, port} <- discard_port(state.port),
           {:ok, updated} <- refresh_discarded_files(%{state | port: port}) do
        Store.persist(updated, %{
          state.snapshot
          | pending: %{},
            uploads: %{},
            upload_dates: %{},
            activation: nil
        })
      end
    end

    @spec refresh_discarded_files(ManagedPort.state()) :: state_update()
    defp refresh_discarded_files(%{files: nil} = state), do: {:ok, state}

    defp refresh_discarded_files(state) do
      active = %{state.snapshot | uploads: %{}, upload_dates: %{}}

      with {:ok, files} <- Objects.project_files(%{state | snapshot: active}) do
        {:ok, %{state | files: files}}
      end
    end

    @doc """
    Applies the Network Port's discard command. Hosted mode uses the same
    lifecycle operation before restoring managed changes from disk.
    """
    @spec discard_port(NetworkPort.t()) :: {:ok, NetworkPort.t()} | {:error, term()}
    def discard_port(port) do
      context = Context.new({:property_write, :command, nil, nil})

      with {:ok, candidate} <- NetworkPort.update_property(port, :command, :discard_changes),
           {:ok, prepared} <- Lifecycle.prepare_write(port, candidate, context),
           {:ok, result} <- Lifecycle.execute(prepared, context) do
        {:ok, result.object}
      end
    end

    @spec validate_changes(ManagedPort.state()) :: state_update()
    defp validate_changes(state) do
      result =
        case ManagedPort.runtime_config(state.snapshot, :proposed, state.hub_audit) do
          {:ok, _runtime} -> Objects.health()
          {:error, {property, class, code}} -> Objects.health(property, class, code)
        end

      with {:ok, port} <-
             NetworkPort.update_operating_property(state.port, :command_validation_result, result) do
        {:ok, %{state | port: port}}
      end
    end

    @spec generate_csr(ManagedPort.state()) :: state_update()
    defp generate_csr(%{port: %{changes_pending: true}}),
      do: {:error, {:property, :invalid_value_in_this_state}}

    defp generate_csr(state) do
      snapshot = state.snapshot

      with {:ok, cert} <- Credentials.certificate(snapshot.certificates.operational),
           {:ok, object} <- Objects.file_object(state, :csr) do
        key = X509.PrivateKey.new_ec(:secp256r1)
        csr = X509.CSR.to_pem(X509.CSR.new(key, X509.Certificate.subject(cert)))

        with {:ok, file} <- modification(object, csr) do
          snapshot = %{snapshot | csr: csr, csr_key: X509.PrivateKey.to_pem(key)}
          snapshot = put_in(snapshot.file_dates[:csr], file.modification_date)

          Store.persist(retain_file(state, :csr, file), snapshot)
        end
      end
    end

    @spec stage_file(ManagedPort.state(), ManagedPort.file_role(), File.t(), binary()) ::
            state_update()
    defp stage_file(state, role, object, data) do
      with {:ok, file} <- modification(object, data),
           {:ok, port} <- NetworkPort.stage_external_change(state.port) do
        snapshot =
          state.snapshot
          |> put_in([:uploads, role], data)
          |> put_in([:upload_dates, role], file.modification_date)

        Store.persist(retain_file(%{state | port: port}, role, file), snapshot)
      end
    end

    @spec retain_file(ManagedPort.state(), ManagedPort.file_role(), File.t()) ::
            ManagedPort.state()
    defp retain_file(%{files: files} = state, role, file) when is_map(files),
      do: %{state | files: Map.replace!(files, role, file)}

    defp retain_file(state, _role, _file), do: state

    @spec modification(File.t(), binary()) :: {:ok, File.t()} | {:error, term()}
    defp modification(object, data) do
      File.record_modification(
        object,
        %{file_size: byte_size(data), record_count: nil},
        BACnetDateTime.utc_now()
      )
    end

    @spec patch_file(binary(), non_neg_integer(), binary()) ::
            {:ok, binary()} | {:error, bacnet_error()}
    defp patch_file(contents, offset, data) when offset + byte_size(data) <= @file_limit do
      end_offset = offset + byte_size(data)
      existing = byte_size(contents)
      prefix = binary_part(contents, 0, min(existing, offset))
      padding = :binary.copy(<<0>>, max(0, offset - existing))

      suffix =
        if end_offset < existing,
          do: binary_part(contents, end_offset, existing - end_offset),
          else: ""

      {:ok, prefix <> padding <> data <> suffix}
    end

    defp patch_file(_contents, _offset, _data),
      do: {:error, {:resources, :no_space_to_write_property}}

    @spec bounded_read(AtomicReadFile.t(), APDU.ConfirmedServiceRequest.t()) :: AtomicReadFile.t()
    defp bounded_read(request, apdu) do
      # Leave room for the ACK's APCI, tags, stream position, and end-of-file flag.
      max_count = max(apdu.max_apdu - 32, 1)
      %{request | requested_count: min(request.requested_count, max_count)}
    end
  end
end
