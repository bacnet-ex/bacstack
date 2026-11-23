defmodule BACnet.Test.Stack.Transport.ScTransport.ComponentsTest do
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectTypes.NetworkPort
  alias BACnet.Protocol.SecureConnect.BVLC
  alias BACnet.Protocol.SecureConnect.Settings
  alias BACnet.Stack.Transport.ScTransport.Config
  alias BACnet.Stack.Transport.ScTransport.Credentials
  alias BACnet.Stack.Transport.ScTransport.Store

  use BACnet.Test.Stack.Case, async: true

  @moduletag skip: not BACstack.MixProject.sc_enabled?()

  @vmac <<2, 0, 0, 0, 0, 1>>
  @uuid <<1::size(128)>>

  test "shares SC timer defaults and limits between Network Port and runtime configuration" do
    assert {:ok, port} =
             NetworkPort.create(
               1,
               "SC Port",
               %{
                 network_type: :sc,
                 protocol_level: :bacnet_application,
                 mac_address: @vmac,
                 max_bvlc_length_accepted: BVLC.max_bvlc(),
                 max_npdu_length_accepted: BVLC.max_npdu(),
                 operational_certificate_file: %ObjectIdentifier{type: :file, instance: 10},
                 issuer_certificate_files:
                   BACnetArray.from_list(
                     [
                       %ObjectIdentifier{type: :file, instance: 11},
                       %ObjectIdentifier{type: :file, instance: 12}
                     ],
                     true
                   ),
                 certificate_signing_request_file: %ObjectIdentifier{type: :file, instance: 13}
               },
               revision: 24,
               supports_sc_hub: true
             )

    assert {:ok, active} = NetworkPort.active_configuration(port)
    runtime = Store.put_transport_settings([], active)
    assert Enum.all?(Settings.port_properties(), &NetworkPort.property_writable?(port, &1))

    for {property, {option, default, range}} <- Settings.timers() do
      assert Map.fetch!(active, property) == default
      assert Keyword.fetch!(runtime, option) == default
      assert Map.fetch!(Config.defaults(), option) == default

      for value <- [range.first, range.last] do
        assert Config.timer_valid?(option, value)
        assert {:ok, changed} = NetworkPort.update_property(port, property, value)
        assert changed.changes_pending
        assert Map.fetch!(changed, property) == value
        assert {:ok, ^active} = NetworkPort.active_configuration(changed)
      end

      for value <- [range.first - 1, range.last + 1] do
        refute Config.timer_valid?(option, value)

        assert {:error, {:invalid_property_type, ^property}} =
                 NetworkPort.update_property(port, property, value)
      end
    end
  end

  test "BVLC checks header addressing, flags, and options before applying payload rules" do
    assert {:error, 147, nil} = BVLC.decode(<<1, 8, 1::size(16), 2>>)
    assert {:error, 147, nil} = BVLC.decode(:binary.copy(<<0>>, BVLC.max_bvlc() + 1))
    assert {:error, 145, %BVLC{}} = BVLC.decode(<<1, 1, 1::size(16), 0>>)
    assert {:error, 145, %BVLC{}} = BVLC.decode(<<1, 1, 1::size(16), 129>>)
    assert {:error, 147, %BVLC{}} = BVLC.decode(<<1, 1, 1::size(16), 33, 2::size(16), 1>>)
    assert {:error, 80, %BVLC{}} = BVLC.decode(<<1, 16, 1::size(16), 0>>)
    assert {:error, 80, %BVLC{}} = BVLC.decode(<<1, 4, 1::size(16), 0::size(48), 0>>)
    assert {:error, 80, %BVLC{}} = BVLC.decode(<<1, 8, 1::size(16), 0::size(48), 0>>)
    assert {:error, 80, %BVLC{}} = BVLC.decode(<<10, 4, 1::size(16), @vmac::binary>>)
    assert {:error, 80, %BVLC{}} = BVLC.decode(<<10, 1, 1::size(16), 1>>)
    assert {:error, 7, %BVLC{}} = BVLC.decode(<<2, 4, 1::size(16), 0xFFFFFFFFFFFF::size(48)>>)
    refute BVLC.valid_vmac?(<<2>>)
    assert <<_high::size(4), 2::size(4), _remaining::size(40)>> = BVLC.random_vmac()
  end

  test "BVLC validates control payloads and correlates results" do
    for {function, payload, expected} <- [
          {:npdu, <<>>, 149},
          {:connect_request, <<1>>, 147},
          {:connect_request, BVLC.identity(@vmac, <<0::size(128)>>), 80},
          {:address_resolution_ack, <<255>>, 80},
          {:proprietary, <<1, 2>>, 147},
          {:result, <<1, 2>>, 147},
          {:result, <<1, 1, 0, 7::size(16), 80::size(16), 255>>, 80},
          {:advertisement, <<3, 0, 1024::size(16), 100::size(16)>>, 80},
          {:heartbeat_ack, <<1>>, 150}
        ] do
      frame = %BVLC{
        function: function,
        id: 30,
        source: nil,
        destination: nil,
        destination_options: [],
        data_options: [],
        payload: payload
      }

      assert {:error, ^expected, %BVLC{id: 30}} = BVLC.decode(BVLC.encode(frame))
    end

    for {function, payload} <- [
          {:connect_accept, BVLC.identity(@vmac, @uuid)},
          {:result, <<1, 0>>},
          {:address_resolution_ack, "wss://peer/"},
          {:advertisement, <<2, 1, 1024::size(16), 100::size(16)>>},
          {:proprietary, <<1, 2, 3>>}
        ] do
      frame = %BVLC{
        function: function,
        id: 30,
        source: nil,
        destination: nil,
        destination_options: [],
        data_options: [],
        payload: payload
      }

      assert {:ok, ^frame} = BVLC.decode(BVLC.encode(frame))
    end

    assert {:error, 143, %BVLC{} = unknown} = BVLC.decode(<<255, 0, 30::size(16)>>)

    assert %BVLC{id: 30, payload: <<255, 1, 0, 7::size(16), 143::size(16)>>} =
             BVLC.nak(unknown, 143)

    assert nil == BVLC.nak(BVLC.response(unknown, :result, <<1, 0>>), 80)
    broadcast = %{unknown | function: :npdu, destination: BVLC.broadcast(), payload: <<1, 0>>}
    assert nil == BVLC.nak(broadcast, 80)
  end

  test "BVLC retains destination and data options, including 4192 octets of option data" do
    options = [{1, false, nil}, {2, true, <<>>}, {3, false, :binary.copy(<<42>>, 4192)}]

    frame = %BVLC{
      function: :npdu,
      id: 5,
      source: nil,
      destination: nil,
      destination_options: options,
      data_options: options,
      payload: <<1, 0>>
    }

    assert {:ok, ^frame} = BVLC.decode(BVLC.encode(frame))
    assert BVLC.unsupported_option(frame) == 0b11100010
    assert BVLC.unsupported_option(%{frame | destination_options: [{1, false, nil}]}) == nil
  end

  test "config rejects malformed endpoints, bindings, identities, credentials, and timers" do
    options = [
      vmac: @vmac,
      device_uuid: @uuid,
      credentials: %{cert: <<>>, key: {:key, <<>>}, issuers: [<<>>]}
    ]

    assert {:ok, %{primary: nil, failover: nil, heartbeat_timeout: 300}} = Config.node(options)
    assert {:ok, %{path: "/"}} = Config.hub([{:port, 0} | options])
    assert {:ok, uri} = Config.uri("wss://localhost/sc?site=1")
    assert uri.port == 443
    assert Config.target(uri) == "/sc?site=1"
    assert {:ok, uri} = Config.uri("wss://localhost:8443/sc")
    assert uri.port == 8443
    assert Config.target(uri) == "/sc"

    for value <- [
          :bad,
          "ws://localhost/",
          "wss://user@localhost/",
          "wss://localhost/#fragment",
          "wss://localhost:0/",
          "wss:///"
        ] do
      assert {:error, :invalid_hub_uri} = Config.uri(value)
    end

    assert {:error, :invalid_hub_binding} = Config.hub([{:port, 65_536} | options])
    assert {:error, :invalid_hub_binding} = Config.hub([{:port, 0}, {:path, "sc"} | options])
    assert {:error, :invalid_vmac} = Config.hub(Keyword.put(options, :vmac, <<0::size(48)>>))

    assert {:error, :invalid_device_uuid} =
             Config.node(Keyword.put(options, :device_uuid, <<0::size(128)>>))

    assert {:error, :invalid_credentials} = Config.node(Keyword.delete(options, :credentials))
    assert {:error, :invalid_ip_family} = Config.node([{:ip_family, :local} | options])

    assert {:error, {:invalid_timer, :heartbeat_timeout}} =
             Config.node([{:heartbeat_timeout, 2} | options])
  end

  test "store locks its directory and enforces private snapshot permissions" do
    directory =
      Path.join(System.tmp_dir!(), "bacstack-sc-store-#{System.unique_integer([:positive])}")

    File.mkdir!(directory)
    on_exit(fn -> File.rm_rf(directory) end)
    private = Path.join(directory, "private")
    assert {:ok, path} = Store.open(private)
    assert {:error, :enoent} = Store.read(path)

    assert {:error, :credential_store_in_use} =
             Task.await(Task.async(fn -> Store.open(private) end))

    assert :ok = Store.write(path, %{vmac: @vmac})
    assert {:ok, %{vmac: @vmac}} = Store.read(path)
    assert {:ok, %{mode: mode}} = File.stat(path)
    assert rem(mode, 512) == 0o600
    assert :ok = Store.write(path, %{vmac: <<2::size(48)>>})
    assert {:ok, %{vmac: <<2::size(48)>>}} = Store.read(path)

    File.write!(path, :erlang.term_to_binary({2, %{}}))
    assert {:error, :invalid_sc_snapshot} = Store.read(path)
    File.write!(path, "corrupt")
    assert {:error, :invalid_sc_snapshot} = Store.read(path)
    File.chmod!(path, 0o644)
    assert {:error, :insecure_credential_store} = Store.read(path)
    File.chmod!(private, 0o755)
    assert {:error, :insecure_credential_store} = Store.open(private)
    assert {:error, :enoent} = Store.open(Path.join([directory, "missing", "private"]))
    assert {:error, :enoent} = Store.write(Path.join([directory, "missing", "snapshot"]), %{})
  end

  test "bootstraps and validates active and proposed runtime snapshots" do
    directory =
      Path.join(System.tmp_dir!(), "bacstack-sc-snapshot-#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf(directory) end)
    {:ok, path} = Store.open(directory)
    assert {:error, :missing_bootstrap_credentials} = Store.load(path, [])

    key = X509.PrivateKey.new_ec(:secp256r1)
    issuer = X509.Certificate.self_signed(key, "/CN=Store CA", template: :root_ca)
    key_pem = X509.PrivateKey.to_pem(key)
    issuer_pem = X509.Certificate.to_pem(issuer)

    cert =
      X509.Certificate.new(X509.PublicKey.derive(key), "/CN=Store node", issuer, key,
        template: :server
      )

    cert_pem = X509.Certificate.to_pem(cert)

    opts = [
      certificate_pem: cert_pem,
      private_key_pem: key_pem,
      issuer_pems: [issuer_pem],
      file_instances: %{operational: 10, issuer_1: 11, issuer_2: 12, csr: 13},
      transport: [primary_hub_uri: "wss://localhost/"]
    ]

    assert {:ok, snapshot, true} = Store.load(path, opts)
    assert {:ok, %{hub: nil, key: ^key_pem, node: node}} = Store.runtime_config(snapshot, :active)
    assert node[:primary_hub_uri] == "wss://localhost/"
    assert <<_uuid::128>> = node[:device_uuid]

    assert :ok = Store.initialize(path, %{snapshot | activation: :in_progress}, true)
    assert {:ok, ^snapshot, false} = Store.load(path, [])
    assert :ok = Store.initialize(path, snapshot, false)

    hosted_opts = [
      mode: :hosted,
      hub: [ip: {127, 0, 0, 1}, port: 0],
      objects: %{port: %{sc_heartbeat_timeout: 30}, files: hosted_files(opts[:file_instances])}
    ]

    hosted_path = Path.join(directory, "hosted.term")
    assert {:ok, hosted, true} = Store.load(hosted_path, hosted_opts ++ opts)
    assert hosted.pending == %{sc_heartbeat_timeout: 30}
    assert map_size(hosted.file_dates) == 4
    assert {:ok, %{hub: hub}} = Store.runtime_config(hosted, :proposed)
    assert hub[:heartbeat_timeout] == 30

    assert {:ok, %{snapshot: ^hosted}} =
             Store.persist(%{path: hosted_path, snapshot: nil}, hosted)

    assert {:error, {:sc_primary_hub_uri, :property, :value_out_of_range}} =
             Store.runtime_config(
               %{snapshot | pending: %{sc_primary_hub_uri: "ws://invalid/"}},
               :proposed
             )

    assert {:error, {:sc_hub_function_binding, :property, :value_out_of_range}} =
             Store.runtime_config(%{hosted | hub: [port: 65_536]}, :active)

    next_key = X509.PrivateKey.new_ec(:secp256r1)
    next_pem = X509.PrivateKey.to_pem(next_key)
    uploads = %{operational: cert_pem}

    assert {:ok, %{key: ^key_pem}} =
             Store.runtime_config(%{snapshot | csr_key: next_pem, uploads: uploads}, :proposed)

    assert {:error, {:operational_certificate_file, :security, :unknown_certificate_key}} =
             Store.runtime_config(
               %{snapshot | active_key: "invalid", csr_key: next_pem, uploads: uploads},
               :proposed
             )

    assert {:error, {:operational_certificate_file, :security, :certificate_malformed}} =
             Store.runtime_config(%{snapshot | uploads: %{operational: "invalid"}}, :proposed)

    File.write!(hosted_path, "corrupt")
    assert {:error, :invalid_sc_snapshot} = Store.load(hosted_path, opts)
  end

  defp hosted_files(instances) do
    date = BACnet.Protocol.BACnetDateTime.utc_now()
    Map.new(instances, fn {role, _id} -> {role, %{modification_date: date}} end)
  end

  test "credentials reject malformed material, invalid signatures, and expired certificates" do
    assert {:error, {:bacnet_sc_dependency, _reason}} = Config.runtime([:missing_sc_test_app])
    key = X509.PrivateKey.new_ec(:secp256r1)
    issuer = X509.Certificate.self_signed(key, "/CN=Test CA", template: :root_ca)
    other_key = X509.PrivateKey.new_ec(:secp256r1)
    other_issuer = X509.Certificate.self_signed(other_key, "/CN=Test CA", template: :root_ca)
    issuer_pem = X509.Certificate.to_pem(issuer)

    issue = fn options ->
      public_key = X509.PublicKey.derive(key)

      public_key
      |> X509.Certificate.new("/CN=Test SC node", issuer, key, options)
      |> X509.Certificate.to_pem()
    end

    certificate = issue.(template: :server)

    assert {:error, :certificate_malformed} = Credentials.certificate(nil)
    assert {:error, :certificate_malformed} = Credentials.certificate("invalid")

    assert {:error, :certificate_malformed} =
             Credentials.certificate(
               :public_key.pem_encode([{:Certificate, <<1>>, :not_encrypted}])
             )

    assert {:error, :unknown_certificate_key} = Credentials.parse_key("invalid")
    assert {:error, :certificate_invalid} = Credentials.from_key(certificate, key, [])

    assert {:error, :certificate_malformed} =
             Credentials.from_key(certificate, key, ["invalid"])

    assert {:error, :unknown_certificate_key} =
             Credentials.from_key(certificate, other_key, [issuer_pem])

    assert {:error, :certificate_invalid} =
             Credentials.from_key(certificate, key, [X509.Certificate.to_pem(other_issuer)])

    expired =
      issue.(
        template: :server,
        validity:
          X509.Certificate.Validity.new(~U[2000-01-01 00:00:00Z], ~U[2001-01-01 00:00:00Z])
      )

    assert {:error, :certificate_expired} = Credentials.from_key(expired, key, [issuer_pem])

    assert {:ok, credentials} =
             Credentials.from_pem(certificate, X509.PrivateKey.to_pem(key), [issuer_pem])

    opts = Credentials.tls(%{credentials: credentials, verify_hostname: true}, :client)
    refute Keyword.has_key?(opts, :server_name_indication)
    {verify, issuers} = opts[:verify_fun]
    assert {:valid, ^issuers} = verify.(issuer, :valid, issuers)
    {:ok, operational} = Credentials.certificate(certificate)
    assert {:valid, ^issuers} = verify.(operational, :valid_peer, issuers)
    assert {:fail, :unknown_ca} = verify.(issuer, {:bad_cert, :unknown_ca}, issuers)
    assert {:unknown, ^issuers} = verify.(issuer, {:extension, :example}, issuers)

    server = Credentials.tls(%{credentials: credentials}, :server)
    assert server[:fail_if_no_peer_cert]
    [trusted_issuer] = credentials.issuers
    partial_chain = server[:partial_chain]
    assert {:trusted_ca, ^trusted_issuer} = partial_chain.([credentials.cert, trusted_issuer])
    assert :unknown_ca = partial_chain.([credentials.cert])
    assert {:fail, :certificate_invalid} = verify.(other_issuer, :valid_peer, issuers)
  end
end
