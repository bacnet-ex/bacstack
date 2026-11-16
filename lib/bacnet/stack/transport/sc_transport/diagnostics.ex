if BACstack.MixProject.sc_enabled?() do
  defmodule BACnet.Stack.Transport.ScTransport.Diagnostics do
    @moduledoc """
    Translates BACnet/SC connection failures into BACnet communication error codes.

    Where Gun identifies a failed DNS lookup, TCP dial, or TLS handshake, use
    that stage to distinguish errors that otherwise share the same reason.
    Protocol errors retain the original BVLC code or follow Annex AB's
    WebSocket close-code table. Unknown failures use the closest known generic
    error code. These codes describe the failure for BACnet property reads and
    do not control whether or when a connection is retried.
    """

    alias BACnet.Protocol.Constants

    @websocket_codes %{
      1000 => :websocket_closed_by_peer,
      1001 => :websocket_endpoint_leaves,
      1002 => :websocket_protocol_error,
      1003 => :websocket_data_not_accepted,
      1006 => :websocket_closed_abnormally,
      1007 => :websocket_data_inconsistent,
      1008 => :websocket_data_against_policy,
      1009 => :websocket_frame_too_long,
      1010 => :websocket_extension_missing,
      1011 => :websocket_request_unavailable
    }

    @doc """
    Returns the BACnet error code for a session failure.
    """
    @spec code(term()) :: Constants.error_code() | non_neg_integer()
    def code({:connect_rejected, code}), do: code

    def code({:websocket_closed, code}), do: Map.get(@websocket_codes, code, :websocket_error)
    def code(:websocket_closed), do: :websocket_closed_by_peer
    def code(:unsupported_data), do: :websocket_data_not_accepted
    def code(:invalid_subprotocol), do: :http_websocket_header_error
    def code(:http_upgrade_timeout), do: :http_response_timeout
    def code({:http_status, 407}), do: :http_proxy_authentication_failed

    def code({:http_status, status}) when status in [301, 302, 303, 307, 308],
      do: :http_resource_not_local

    def code({:http_status, _status}), do: :http_unexpected_response_code
    def code({:http_upgrade, {:closed, {:tls_alert, _alert}}}), do: :tls_error
    def code({:http_upgrade, {:tls_alert, _alert}}), do: :tls_error
    def code({:http_upgrade, _reason}), do: :http_error
    def code(reason) when reason in [:connect_timeout, :heartbeat_timeout], do: :timeout
    def code({:dial_error, :dns, :nxdomain}), do: :dns_name_resolution_failed
    def code({:dial_error, :dns, _reason}), do: :dns_error
    def code({:dial_error, :tcp, :timeout}), do: :tcp_connect_timeout
    def code({:dial_error, :tcp, :econnrefused}), do: :tcp_connection_refused

    def code({:dial_error, :tcp, reason}) when reason in [:ehostunreach, :enetunreach],
      do: :ip_address_not_reachable

    def code({:dial_error, :tcp, _reason}), do: :tcp_error
    def code({:dial_error, :tls, {:bad_cert, :cert_expired}}), do: :tls_server_certificate_expired
    def code({:dial_error, :tls, {:bad_cert, :cert_revoked}}), do: :tls_server_certificate_revoked
    def code({:dial_error, :tls, {:bad_cert, _reason}}), do: :tls_server_certificate_error
    def code({:dial_error, :tls, _reason}), do: :tls_error
    def code({:tls_alert, _reason}), do: :tls_error
    def code(:nxdomain), do: :dns_name_resolution_failed
    def code(:econnrefused), do: :tcp_connection_refused
    def code(reason) when reason in [:ehostunreach, :enetunreach], do: :ip_address_not_reachable
    def code(reason) when reason in [:econnreset, :closed], do: :tcp_closed_other

    def code({source, reason})
        when source in [:shutdown, :error, :closed, :gun_down, :gun_error, :gun_process_down],
        do: code(reason)

    def code(_reason), do: :websocket_error

    defmodule GunEvents do
      @moduledoc """
      Relays failed DNS, TCP, and TLS operations to the SC connection process.

      Gun invokes these callbacks in its own process before reporting the
      failure or exiting. The callback state is the receiving session PID.
      Event information such as TLS options remains with Gun.
      """

      @behaviour :gun_event

      @doc false
      @impl true
      def init(_event, receiver), do: receiver

      @doc false
      @impl true
      def domain_lookup_start(_event, receiver), do: receiver

      @doc false
      @impl true
      def domain_lookup_end(event, receiver), do: report(:dns, event, receiver)

      @doc false
      @impl true
      def connect_start(_event, receiver), do: receiver

      @doc false
      @impl true
      def connect_end(event, receiver), do: report(:tcp, event, receiver)

      @doc false
      @impl true
      def tls_handshake_start(_event, receiver), do: receiver

      @doc false
      @impl true
      def tls_handshake_end(event, receiver), do: report(:tls, event, receiver)

      @doc false
      @impl true
      def request_start(_event, receiver), do: receiver

      @doc false
      @impl true
      def request_headers(_event, receiver), do: receiver

      @doc false
      @impl true
      def request_end(_event, receiver), do: receiver

      @doc false
      @impl true
      def push_promise_start(_event, receiver), do: receiver

      @doc false
      @impl true
      def push_promise_end(_event, receiver), do: receiver

      @doc false
      @impl true
      def response_start(_event, receiver), do: receiver

      @doc false
      @impl true
      def response_inform(_event, receiver), do: receiver

      @doc false
      @impl true
      def response_headers(_event, receiver), do: receiver

      @doc false
      @impl true
      def response_trailers(_event, receiver), do: receiver

      @doc false
      @impl true
      def response_end(_event, receiver), do: receiver

      @doc false
      @impl true
      def ws_upgrade(_event, receiver), do: receiver

      @doc false
      @impl true
      def ws_recv_frame_start(_event, receiver), do: receiver

      @doc false
      @impl true
      def ws_recv_frame_header(_event, receiver), do: receiver

      @doc false
      @impl true
      def ws_recv_frame_end(_event, receiver), do: receiver

      @doc false
      @impl true
      def ws_send_frame_start(_event, receiver), do: receiver

      @doc false
      @impl true
      def ws_send_frame_end(_event, receiver), do: receiver

      @doc false
      @impl true
      def protocol_changed(_event, receiver), do: receiver

      @doc false
      @impl true
      def origin_changed(_event, receiver), do: receiver

      @doc false
      @impl true
      def cancel(_event, receiver), do: receiver

      @doc false
      @impl true
      def disconnect(_event, receiver), do: receiver

      @doc false
      @impl true
      def terminate(_event, receiver), do: receiver

      @spec report(:dns | :tcp | :tls, map(), pid()) :: pid()
      defp report(stage, %{error: reason}, receiver) do
        send(receiver, {:sc_dial_error, self(), stage, reason})
        receiver
      end

      defp report(_stage, _event, receiver), do: receiver
    end
  end
end
