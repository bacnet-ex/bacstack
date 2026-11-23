if BACstack.MixProject.sc_enabled?() do
  defmodule BACnet.Stack.Transport.ScTransport.Config do
    alias BACnet.Protocol.SecureConnect.BVLC
    alias BACnet.Protocol.SecureConnect.Settings
    alias BACnet.Stack.Transport.ScTransport.Audit

    @timers Enum.map(Settings.timers(), fn {_property, {option, default, range}} ->
              {option, {default, range}}
            end)

    @moduledoc """
    Validates and normalizes configuration shared by BACnet/SC nodes and hubs.

    Both roles use a six-octet VMAC, a 16-octet Device UUID, site credentials,
    and timers expressed in seconds. The node adds outbound hub URIs. The hub
    adds the socket binding and WebSocket path it accepts.

    This module also checks the runtime before the transport starts. BACnet/SC
    uses optional dependencies on OTP 27 and later. A startup failure identifies
    the unavailable application or invalid setting.

    ## Timers

    | Option | Default | Range | Unit |
    | --- | ---: | --- | --- |
    #{Enum.map_join(@timers, "\n", fn {option, {default, range}} -> "| `#{inspect(option)}` | #{default} | #{range.first}–#{range.last} | seconds |" end)}

    Reconnect timers apply to the `BACnet.Stack.Transport.ScTransport.Node`
    connector. Session timers apply to both node and hub connections.
    """

    @typedoc """
    Options passed to `node/1` or `hub/1`.

    Both accept the device's `:vmac`, `:device_uuid`, `:credentials`,
    and the timer overrides listed above. Node options include
    `:primary_hub_uri`, `:failover_hub_uri`, and `:ip_family`.
    Hub options include `:port`, `:ip`, `:path`, and `:audit`. Other options,
    such as TLS settings, pass through to the transport process.
    """
    @type options :: Keyword.t()

    @typedoc """
    A configurable BACnet/SC timer. Values passed to the configuration API are
    in seconds.
    """
    @type timer ::
            :min_reconnect_time
            | :max_reconnect_time
            | :connect_wait_timeout
            | :disconnect_wait_timeout
            | :heartbeat_timeout

    @typedoc """
    Validated node configuration with parsed primary and failover endpoints.
    """
    @type node_config :: %{
            required(:vmac) => BVLC.vmac(),
            required(:device_uuid) => <<_::128>>,
            required(:credentials) => BACnet.Stack.Transport.ScTransport.Credentials.t(),
            required(:primary) => URI.t() | nil,
            required(:failover) => URI.t() | nil,
            required(:min_reconnect_time) => pos_integer(),
            required(:max_reconnect_time) => pos_integer(),
            required(:connect_wait_timeout) => pos_integer(),
            required(:disconnect_wait_timeout) => pos_integer(),
            required(:heartbeat_timeout) => pos_integer(),
            optional(atom()) => term()
          }

    @typedoc """
    Validated hub configuration with a socket port and WebSocket path.
    """
    @type hub_config :: %{
            required(:vmac) => BVLC.vmac(),
            required(:device_uuid) => <<_::128>>,
            required(:credentials) => BACnet.Stack.Transport.ScTransport.Credentials.t(),
            required(:port) => :inet.port_number(),
            required(:path) => String.t(),
            required(:crl_check) => term(),
            required(:audit) => Audit.config() | nil,
            required(:connect_wait_timeout) => pos_integer(),
            required(:disconnect_wait_timeout) => pos_integer(),
            required(:heartbeat_timeout) => pos_integer(),
            optional(atom()) => term()
          }

    @doc """
    Checks that BACnet/SC can run on the current OTP release and starts the
    applications needed for the requested role.
    """
    @spec runtime([Application.app()]) ::
            :ok | {:error, :bacnet_sc_requires_otp_27 | {:bacnet_sc_dependency, term()}}
    def runtime(required_apps) do
      if String.to_integer(System.otp_release()) < 27 do
        {:error, :bacnet_sc_requires_otp_27}
      else
        Enum.reduce_while(required_apps, :ok, fn app, :ok ->
          case Application.ensure_all_started(app) do
            {:ok, _started_apps} -> {:cont, :ok}
            {:error, reason} -> {:halt, {:error, {:bacnet_sc_dependency, reason}}}
          end
        end)
      end
    end

    @doc """
    Returns the default BACnet/SC timer values in seconds.
    """
    @spec defaults() :: %{timer() => pos_integer()}
    def defaults(), do: Map.new(@timers, fn {key, {default, _range}} -> {key, default} end)

    @doc """
    Checks a value against the supported range in seconds for the specified timer.
    """
    @spec timer_valid?(timer(), term()) :: boolean()
    def timer_valid?(key, value) do
      {_default, range} = Keyword.fetch!(@timers, key)
      value in range
    end

    @doc """
    Validates node options and resolves the primary and failover URIs into
    parsed endpoints. An empty URI means that hub is unconfigured.

    Invalid input returns `:invalid_vmac`, `:invalid_device_uuid`,
    `:invalid_credentials`, `{:invalid_timer, timer}`, `:invalid_hub_uri`, or
    `:invalid_ip_family` in an error tuple.
    """
    @spec node(options()) :: {:ok, node_config()} | {:error, term()}
    def node(opts) do
      config = normalize(opts)

      with :ok <- validate(config),
           {:ok, primary} <- uri(config[:primary_hub_uri]),
           {:ok, failover} <- uri(config[:failover_hub_uri]) do
        if Map.get(config, :ip_family, :inet) in [:inet, :inet6],
          do: {:ok, Map.merge(config, %{primary: primary, failover: failover})},
          else: {:error, :invalid_ip_family}
      end
    end

    @doc """
    Validates hub options and supplies the default WebSocket path. Port zero
    asks the operating system to assign a listening port.

    Invalid input returns `:invalid_vmac`, `:invalid_device_uuid`,
    `:invalid_credentials`, `{:invalid_timer, timer}`, `:invalid_audit_options`,
    or `:invalid_hub_binding` in an error tuple.
    """
    @spec hub(options()) :: {:ok, hub_config()} | {:error, term()}
    def hub(opts) do
      config = normalize(opts)

      with :ok <- validate(config),
           {:ok, audit} <- Audit.configure(config[:audit]),
           port when port in 0..65_535 <- config[:port],
           true <- :inet.is_ip_address(Map.get(config, :ip, {0, 0, 0, 0})),
           <<"/", _path::binary>> <- Map.get(config, :path, "/") do
        config =
          config
          |> Map.put_new(:ip, {0, 0, 0, 0})
          |> Map.put_new(:path, "/")
          |> Map.put_new(:crl_check, false)
          |> Map.put(:audit, audit)

        {:ok, config}
      else
        {:error, _reason} = error -> error
        _other -> {:error, :invalid_hub_binding}
      end
    end

    @doc """
    Parses a configured `wss` URI. A missing port defaults to 443, and a
    missing path defaults to `/`. Empty configuration returns `{:ok, nil}`.
    """
    @spec uri(term()) :: {:ok, URI.t() | nil} | {:error, :invalid_hub_uri}
    def uri(value) when value in [nil, ""], do: {:ok, nil}

    def uri(value) when is_binary(value) do
      case URI.new(value) do
        {:ok, %URI{scheme: "wss", host: host, port: port, userinfo: nil, fragment: nil} = uri}
        when is_binary(host) and host != "" and (is_nil(port) or port in 1..65_535) ->
          {:ok, %{uri | port: port || 443, path: uri.path || "/"}}

        _other ->
          {:error, :invalid_hub_uri}
      end
    end

    def uri(_value), do: {:error, :invalid_hub_uri}

    @doc """
    Returns the HTTP request target for a parsed hub URI, including its query
    string when present.
    """
    @spec target(URI.t()) :: String.t()
    def target(%URI{path: path, query: nil}), do: path
    def target(%URI{path: path, query: query}), do: path <> "?" <> query

    @spec normalize(options()) :: map()
    defp normalize(opts), do: Map.merge(defaults(), Map.new(opts))

    @spec validate(map()) :: :ok | {:error, atom() | {:invalid_timer, timer()}}
    defp validate(config) do
      cond do
        not BVLC.valid_vmac?(config[:vmac]) ->
          {:error, :invalid_vmac}

        not match?(<<_uuid::size(128)>>, config[:device_uuid]) or
            config[:device_uuid] == <<0::size(128)>> ->
          {:error, :invalid_device_uuid}

        not match?(
          %{cert: _cert, key: _key, issuers: [_first_issuer | _rest]},
          config[:credentials]
        ) ->
          {:error, :invalid_credentials}

        true ->
          case Enum.find(@timers, fn {key, _limits} -> not timer_valid?(key, config[key]) end) do
            nil -> :ok
            {key, _limits} -> {:error, {:invalid_timer, key}}
          end
      end
    end
  end
end
