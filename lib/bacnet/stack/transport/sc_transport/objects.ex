if BACstack.MixProject.sc_enabled?() do
  defmodule BACnet.Stack.Transport.ScTransport.Objects do
    @moduledoc """
    Resolves and reads objects exposed by the managed SC service.

    Standalone mode supplies a Device and Network Port owned by ManagedPort
    and constructs File metadata from the private snapshot. Hosted mode
    supplies the corresponding application-owned objects. The projection
    adds current connector and hub observations and the sizes and dates of
    certificate Files without publishing private keys.
    """

    alias BACnet.Protocol.AccessSpecification
    alias BACnet.Protocol.AccessSpecification.Property
    alias BACnet.Protocol.ApplicationTags.Encoding
    alias BACnet.Protocol.BACnetArray
    alias BACnet.Protocol.BACnetDateTime
    alias BACnet.Protocol.BACnetError
    alias BACnet.Protocol.Constants
    alias BACnet.Protocol.HostNPort
    alias BACnet.Protocol.ObjectExecution.Context
    alias BACnet.Protocol.ObjectExecution.Lifecycle
    alias BACnet.Protocol.ObjectIdentifier
    alias BACnet.Protocol.ObjectsMacro
    alias BACnet.Protocol.ObjectsUtility
    alias BACnet.Protocol.ObjectTypes.File
    alias BACnet.Protocol.ObjectTypes.NetworkPort
    alias BACnet.Protocol.ReadAccessResult
    alias BACnet.Protocol.ReadAccessResult.ReadResult
    alias BACnet.Protocol.SecureConnect.FailedConnectionRequest
    alias BACnet.Protocol.SecureConnect.Health
    alias BACnet.Protocol.SecureConnect.HubConnection
    alias BACnet.Protocol.SecureConnect.HubFunctionConnection
    alias BACnet.Stack.Transport.ScTransport.Diagnostics
    alias BACnet.Stack.Transport.ScTransport.Hub
    alias BACnet.Stack.Transport.ScTransport.ManagedPort
    alias BACnet.Stack.Transport.ScTransport.Node
    alias BACnet.Stack.Transport.ScTransport.Node.ConnectionStatus

    @typep object :: BACnet.Protocol.ObjectTypes.Device.t() | NetworkPort.t() | File.t()
    @typep property :: Constants.property_identifier() | non_neg_integer()
    @typep array_index :: non_neg_integer() | nil
    @typep bacnet_error :: {Constants.error_class(), Constants.error_code()}
    @typep encoded_value :: {:ok, Encoding.t() | [Encoding.t()]} | {:error, term()}

    @doc """
    Resolves the wildcard Device instance against the managed Device.
    """
    @spec canonical_id(ManagedPort.state(), ObjectIdentifier.t()) :: ObjectIdentifier.t()
    def canonical_id(state, %ObjectIdentifier{type: :device, instance: 4_194_303}),
      do: ObjectsUtility.get_object_identifier(state.device)

    def canonical_id(_state, id), do: id

    @doc """
    Returns an object exposed by the managed port.
    """
    @spec get_object(ManagedPort.state(), ObjectIdentifier.t()) ::
            {:ok, object()} | {:error, term()}
    def get_object(state, %ObjectIdentifier{type: :device, instance: instance})
        when instance == state.device.object_instance,
        do: {:ok, state.device}

    def get_object(%{hosted: nil} = state, %ObjectIdentifier{
          type: :network_port,
          instance: instance
        })
        when instance == state.port.object_instance,
        do: {:ok, observed_port(state)}

    def get_object(%{port: %{object_instance: instance} = port}, %ObjectIdentifier{
          type: :network_port,
          instance: instance
        }),
        do: {:ok, port}

    def get_object(state, %ObjectIdentifier{type: :file} = id) do
      with {:ok, role} <- lookup_file(state, id), do: file_object(state, role)
    end

    def get_object(_state, _id), do: {:error, {:object, :unknown_object}}

    @doc """
    Finds the credential role assigned to a File object identifier.
    """
    @spec lookup_file(ManagedPort.state(), ObjectIdentifier.t()) ::
            {:ok, ManagedPort.file_role()} | {:error, bacnet_error()}
    def lookup_file(state, %ObjectIdentifier{type: :file, instance: instance}) do
      case Enum.find(state.snapshot.files, fn {_role, id} -> id == instance end) do
        {role, _id} -> {:ok, role}
        nil -> {:error, {:object, :unknown_object}}
      end
    end

    def lookup_file(_state, _id), do: {:error, {:object, :unknown_object}}

    @doc """
    Builds or refreshes the File metadata for a credential role.
    """
    @spec file_object(ManagedPort.state(), ManagedPort.file_role()) ::
            {:ok, File.t()} | {:error, term()}
    def file_object(%{files: files, snapshot: snapshot}, role) when is_map(files) do
      object = Map.fetch!(files, role)
      size = byte_size(file_data(snapshot, role))
      date = snapshot.upload_dates[role] || snapshot.file_dates[role] || object.modification_date

      if object.file_size == size and object.modification_date == date do
        {:ok, object}
      else
        File.record_modification(object, %{file_size: size, record_count: nil}, date)
      end
    end

    def file_object(state, role) do
      snapshot = state.snapshot

      File.create(
        snapshot.files[role],
        file_name(role),
        %{
          file_type: "PEM",
          file_size: byte_size(file_data(snapshot, role)),
          file_access_method: :stream_access,
          read_only: role == :csr,
          modification_date:
            snapshot.upload_dates[role] || snapshot.file_dates[role] ||
              ObjectsMacro.get_default_bacnet_datetime()
        },
        revision: 24
      )
    end

    @spec file_name(ManagedPort.file_role()) :: String.t()
    defp file_name(:operational), do: "SC Operational Certificate"
    defp file_name(:issuer_1), do: "SC Issuer Certificate 1"
    defp file_name(:issuer_2), do: "SC Issuer Certificate 2"
    defp file_name(:csr), do: "SC Certificate Signing Request"

    @doc """
    Returns the visible certificate or CSR bytes from the snapshot.
    """
    @spec file_data(ManagedPort.snapshot(), ManagedPort.file_role()) :: binary()
    def file_data(snapshot, :csr), do: snapshot.csr

    def file_data(snapshot, role),
      do: Map.get(snapshot.uploads, role, snapshot.certificates[role])

    @doc """
    Reads and encodes a BACnet property or array element.
    """
    @spec read_value(object(), ObjectIdentifier.t(), property(), array_index()) :: encoded_value()
    def read_value(object, _id, :object_identifier, nil),
      do:
        {:ok,
         Encoding.create!({:object_identifier, ObjectsUtility.get_object_identifier(object)})}

    def read_value(object, _id, :object_type, nil) do
      type = Constants.by_name!(:object_type, ObjectsUtility.get_object_type(object))
      {:ok, Encoding.create!({:enumerated, type})}
    end

    def read_value(object, _id, :property_list, index) do
      properties =
        object
        |> ObjectsUtility.get_properties()
        |> Enum.map(
          &Encoding.create!({:enumerated, Constants.by_name!(:property_identifier, &1)})
        )

      case index do
        nil ->
          {:ok, properties}

        0 ->
          {:ok, Encoding.create!({:unsigned_integer, length(properties)})}

        index when index > 0 and index <= length(properties) ->
          {:ok, Enum.at(properties, index - 1)}

        _other ->
          {:error, {:property, :invalid_array_index}}
      end
    end

    def read_value(object, id, property, index) when is_atom(property) do
      with {:ok, result} <-
             Lifecycle.prepare_read(object, Context.new({:property_read, property, index})),
           {:ok, value} <- ObjectsUtility.get_property(result.object, property) do
        encode_value(id, property, value, index)
      else
        {:error, {:property, _code}} = error -> error
        {:error, _reason} -> {:error, {:property, :unknown_property}}
      end
    end

    def read_value(_object, _id, _property, _index), do: {:error, {:property, :unknown_property}}

    @spec encode_value(
            ObjectIdentifier.t(),
            Constants.property_identifier(),
            term(),
            array_index()
          ) ::
            encoded_value()
    defp encode_value(id, property, value, nil),
      do: ObjectsUtility.cast_value_to_property(id, property, value)

    defp encode_value(_id, _property, %BACnetArray{} = array, 0),
      do: {:ok, Encoding.create!({:unsigned_integer, BACnetArray.size(array)})}

    defp encode_value(id, property, %BACnetArray{} = array, index) do
      case BACnetArray.fetch(array, index) do
        {:ok, value} ->
          ObjectsUtility.cast_value_to_property(id, property, value, allow_partial: true)

        :error ->
          {:error, {:property, :invalid_array_index}}
      end
    end

    defp encode_value(_id, _property, _value, _index),
      do: {:error, {:property, :property_is_not_an_array}}

    @doc """
    Builds a result for one ReadPropertyMultiple object selection.

    A missing object produces an access error for each explicitly named
    property. If the request contains only selectors, returns the object error
    because there are no concrete properties to include in the result.
    """
    @spec read_access_result(ManagedPort.state(), AccessSpecification.t()) ::
            ReadAccessResult.t() | {:error, term()}
    def read_access_result(state, spec) do
      id = canonical_id(state, spec.object_identifier)

      case get_object(state, id) do
        {:ok, object} ->
          results =
            for selector <- spec.properties,
                {property, index} <- select_properties(object, selector) do
              read_result(property, index, read_value(object, id, property, index))
            end

          %ReadAccessResult{object_identifier: id, results: results}

        {:error, _reason} = error ->
          results =
            for %Property{property_identifier: property, property_array_index: index} <-
                  spec.properties do
              read_result(property, index, error)
            end

          case results do
            [] -> error
            [_result | _rest] -> %ReadAccessResult{object_identifier: id, results: results}
          end
      end
    end

    @spec select_properties(
            object(),
            Property.t() | :all | :required | :optional
          ) :: [{property(), array_index()}]
    defp select_properties(_object, %{property_identifier: property, property_array_index: index}),
         do: [{property, index}]

    defp select_properties(%module{} = object, selector)
         when selector in [:all, :required, :optional] do
      required =
        module.get_required_properties() ++
          [:object_identifier, :object_name, :object_type, :property_list]

      available = [
        :object_identifier,
        :object_name,
        :object_type,
        :property_list | ObjectsUtility.get_properties(object)
      ]

      for property <- available,
          selector == :all or (selector == :required and property in required) or
            (selector == :optional and property not in required),
          do: {property, nil}
    end

    @spec read_result(property(), array_index(), encoded_value()) :: ReadResult.t()
    defp read_result(property, index, {:ok, value}),
      do: %ReadResult{
        property_identifier: property,
        property_array_index: index,
        property_value: value,
        error: nil
      }

    defp read_result(property, index, {:error, {class, code}}) do
      %ReadResult{
        property_identifier: property,
        property_array_index: index,
        property_value: nil,
        error: %BACnetError{class: class, code: code}
      }
    end

    @doc """
    Returns the host's objects with the live port observations and File metadata
    from the managed snapshot. The Device and host-defined properties are
    retained from the supplied objects.
    """
    @spec host_objects(ManagedPort.state()) ::
            {:ok, ManagedPort.host_objects()} | {:error, term()}
    def host_objects(state) do
      with {:ok, files} <- project_files(state) do
        {:ok, %{device: state.device, port: observed_port(state), files: files}}
      end
    end

    @doc """
    Projects snapshot metadata onto the certificate File objects.
    """
    @spec project_files(ManagedPort.state()) ::
            {:ok, %{ManagedPort.file_role() => File.t()}} | {:error, term()}
    def project_files(state) do
      Enum.reduce_while(state.snapshot.files, {:ok, %{}}, fn {role, _instance}, {:ok, acc} ->
        case file_object(state, role) do
          {:ok, file} -> {:cont, {:ok, Map.put(acc, role, file)}}
          error -> {:halt, error}
        end
      end)
    end

    @spec observed_port(ManagedPort.state()) :: NetworkPort.t()
    defp observed_port(state) do
      status = Node.status(state.node)

      connector_state =
        case status.active do
          :primary -> :connected_to_primary
          :failover -> :connected_to_failover
          nil -> :no_hub_connection
        end

      props = [
        mac_address: status.vmac,
        apdu_length: Node.max_apdu_length(),
        max_bvlc_length_accepted: BACnet.Protocol.SecureConnect.BVLC.max_bvlc(),
        max_npdu_length_accepted: Node.max_npdu_length(),
        current_health: current_health(status, state.snapshot.active),
        sc_hub_connector_state: connector_state,
        sc_primary_hub_connection_status: connector(status.active == :primary, status.primary),
        sc_failover_hub_connection_status: connector(status.active == :failover, status.failover)
      ]

      props =
        if state.hub do
          hub = Hub.status(state.hub)

          props ++
            [
              sc_hub_function_binding: Integer.to_string(Hub.port(state.hub)),
              sc_hub_function_connection_status: Enum.map(hub.connections, &hub_connection/1),
              sc_failed_connection_requests: Enum.map(hub.failed, &failed_connection/1)
            ]
        else
          props
        end

      Enum.reduce(props, state.port, fn {property, value}, port ->
        {:ok, port} =
          if property == :current_health and not NetworkPort.has_property?(port, property) do
            NetworkPort.add_property(port, property, value)
          else
            NetworkPort.update_operating_property(port, property, value)
          end

        port
      end)
    end

    @spec current_health(Node.Status.t(), map()) :: Health.t()
    defp current_health(status, settings) do
      configured =
        Enum.reject([primary: :sc_primary_hub_uri, failover: :sc_failover_hub_uri], fn
          {_role, property} -> settings[property] in [nil, ""]
        end)

      if not is_nil(status.active) or configured == [] do
        health()
      else
        latest =
          configured
          |> Enum.map(fn {role, property} -> {property, Map.get(status, role)} end)
          |> Enum.max_by(fn {_property, observation} ->
            case observation && (observation.failed_at || observation.disconnected_at) do
              nil -> 0
              time -> DateTime.to_unix(time, :microsecond)
            end
          end)

        {property, observation} = latest

        code =
          if observation && observation.error not in [nil, :closed, :owner_closed],
            do: Diagnostics.code(observation.error),
            else: :network_down

        health(property, :communication, code)
      end
    end

    @doc """
    Converts a connector observation into the BACnet hub connection status
    sequence. A missing observation represents an unconnected hub slot.
    """
    @spec connector(boolean() | nil, ConnectionStatus.t() | nil) :: HubConnection.t()
    def connector(active, status) do
      status =
        status ||
          %ConnectionStatus{
            peer: nil,
            connected_at: nil,
            disconnected_at: nil,
            failed_at: nil,
            error: nil
          }

      state =
        cond do
          active -> 1
          status.error in [nil, :closed, :owner_closed] -> 0
          status.failed_at -> 3
          status.connected_at -> 2
          true -> 3
        end

      connected_at = status.connected_at && (status.failed_at || status.connected_at)

      %HubConnection{
        state: state,
        connected_at: timestamp(connected_at),
        disconnected_at: timestamp(status.disconnected_at),
        error:
          if(state in [2, 3],
            do: %BACnetError{class: :communication, code: Diagnostics.code(status.error)}
          ),
        details: nil
      }
    end

    @spec hub_connection(Hub.Session.t()) :: HubFunctionConnection.t()
    defp hub_connection(session) do
      %HubFunctionConnection{
        state: 1,
        connected_at: timestamp(session.connected_at),
        disconnected_at: timestamp(nil),
        address: host(session.remote),
        vmac: session.peer.vmac,
        uuid: session.peer.uuid,
        error: nil,
        details: nil
      }
    end

    @spec failed_connection(Hub.Failure.t()) :: FailedConnectionRequest.t()
    defp failed_connection(failure) do
      %FailedConnectionRequest{
        timestamp: timestamp(failure.timestamp),
        address: host(failure.remote),
        vmac: failure.peer && failure.peer.vmac,
        uuid: failure.peer && failure.peer.uuid,
        error: %BACnetError{class: :communication, code: failure.code},
        details: nil
      }
    end

    @spec host({:inet.ip_address(), :inet.port_number()}) :: HostNPort.t()
    defp host({ip, port}), do: %HostNPort{host: {:ip_address, ip}, port: port}
    @spec timestamp(DateTime.t() | nil) :: BACnetDateTime.t()
    defp timestamp(nil), do: ObjectsMacro.get_default_bacnet_datetime()
    defp timestamp(datetime), do: BACnetDateTime.from_datetime(datetime)

    @doc """
    Builds a timestamped Network Port health result. The default records a
    successful validation without identifying a failing property.
    """
    @spec health(
            Constants.property_identifier() | nil,
            Constants.error_class(),
            Constants.error_code() | non_neg_integer()
          ) :: Health.t()
    def health(property \\ nil, class \\ :object, code \\ :success),
      do: %Health{
        timestamp: BACnetDateTime.utc_now(),
        result: %BACnetError{class: class, code: code},
        property: property,
        details: nil
      }
  end
end
