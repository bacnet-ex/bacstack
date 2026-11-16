# This example has three commands:
# - `demo`:
#   The demo creates a local P-256 CA, issues an operational certificate for the
#   BACstack node, and signs the CSR of a second device. It starts that second
#   device as a loopback hub, then opens the BACstack node and sends a Who-Is
#   broadcast. The example leaves the generated credentials in the private output
#   directory.
# - `issue`:
#   Generate a certificate using the CA by supplying a separate device PEM CSR.
# - `connect`:
#   Connect to the given SC Hub using an existing CA and node certificate + key
#   in the given directory.
#   You should use `demo` or `issue` before using this command.
#
# Usage:
#   demo <new-directory>
#   issue <new-directory> <peer-csr.pem>
#   connect <directory> <wss://hub:port/path>

alias BACnet.Protocol.SecureConnect.BVLC
alias BACnet.Protocol.Services.WhoIs

alias BACnet.Stack.Transport.ScTransport.Credentials
alias BACnet.Stack.Transport.ScTransport.Hub
alias BACnet.Stack.Transport.ScTransport.Node, as: ScNode

usage = """
Usage:
  mix run examples/bacnet_sc_certificates.exs demo <new-directory>
  mix run examples/bacnet_sc_certificates.exs issue <new-directory> <peer-csr.pem>
  mix run examples/bacnet_sc_certificates.exs connect <directory> <wss://hub:port/path>
"""

device_uuid = fn ->
  <<prefix::48, _version::4, middle::12, _variant::2, suffix::62>> =
    :crypto.strong_rand_bytes(16)

  <<prefix::48, 4::4, middle::12, 2::2, suffix::62>>
end

issue = fn directory, request ->
  unless X509.CSR.valid?(request), do: raise("The peer's CSR signature is invalid")

  # Create a private directory before any key is written. Refuse to overwrite a deployment.
  File.mkdir!(directory)
  File.chmod!(directory, 0o700)

  issuer_key = X509.PrivateKey.new_ec(:secp256r1)

  issuer =
    X509.Certificate.self_signed(issuer_key, "/CN=BACnet SC example CA", template: :root_ca)

  node_key = X509.PrivateKey.new_ec(:secp256r1)

  node_certificate =
    X509.Certificate.new(
      X509.PublicKey.derive(node_key),
      "/CN=BACstack example node",
      issuer,
      issuer_key,
      template: :server
    )

  # Use the request's public key and subject. The issuer supplies its own extension policy.
  peer_certificate =
    X509.Certificate.new(
      X509.CSR.public_key(request),
      X509.CSR.subject(request),
      issuer,
      issuer_key,
      template: :server
    )

  for {name, contents} <- [
        {"ca-key.pem", X509.PrivateKey.to_pem(issuer_key)},
        {"ca.pem", X509.Certificate.to_pem(issuer)},
        {"node-key.pem", X509.PrivateKey.to_pem(node_key)},
        {"node.pem", X509.Certificate.to_pem(node_certificate)},
        {"peer.pem", X509.Certificate.to_pem(peer_certificate)},
        {"node-uuid", device_uuid.()},
        {"node-vmac", BVLC.random_vmac()}
      ] do
    path = Path.join(directory, name)
    File.write!(path, contents, [:exclusive])
    File.chmod!(path, 0o600)
  end

  IO.puts(
    "Wrote the CA certificate, node credentials, and signed peer certificate to #{directory}"
  )
end

connect = fn directory, uri ->
  read = fn name -> File.read!(Path.join(directory, name)) end

  {:ok, credentials} =
    Credentials.from_pem(read.("node.pem"), read.("node-key.pem"), [read.("ca.pem")])

  {:ok, node} =
    ScNode.open(self(),
      primary_hub_uri: uri,
      device_uuid: read.("node-uuid"),
      vmac: read.("node-vmac"),
      credentials: credentials
    )

  try do
    connected? =
      Enum.any?(1..200, fn _attempt ->
        case ScNode.status(node).active do
          :primary ->
            true

          nil ->
            Process.sleep(50)
            false
        end
      end)

    unless connected?, do: raise("The node did not complete the BACnet/SC handshake")

    IO.puts("Connected with VMAC #{Base.encode16(ScNode.get_local_address(node))}")

    {:ok, request} =
      WhoIs.to_apdu(%WhoIs{device_id_low_limit: nil, device_id_high_limit: nil}, [])

    :ok = ScNode.send(node, ScNode.get_broadcast_address(node), request)
    IO.puts("Sent a BACnet Who-Is broadcast")

    :ok = ScNode.flush(node)
  after
    :ok = ScNode.close(node)
  end
end

case System.argv() do
  ["demo", directory] ->
    # In a real deployment, the other device generates this key and sends only its CSR.
    peer_key = X509.PrivateKey.new_ec(:secp256r1)
    request = X509.CSR.new(peer_key, "/CN=Loopback example hub")
    issue.(directory, request)

    {:ok, credentials} =
      Credentials.from_pem(
        File.read!(Path.join(directory, "peer.pem")),
        X509.PrivateKey.to_pem(peer_key),
        [File.read!(Path.join(directory, "ca.pem"))]
      )

    {:ok, hub} =
      Hub.start_link(
        ip: {127, 0, 0, 1},
        port: 0,
        device_uuid: device_uuid.(),
        vmac: BVLC.random_vmac(),
        credentials: credentials
      )

    try do
      connect.(directory, "wss://127.0.0.1:#{Hub.port(hub)}/")
    after
      :ok = Hub.close(hub)
    end

  ["issue", directory, request_path] ->
    {:ok, request} =
      request_path
      |> File.read!()
      |> X509.CSR.from_pem()

    issue.(directory, request)

  ["connect", directory, uri] ->
    connect.(directory, uri)

  _args ->
    IO.puts(:stderr, usage)
    System.halt(1)
end
