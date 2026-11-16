if BACstack.MixProject.sc_enabled?() do
  defmodule BACnet.Stack.Transport.ScTransport.Hosted do
    @moduledoc """
    Binds a managed SC port to the object instances owned by a BACnet host.

    The binding retains the host's address and the identifiers of the Device,
    Network Port, and certificate Files. The host supplies its current objects
    on each call and retains the updated objects that the port returns. This
    allows the host to serialize SC changes with its other BACnet operations
    in its own process.

    The first startup takes its Device UUID, VMAC, active hub settings, and
    File references from the host's objects. The private snapshot records
    subsequent managed settings and certificate changes. An explicit refresh
    projects persisted SC settings and File metadata onto the current host
    objects. This can replace host-side edits to managed properties that were
    never staged through the port. Unrelated host settings are preserved.
    See `BACnet.Stack.Transport.ScTransport.ManagedPort` for the host call order.
    """

    alias BACnet.Protocol.BACnetArray
    alias BACnet.Protocol.ObjectIdentifier
    alias BACnet.Protocol.ObjectsUtility
    alias BACnet.Protocol.ObjectTypes.Device
    alias BACnet.Protocol.ObjectTypes.File
    alias BACnet.Protocol.ObjectTypes.NetworkPort
    alias BACnet.Protocol.SecureConnect.BVLC
    alias BACnet.Stack.Transport.ScTransport.ManagedPort
    alias BACnet.Stack.Transport.ScTransport.Management
    alias BACnet.Stack.Transport.ScTransport.Objects

    import BACnet.Internal, only: [is_server: 1]

    @file_roles [:operational, :issuer_1, :issuer_2, :csr]

    @typedoc """
    The host address and the identity of the objects it delegates to this port.
    """
    @type t :: %__MODULE__{
            host: GenServer.server(),
            device: ObjectIdentifier.t(),
            uuid: <<_::128>>,
            port: ObjectIdentifier.t(),
            files: %{ManagedPort.file_role() => non_neg_integer()}
          }

    @fields [:host, :device, :uuid, :port, :files]
    @enforce_keys @fields
    defstruct @fields

    @doc """
    Validates the local SC objects and records their identifiers. Each File
    must be the stream-access object referenced by its corresponding port
    property. The CSR is read-only and the certificate Files are writable.
    """
    @spec bind(GenServer.server(), ManagedPort.host_objects()) ::
            {:ok, t()} | {:error, :invalid_host_objects}
    def bind(
          host,
          %{
            device:
              %Device{device_uuid: <<uuid::binary-16>>, _metadata: %{remote_object: nil}} =
                device,
            port:
              %NetworkPort{
                network_type: :sc,
                protocol_level: :bacnet_application,
                _metadata: %{revision: revision, remote_object: nil}
              } = port,
            files: files
          }
        )
        when (is_server(host) or
                (is_tuple(host) and tuple_size(host) == 2 and elem(host, 0) == :global)) and
               not is_nil(host) and uuid != <<0::size(128)>> and revision >= 24 do
      with {:ok, ids} <- file_instances(files),
           true <- matching_references?(port, ids),
           true <- ObjectsUtility.has_property?(port, :command) do
        {:ok,
         %__MODULE__{
           host: host,
           device: ObjectsUtility.get_object_identifier(device),
           uuid: uuid,
           port: ObjectsUtility.get_object_identifier(port),
           files: ids
         }}
      else
        _invalid -> {:error, :invalid_host_objects}
      end
    end

    def bind(_host, _objects), do: {:error, :invalid_host_objects}

    @doc """
    Validates that an operation is still using the objects bound at startup.
    """
    @spec check(t(), ManagedPort.host_objects()) :: :ok | {:error, :invalid_host_objects}
    def check(binding, objects) do
      case bind(binding.host, objects) do
        {:ok, ^binding} -> :ok
        _different -> {:error, :invalid_host_objects}
      end
    end

    @doc """
    Confirms that the existing credential snapshot belongs to the bound
    Device UUID and File slots.
    """
    @spec check_snapshot(t() | nil, ManagedPort.snapshot()) ::
            :ok | {:error, :host_snapshot_mismatch}
    def check_snapshot(nil, _snapshot), do: :ok

    def check_snapshot(%__MODULE__{uuid: uuid, files: files}, snapshot) do
      if snapshot.transport[:device_uuid] == uuid and snapshot.files == files,
        do: :ok,
        else: {:error, :host_snapshot_mismatch}
    end

    @doc """
    Returns the active SC settings of the host's Network Port, including its
    initial VMAC. The binding for a hub listener is supplied separately.
    """
    @spec active_configuration(NetworkPort.t()) ::
            {:ok, map()} | {:error, :invalid_host_objects}
    def active_configuration(port) do
      with {:ok, config} <- NetworkPort.active_configuration(port),
           true <- BVLC.valid_vmac?(config[:mac_address]) do
        {:ok, config}
      else
        _invalid -> {:error, :invalid_host_objects}
      end
    end

    @doc """
    Checks the managed settings on the supplied port before a mutation. A
    stale port must be explicitly refreshed by the host.
    """
    @spec check_configuration(NetworkPort.t(), ManagedPort.snapshot()) ::
            :ok | {:error, :refresh_required}
    def check_configuration(port, snapshot) do
      with {:ok, active} <- NetworkPort.active_configuration(port),
           true <- current_configuration?(port, active, snapshot) do
        :ok
      else
        _stale -> {:error, :refresh_required}
      end
    end

    @spec current_configuration?(NetworkPort.t(), map(), ManagedPort.snapshot()) :: boolean()
    defp current_configuration?(port, active, snapshot) do
      settings = Map.put(snapshot.active, :mac_address, snapshot.transport[:vmac])
      pending = host_pending(port, active, settings, snapshot.pending)
      visible = Map.merge(settings, pending)
      pending? = map_size(pending) > 0 or map_size(snapshot.uploads) > 0

      Map.take(active, Map.keys(settings)) == settings and
        Map.take(port, Map.keys(visible)) == visible and port.changes_pending == pending?
    end

    @doc """
    Reconciles the host Network Port with persisted managed settings. Call
    during explicit refresh or startup validation.
    """
    @spec restore_port(NetworkPort.t(), ManagedPort.snapshot()) ::
            {:ok, NetworkPort.t()} | {:error, term()}
    def restore_port(port, snapshot) do
      properties = [
        sc_primary_hub_connection_status: Objects.connector(nil, nil),
        sc_failover_hub_connection_status: Objects.connector(nil, nil),
        command_validation_result: Objects.health()
      ]

      properties =
        if snapshot.hub do
          [{:sc_hub_function_binding, Integer.to_string(snapshot.hub[:port])} | properties]
        else
          properties
        end

      with {:ok, port} <- ensure_host_properties(port, properties),
           {:ok, active} <- NetworkPort.active_configuration(port) do
        settings = Map.put(snapshot.active, :mac_address, snapshot.transport[:vmac])
        pending = host_pending(port, active, settings, snapshot.pending)

        if current_configuration?(port, active, snapshot) do
          {:ok, port}
        else
          with {:ok, port} <- Management.discard_port(port),
               {:ok, port} <- restore_active(port, settings) do
            restore_changes(port, %{snapshot | pending: pending})
          end
        end
      end
    end

    @spec host_pending(NetworkPort.t(), map(), map(), map()) :: map()
    defp host_pending(port, active, settings, pending) do
      managed_properties = [:network_number_quality | Map.keys(settings)]

      other_changes =
        for {property, value} <- Map.drop(active, managed_properties),
            pending_value = Map.fetch!(port, property),
            pending_value != value,
            into: %{},
            do: {property, pending_value}

      Map.merge(other_changes, pending)
    end

    @spec ensure_host_properties(NetworkPort.t(), Keyword.t()) ::
            {:ok, NetworkPort.t()} | {:error, term()}
    defp ensure_host_properties(port, properties) do
      Enum.reduce_while(properties, {:ok, port}, fn {property, value}, {:ok, acc} ->
        if ObjectsUtility.has_property?(acc, property) do
          {:cont, {:ok, acc}}
        else
          case NetworkPort.add_property(acc, property, value) do
            {:ok, updated} -> {:cont, {:ok, updated}}
            error -> {:halt, error}
          end
        end
      end)
    end

    @spec restore_active(NetworkPort.t(), map()) :: {:ok, NetworkPort.t()} | {:error, term()}
    defp restore_active(port, active) do
      Enum.reduce_while(active, {:ok, port}, fn {property, value}, {:ok, acc} ->
        case restore_active_property(acc, property, value) do
          {:ok, updated} -> {:cont, {:ok, updated}}
          error -> {:halt, error}
        end
      end)
    end

    @spec restore_active_property(NetworkPort.t(), atom(), term()) ::
            {:ok, NetworkPort.t()} | {:error, term()}
    defp restore_active_property(port, :network_number, value)
         when value != port.network_number do
      with {:ok, port} <- NetworkPort.update_property(port, :network_number, value) do
        ManagedPort.commit_port(port, :activate_changes)
      end
    end

    defp restore_active_property(port, property, value),
      do: NetworkPort.update_operating_property(port, property, value)

    @doc """
    Restages saved Network Port writes and external certificate uploads.
    """
    @spec restore_changes(NetworkPort.t(), ManagedPort.snapshot()) ::
            {:ok, NetworkPort.t()} | {:error, term()}
    def restore_changes(object, snapshot) do
      with {:ok, object} <- restore_pending(object, snapshot.pending) do
        if map_size(snapshot.uploads) > 0,
          do: NetworkPort.stage_external_change(object),
          else: {:ok, object}
      end
    end

    @spec restore_pending(NetworkPort.t(), map()) :: {:ok, NetworkPort.t()} | {:error, term()}
    defp restore_pending(object, pending) do
      Enum.reduce_while(pending, {:ok, object}, fn {property, value}, {:ok, port} ->
        case NetworkPort.update_property(port, property, value) do
          {:ok, port} -> {:cont, {:ok, port}}
          error -> {:halt, error}
        end
      end)
    end

    @spec file_instances(map()) ::
            {:ok, %{ManagedPort.file_role() => non_neg_integer()}}
            | {:error, :invalid_host_objects}
    defp file_instances(files) do
      Enum.reduce_while(@file_roles, {:ok, %{}}, fn role, {:ok, ids} ->
        case files do
          %{
            ^role => %File{
              object_instance: instance,
              file_access_method: :stream_access,
              read_only: read_only,
              _metadata: %{remote_object: nil}
            }
          }
          when read_only == (role == :csr) ->
            {:cont, {:ok, Map.put(ids, role, instance)}}

          _invalid ->
            {:halt, {:error, :invalid_host_objects}}
        end
      end)
    end

    @spec matching_references?(NetworkPort.t(), %{ManagedPort.file_role() => non_neg_integer()}) ::
            boolean()
    defp matching_references?(port, ids) do
      operational = %ObjectIdentifier{type: :file, instance: ids.operational}
      csr = %ObjectIdentifier{type: :file, instance: ids.csr}

      issuers = [
        %ObjectIdentifier{type: :file, instance: ids.issuer_1},
        %ObjectIdentifier{type: :file, instance: ids.issuer_2}
      ]

      length(Enum.uniq(Map.values(ids))) == length(@file_roles) and
        port.operational_certificate_file == operational and
        port.certificate_signing_request_file == csr and
        match?(%BACnetArray{}, port.issuer_certificate_files) and
        BACnetArray.to_list(port.issuer_certificate_files) == issuers
    end
  end
end
