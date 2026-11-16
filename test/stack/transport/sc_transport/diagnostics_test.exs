defmodule BACnet.Test.Stack.Transport.ScTransport.DiagnosticsTest do
  alias BACnet.Protocol.Constants
  alias BACnet.Stack.Transport.ScTransport.Diagnostics
  alias BACnet.Stack.Transport.ScTransport.Diagnostics.GunEvents

  use BACnet.Test.Stack.Case, async: true

  @moduletag skip: not BACstack.MixProject.sc_enabled?()

  test "maps failures using the observed stage and standard wire codes" do
    for {reason, name, number} <- [
          {{:dial_error, :dns, :nxdomain}, :dns_name_resolution_failed, 190},
          {{:dial_error, :dns, :timeout}, :dns_error, 192},
          {{:dial_error, :tcp, :timeout}, :tcp_connect_timeout, 193},
          {{:dial_error, :tcp, :econnrefused}, :tcp_connection_refused, 194},
          {{:dial_error, :tcp, :ehostunreach}, :ip_address_not_reachable, 198},
          {{:dial_error, :tcp, :badarg}, :tcp_error, 197},
          {{:dial_error, :tls, {:bad_cert, :cert_expired}}, :tls_server_certificate_expired, 185},
          {{:dial_error, :tls, {:bad_cert, :cert_revoked}}, :tls_server_certificate_revoked, 187},
          {{:dial_error, :tls, {:bad_cert, :unknown_ca}}, :tls_server_certificate_error, 181},
          {{:dial_error, :tls, :handshake_failure}, :tls_error, 188},
          {{:gun_down, {:tls_alert, :unknown_ca}}, :tls_error, 188},
          {{:gun_down, :nxdomain}, :dns_name_resolution_failed, 190},
          {{:gun_process_down, {:shutdown, :econnrefused}}, :tcp_connection_refused, 194},
          {:enetunreach, :ip_address_not_reachable, 198},
          {{:gun_error, :econnreset}, :tcp_closed_other, 196},
          {{:http_status, 404}, :http_unexpected_response_code, 152},
          {{:http_status, 407}, :http_proxy_authentication_failed, 155},
          {{:http_status, 308}, :http_resource_not_local, 154},
          {{:http_upgrade, {:closed, {:tls_alert, :certificate_revoked}}}, :tls_error, 188},
          {{:http_upgrade, {:tls_alert, :unknown_ca}}, :tls_error, 188},
          {{:http_upgrade, :protocol_error}, :http_error, 165},
          {:http_upgrade_timeout, :http_response_timeout, 156},
          {:invalid_subprotocol, :http_websocket_header_error, 160},
          {:unsupported_data, :websocket_data_not_accepted, 172},
          {:heartbeat_timeout, :timeout, 30},
          {:connect_timeout, :timeout, 30},
          {:websocket_closed, :websocket_closed_by_peer, 169},
          {:unknown, :websocket_error, 179}
        ] do
      assert Diagnostics.code(reason) == name
      assert Constants.by_name!(:error_code, name) == number
    end

    assert Diagnostics.code({:connect_rejected, 151}) == 151

    for {code, expected} <-
          Enum.zip([1000, 1001, 1002, 1003, 1006, 1007, 1008, 1009, 1010, 1011], 169..178) do
      assert Constants.by_name!(:error_code, Diagnostics.code({:websocket_closed, code})) ==
               expected
    end

    assert Diagnostics.code({:websocket_closed, 4999}) == :websocket_error
  end

  test "Gun callbacks relay only the failure and its stage" do
    receiver = self()

    for {callback, stage} <- [domain_lookup_end: :dns, connect_end: :tcp, tls_handshake_end: :tls] do
      assert ^receiver =
               apply(GunEvents, callback, [%{error: :timeout, options: :omitted}, receiver])

      assert_received {:sc_dial_error, ^receiver, ^stage, :timeout}
      assert ^receiver = apply(GunEvents, callback, [%{}, receiver])
      refute_received {:sc_dial_error, ^receiver, ^stage, _reason}
    end

    for {callback, 2} <- :gun_event.behaviour_info(:callbacks) do
      assert ^receiver = apply(GunEvents, callback, [%{}, receiver])
    end
  end
end
