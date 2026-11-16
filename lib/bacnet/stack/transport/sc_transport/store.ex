if BACstack.MixProject.sc_enabled?() do
  defmodule BACnet.Stack.Transport.ScTransport.Store do
    @moduledoc """
    Persists a `BACnet.Stack.Transport.ScTransport.ManagedPort` snapshot and
    its credentials in `sc-port.term`.

    The file contains a serialized Erlang term, `{1, snapshot}`. The snapshot
    contains private keys and keeps active settings and credentials separate
    from pending property writes and certificate uploads. Startup clears any
    persisted `:activation` marker and uses the stored active credentials. Any
    pending settings and uploads remain available for later activation.

    Each managed port reserves its private directory while it is running. Writes
    sync a temporary file with permissions `0600` before replacing the
    existing snapshot in the same directory. The directory is private to the
    owner as well.
    """

    alias BACnet.Protocol.BACnetArray
    alias BACnet.Protocol.SecureConnect.BVLC
    alias BACnet.Stack.Transport.ScTransport.Config
    alias BACnet.Stack.Transport.ScTransport.Credentials
    alias BACnet.Stack.Transport.ScTransport.ManagedPort

    @file_roles [:operational, :issuer_1, :issuer_2, :csr]
    @setting_map [
      sc_primary_hub_uri: :primary_hub_uri,
      sc_failover_hub_uri: :failover_hub_uri,
      sc_minimum_reconnect_time: :min_reconnect_time,
      sc_maximum_reconnect_time: :max_reconnect_time,
      sc_connect_wait_timeout: :connect_wait_timeout,
      sc_disconnect_wait_timeout: :disconnect_wait_timeout,
      sc_heartbeat_timeout: :heartbeat_timeout
    ]

    @typep config_mode :: :active | :proposed

    @filename "sc-port.term"

    @doc """
    Prepares a private directory and reserves it for the calling process.
    Returns the path where that process can read or write its snapshot.
    """
    @spec open(Path.t()) :: {:ok, Path.t()} | {:error, term()}
    def open(directory) do
      directory = Path.expand(directory)

      with :ok <- ensure_directory(directory),
           :yes <- :global.register_name({__MODULE__, node(), directory}, self()) do
        {:ok, Path.join(directory, @filename)}
      else
        :no -> {:error, :credential_store_in_use}
        error -> error
      end
    end

    @doc """
    Loads a supported snapshot from an owner-only regular file. Returns
    `{:error, :enoent}` when the port has yet to persist its configuration.
    """
    @spec read(Path.t()) :: {:ok, map()} | {:error, term()}
    def read(path) do
      with {:ok, %{type: :regular, mode: mode}} when rem(mode, 64) == 0 <- File.lstat(path),
           {:ok, data} <- File.read(path) do
        case :erlang.binary_to_term(data, [:safe]) do
          {1, %{} = snapshot} -> {:ok, snapshot}
          _other -> {:error, :invalid_sc_snapshot}
        end
      else
        {:ok, _stat} -> {:error, :insecure_credential_store}
        error -> error
      end
    rescue
      ArgumentError -> {:error, :invalid_sc_snapshot}
    end

    @doc """
    Saves a versioned snapshot through a temporary owner-only file. The
    previous snapshot remains in place until the replacement is ready.
    """
    @spec write(Path.t(), map()) :: :ok | {:error, term()}
    def write(path, snapshot) do
      temporary = path <> "." <> Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)

      try do
        with {:ok, file} <- :file.open(temporary, [:write, :raw, :binary, :exclusive]),
             :ok <- write_snapshot(file, temporary, snapshot) do
          File.rename(temporary, path)
        end
      after
        File.rm(temporary)
      end
    end

    @spec write_snapshot(:file.io_device(), Path.t(), map()) :: :ok | {:error, term()}
    defp write_snapshot(file, path, snapshot) do
      with :ok <- File.chmod(path, 0o600),
           :ok <- :file.write(file, :erlang.term_to_binary({1, snapshot})) do
        :file.sync(file)
      end
    after
      :file.close(file)
    end

    @spec ensure_directory(Path.t()) :: :ok | {:error, term()}
    defp ensure_directory(directory) do
      case File.mkdir(directory) do
        :ok ->
          File.chmod(directory, 0o700)

        {:error, :eexist} ->
          case File.lstat(directory) do
            {:ok, %{type: :directory, mode: mode}} when rem(mode, 64) == 0 -> :ok
            _other -> {:error, :insecure_credential_store}
          end

        error ->
          error
      end
    end

    @doc """
    Loads an existing snapshot or initializes one from local bootstrap options.
    The third return element indicates whether the initial snapshot needs writing.
    """
    @spec load(Path.t(), Keyword.t()) ::
            {:ok, ManagedPort.snapshot(), boolean()} | {:error, term()}
    def load(path, opts) do
      case read(path) do
        {:ok, snapshot} ->
          {:ok, %{snapshot | activation: nil}, false}

        {:error, :enoent} ->
          with {:ok, snapshot} <- bootstrap(opts), do: {:ok, snapshot, true}

        error ->
          error
      end
    end

    @doc """
    Persists a fresh bootstrap snapshot. Existing snapshots already reside on disk.
    """
    @spec initialize(Path.t(), ManagedPort.snapshot(), boolean()) :: :ok | {:error, term()}
    def initialize(path, snapshot, true), do: write(path, snapshot)
    def initialize(_path, _snapshot, false), do: :ok

    @doc """
    Validates the active or proposed snapshot and returns the options needed
    by its node and optional hub. Proposed configuration includes staged writes
    and uploads.
    """
    @spec runtime_config(ManagedPort.snapshot(), config_mode(), Keyword.t() | nil) ::
            {:ok, ManagedPort.runtime_config()} | {:error, {atom(), atom(), atom()}}
    def runtime_config(snapshot, mode, hub_audit \\ nil) do
      settings =
        if mode == :active,
          do: snapshot.active,
          else: Map.merge(snapshot.active, snapshot.pending)

      files =
        if mode == :active,
          do: snapshot.certificates,
          else: Map.merge(snapshot.certificates, snapshot.uploads)

      issuer_pems = Enum.reject([files.issuer_1, files.issuer_2], &(&1 == ""))

      with {:ok, credentials, key} <- credentials(snapshot, files, issuer_pems, mode),
           node <- node_options(snapshot, settings, credentials),
           {:ok, _config} <- annotate(Config.node(node), :sc_primary_hub_uri),
           hub <- hub_options(snapshot, settings, node),
           hub <- if(hub && hub_audit, do: Keyword.put(hub, :audit, hub_audit), else: hub),
           :ok <- validate_hub(hub) do
        {:ok, %{node: node, hub: hub, key: key}}
      end
    end

    @spec credentials(
            ManagedPort.snapshot(),
            %{operational: binary(), issuer_1: binary(), issuer_2: binary()},
            [binary()],
            config_mode()
          ) ::
            {:ok, Credentials.t(), binary()}
            | {:error, {:operational_certificate_file, :security, atom()}}
    defp credentials(snapshot, files, issuers, mode) do
      preferred =
        if mode == :proposed and snapshot.uploads[:operational],
          do: snapshot.csr_key || snapshot.active_key,
          else: snapshot.active_key

      with {:ok, key} <- Credentials.parse_key(preferred),
           {:ok, credentials} <- Credentials.from_key(files.operational, key, issuers) do
        {:ok, credentials, preferred}
      else
        {:error, :unknown_certificate_key} when preferred != snapshot.active_key ->
          with {:ok, key} <- Credentials.parse_key(snapshot.active_key),
               {:ok, credentials} <- Credentials.from_key(files.operational, key, issuers) do
            {:ok, credentials, snapshot.active_key}
          else
            {:error, reason} -> {:error, {:operational_certificate_file, :security, reason}}
          end

        {:error, reason} ->
          {:error, {:operational_certificate_file, :security, reason}}
      end
    end

    @spec annotate({:ok, config} | {:error, term()}, atom()) ::
            {:ok, config} | {:error, {atom(), :property, :value_out_of_range}}
          when config: var
    defp annotate({:error, _reason}, property),
      do: {:error, {property, :property, :value_out_of_range}}

    defp annotate(result, _property), do: result

    @spec validate_hub(Keyword.t() | nil) ::
            :ok | {:error, {:sc_hub_function_binding, :property, :value_out_of_range}}
    defp validate_hub(nil), do: :ok

    defp validate_hub(hub) do
      with {:ok, _config} <- annotate(Config.hub(hub), :sc_hub_function_binding), do: :ok
    end

    @spec node_options(ManagedPort.snapshot(), map(), Credentials.t()) :: Keyword.t()
    defp node_options(snapshot, settings, credentials) do
      transport = put_transport_settings(snapshot.transport, settings)

      transport
      |> Keyword.put(:credentials, credentials)
      |> Keyword.put(:status_receiver, self())
    end

    @spec hub_options(ManagedPort.snapshot(), map(), Keyword.t()) :: Keyword.t() | nil
    defp hub_options(snapshot, %{sc_hub_function_enable: true}, node)
         when not is_nil(snapshot.hub) do
      shared =
        Keyword.take(node, [
          :vmac,
          :device_uuid,
          :credentials,
          :connect_wait_timeout,
          :disconnect_wait_timeout,
          :heartbeat_timeout,
          :crl_check
        ])

      Keyword.merge(snapshot.hub, shared)
    end

    defp hub_options(_snapshot, _settings, _node), do: nil

    @doc """
    Puts the SC connector settings from BACnet properties into the node options.
    """
    @spec put_transport_settings(Keyword.t(), map()) :: Keyword.t()
    def put_transport_settings(transport, settings) do
      Enum.reduce(@setting_map, transport, fn {property, option}, acc ->
        Keyword.put(acc, option, Map.fetch!(settings, property))
      end)
    end

    @doc """
    Writes a staged snapshot before returning the state for a managed change.
    """
    @spec persist(ManagedPort.state(), ManagedPort.snapshot()) ::
            {:ok, ManagedPort.state()} | {:error, term()}
    def persist(state, snapshot) do
      with :ok <- write(state.path, snapshot), do: {:ok, %{state | snapshot: snapshot}}
    end

    @spec bootstrap(Keyword.t()) ::
            {:ok, ManagedPort.snapshot()} | {:error, :missing_bootstrap_credentials}
    defp bootstrap(opts) do
      transport = opts[:transport] || []

      with issuers when is_list(issuers) and length(issuers) in 1..2 <- opts[:issuer_pems],
           cert when is_binary(cert) <- opts[:certificate_pem],
           key when is_binary(key) <- opts[:private_key_pem] do
        transport =
          transport
          |> Keyword.take([:vmac, :device_uuid, :verify_hostname, :crl_check, :ip_family])
          |> Keyword.put_new_lazy(:vmac, &BVLC.random_vmac/0)
          |> Keyword.put_new_lazy(:device_uuid, &uuid/0)

        configured = opts[:transport] || []
        defaults = Config.defaults()

        settings =
          Map.new(@setting_map, fn {property, key} ->
            {property, configured[key] || defaults[key] || ""}
          end)

        settings = Map.put(settings, :network_number, opts[:network_number] || 0)

        settings =
          if opts[:hub] do
            Map.merge(settings, %{
              sc_hub_function_enable: Keyword.get(opts[:hub], :enabled, true),
              sc_hub_function_accept_uris: BACnetArray.from_list(opts[:hub][:accept_uris] || [])
            })
          else
            settings
          end

        {:ok,
         %{
           transport: transport,
           hub: opts[:hub] && Keyword.take(opts[:hub], [:ip, :port, :path]),
           files: opts[:file_instances],
           active: settings,
           pending: initial_pending(opts, settings),
           certificates: %{
             operational: cert,
             issuer_1: hd(issuers),
             issuer_2: Enum.at(issuers, 1, "")
           },
           uploads: %{},
           file_dates: initial_file_dates(opts),
           upload_dates: %{},
           active_key: key,
           csr: "",
           csr_key: nil,
           activation: nil
         }}
      else
        _other -> {:error, :missing_bootstrap_credentials}
      end
    end

    @spec initial_file_dates(Keyword.t()) :: %{
            ManagedPort.file_role() => BACnet.Protocol.BACnetDateTime.t()
          }
    defp initial_file_dates(opts) do
      if opts[:mode] == :hosted do
        Map.new(@file_roles, fn role -> {role, opts[:objects].files[role].modification_date} end)
      else
        %{}
      end
    end

    @spec initial_pending(Keyword.t(), map()) :: map()
    defp initial_pending(opts, active) do
      if opts[:mode] == :hosted do
        opts[:objects].port
        |> Map.take(Map.keys(active))
        |> Map.reject(fn {property, value} -> active[property] == value end)
      else
        %{}
      end
    end

    @spec uuid() :: <<_::128>>
    defp uuid() do
      <<prefix::size(48), _version::size(4), middle::size(12), _variant::size(2),
        suffix::size(62)>> =
        :crypto.strong_rand_bytes(16)

      <<prefix::size(48), 4::size(4), middle::size(12), 2::size(2), suffix::size(62)>>
    end
  end
end
