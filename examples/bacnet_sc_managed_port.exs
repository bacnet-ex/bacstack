# This example issues temporary certificates and starts a standalone ManagedPort
# and a discovery node on a loopback BACnet/SC hub. The discovery node sends
# Who-Is, then prints the device instance, VMAC, and APDU limit from the reply.

alias BACnet.Protocol.APDU
alias BACnet.Protocol.Services.IAm
alias BACnet.Protocol.Services.WhoIs
alias BACnet.Stack.Transport.ScTransport.Credentials
alias BACnet.Stack.Transport.ScTransport.Hub
alias BACnet.Stack.Transport.ScTransport.ManagedPort
alias BACnet.Stack.Transport.ScTransport.Node, as: ScNode

ca_key = X509.PrivateKey.new_ec(:secp256r1)
ca = X509.Certificate.self_signed(ca_key, "/CN=Managed BACnet SC demo CA", template: :root_ca)
issuer_pem = X509.Certificate.to_pem(ca)

issue = fn name ->
  key = X509.PrivateKey.new_ec(:secp256r1)

  cert =
    X509.Certificate.new(X509.PublicKey.derive(key), "/CN=#{name}", ca, ca_key, template: :server)

  {X509.Certificate.to_pem(cert), X509.PrivateKey.to_pem(key)}
end

credentials = fn name ->
  {certificate, key} = issue.(name)
  {:ok, credentials} = Credentials.from_pem(certificate, key, [issuer_pem])
  credentials
end

storage_dir =
  Path.join(
    System.tmp_dir!(),
    "bacstack-sc-managed-" <> Base.encode16(:crypto.strong_rand_bytes(8))
  )

{:ok, supervisor} = Supervisor.start_link([], strategy: :one_for_one)

try do
  {:ok, hub} =
    Supervisor.start_child(
      supervisor,
      {Hub,
       ip: {127, 0, 0, 1},
       port: 0,
       device_uuid: <<1::128>>,
       vmac: <<2, 0, 0, 0, 0, 1>>,
       credentials: credentials.("Demo hub")}
    )

  uri = "wss://127.0.0.1:#{Hub.port(hub)}/"
  {certificate, private_key} = issue.("Standalone managed port")
  device_instance = 123

  {:ok, managed} =
    Supervisor.start_child(
      supervisor,
      {ManagedPort,
       mode: :standalone,
       storage_dir: storage_dir,
       device_instance: device_instance,
       device_name: "Standalone SC demo",
       port_instance: 1,
       vendor_id: 0,
       file_instances: %{operational: 10, issuer_1: 11, issuer_2: 12, csr: 13},
       certificate_pem: certificate,
       private_key_pem: private_key,
       issuer_pems: [issuer_pem],
       transport: [primary_hub_uri: uri]}
    )

  %{transport: node} = ManagedPort.endpoints(managed)

  {:ok, requester} =
    Supervisor.start_child(
      supervisor,
      ScNode.child_spec(self(),
        primary_hub_uri: uri,
        device_uuid: <<2::128>>,
        vmac: <<2, 0, 0, 0, 0, 2>>,
        credentials: credentials.("Discovery requester")
      )
    )

  connected? =
    Enum.any?(1..200, fn _attempt ->
      if ScNode.status(node).active == :primary and ScNode.status(requester).active == :primary do
        true
      else
        Process.sleep(50)
        false
      end
    end)

  unless connected?, do: raise("The managed port and requester did not connect to #{uri}")

  {:ok, who_is} =
    WhoIs.to_apdu(
      %WhoIs{device_id_low_limit: device_instance, device_id_high_limit: device_instance},
      []
    )

  :ok = ScNode.send(requester, ScNode.get_broadcast_address(requester), who_is)
  managed_vmac = ScNode.get_local_address(node)

  receive do
    {:bacnet_transport, {:bacnet_sc, ScNode}, ^managed_vmac, {:apdu, _bvlc, _npci, raw},
     ^requester} ->
      {:ok, apdu} = APDU.decode(raw)
      {:ok, %IAm{device: %{instance: ^device_instance}, max_apdu: max_apdu}} = IAm.from_apdu(apdu)

      IO.puts(
        "Discovered Device #{device_instance} at VMAC #{Base.encode16(managed_vmac)} (max APDU #{max_apdu})"
      )
  after
    2_000 -> raise("The standalone managed port did not respond to Who-Is")
  end
after
  Supervisor.stop(supervisor)
  File.rm_rf!(storage_dir)
end
