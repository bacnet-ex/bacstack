# This example runs a loopback hub and node.
# It creates a new CA and node certificate,
# starts a Hub and connects to the Hub, using a Node connection.

alias BACnet.Protocol.Services.WhoIs
alias BACnet.Stack.Transport.ScTransport.Credentials
alias BACnet.Stack.Transport.ScTransport.Hub
alias BACnet.Stack.Transport.ScTransport.Node, as: ScNode

ca_key = X509.PrivateKey.new_ec(:secp256r1)
ca = X509.Certificate.self_signed(ca_key, "/CN=Local BACnet SC demo", template: :root_ca)

credentials = fn name ->
  key = X509.PrivateKey.new_ec(:secp256r1)

  certificate =
    X509.Certificate.new(X509.PublicKey.derive(key), "/CN=#{name}", ca, ca_key, template: :server)

  {:ok, credentials} =
    Credentials.from_pem(X509.Certificate.to_pem(certificate), X509.PrivateKey.to_pem(key), [
      X509.Certificate.to_pem(ca)
    ])

  credentials
end

loopback = {127, 0, 0, 1}

primary_opts = [
  port: 0,
  ip: loopback,
  device_uuid: <<1::128>>,
  vmac: <<2, 0, 0, 0, 0, 1>>,
  credentials: credentials.("Primary hub")
]

{:ok, primary} = Hub.start_link(primary_opts)
primary_port = Hub.port(primary)

{:ok, failover} =
  Hub.start_link(
    port: 0,
    ip: loopback,
    device_uuid: <<2::128>>,
    vmac: <<2, 0, 0, 0, 0, 2>>,
    credentials: credentials.("Failover hub")
  )

node_options = [
  primary_hub_uri: "wss://127.0.0.1:#{primary_port}/",
  failover_hub_uri: "wss://127.0.0.1:#{Hub.port(failover)}/",
  min_reconnect_time: 2,
  max_reconnect_time: 4
]

{:ok, first} =
  ScNode.open(
    self(),
    node_options ++
      [
        device_uuid: <<3::128>>,
        vmac: <<2, 0, 0, 0, 0, 3>>,
        credentials: credentials.("First node")
      ]
  )

{:ok, second} =
  ScNode.open(
    self(),
    node_options ++
      [
        device_uuid: <<4::128>>,
        vmac: <<2, 0, 0, 0, 0, 4>>,
        credentials: credentials.("Second node")
      ]
  )

{:ok, who_is} = WhoIs.to_apdu(%WhoIs{device_id_low_limit: nil, device_id_high_limit: nil}, [])

exchange = fn role ->
  ready? =
    Enum.any?(1..200, fn _attempt ->
      if ScNode.status(first).active == role and ScNode.status(second).active == role do
        true
      else
        Process.sleep(50)
        false
      end
    end)

  unless ready?, do: raise("Both nodes did not connect to #{role}")

  :ok = ScNode.send(first, ScNode.get_broadcast_address(first), who_is)

  receive do
    {:bacnet_transport, {:bacnet_sc, ScNode}, source, {:apdu, _bvlc, _npci, _raw_apdu}, ^second} ->
      IO.puts("#{role}: received Who-Is from #{Base.encode16(source)}")
  after
    2_000 -> raise("Who-Is did not arrive via #{role}")
  end
end

exchange.(:primary)
:ok = Hub.close(primary)
exchange.(:failover)
{:ok, primary} = Hub.start_link(Keyword.put(primary_opts, :port, primary_port))
exchange.(:primary)
:ok = ScNode.close(first)
:ok = ScNode.close(second)
:ok = Hub.close(failover)
:ok = Hub.close(primary)
