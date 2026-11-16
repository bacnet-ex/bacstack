<!--t:BACnet Secure Connect-->

BACstack's experimental BACnet/SC support includes a node and hub using the
`hub.bsc.bacnet.org` WebSocket subprotocol over mutual TLS 1.3. A node can
switch to a failover hub and return to the primary. Managed ports expose SC
configuration and certificate management at Protocol Revision 24. Node and
hub connections support IPv4 and IPv6. Direct connections (`dc.bsc.bacnet.org`)
are outside the implementation.
The user handles factory reset and distribution of certificate revocation lists (CRLs).

## Dependencies

BACnet/SC runs on Erlang/OTP 27 or newer. Applications consuming BACstack as a
dependency must add [Cowboy](https://hex.pm/packages/cowboy) 2.21+,
[Gun](https://hex.pm/packages/gun) 2.8+ and
[X509](https://hex.pm/packages/x509) 0.9.2+ for BACnet/SC.

## Implemented BACnet addenda

- **ANSI/ASHRAE Addendum bj to Standard 135-2016**, with the June 2020
  errata, defines the BACnet/SC datalink. BACstack implements the node hub
  connector, hub forwarding, and failover and return to the primary hub.
- **ANSI/ASHRAE Addendum cc to Standard 135-2020** defines BACnet/SC
  configuration and certificate management at Protocol Revision 24.
  BACstack implements the SC Network Port properties, connector and hub
  diagnostics, staged changes, and the certificate renewal workflow.

## Trust model

The node and hub verify the TLS peer's operational certificate against a
configured site issuer. Any peer that passes the certificate checks can join
as a trusted SC participant. It claims its VMAC and Device UUID in
Connect-Request. Those values have no binding to the certificate. For a
forwarded BACnet request, `:authorize` receives the VMAC asserted by the hub.
Use that information within the site's hub and issuer trust policy. Hub
hostname verification is off by default per Addendum bj YY.7.4. Enable it
with `:verify_hostname` when the deployment requires it.

## Hub traffic audit

Hub auditing lets you review BACnet traffic that passed through a Secure
Connect hub. You can see which peer requested a property write, which value
and priority it supplied, and how the target replied when the hub observed
a response. You can also capture raw routed frames for troubleshooting.
The hub delivers these records to your application's audit sink for storage.

Auditing is off by default. To enable it on a standalone hub, pass `:audit`
to `BACnet.Stack.Transport.ScTransport.Hub.start_link/1`. For a local Managed
Port hub, put `:audit` inside its `:hub` options.
Supply the sink each time the host starts the port. The Managed Port keeps
it in runtime configuration through settings activation.

```elixir
audit = [
  mode: :writes,
  sink: &MyApp.AuditLog.append/1,
  queue_limit: 1_024
]

{:ok, hub} =
  BACnet.Stack.Transport.ScTransport.Hub.start_link(Keyword.put(hub_options, :audit, audit))
```

Implement `MyApp.AuditLog.append/1` in the host application. It receives an
`BACnet.Stack.Transport.ScTransport.Audit.Event` and returns `:ok` when it
accepts the event or `{:error, reason}` on failure. The application chooses
how to persist, index, and retain the records.

- `:writes` emits `:write_request` events for WriteProperty and
  WritePropertyMultiple. Each requested property comes with its object,
  optional array index, value, and supplied priority.
- `:traffic` adds a `:frame` event with the original BVLC payload and options
  for each frame that reaches the hub's routing path, including dropped
  frames. A broadcast generates one record with a queued-recipient count.
  The recipient connection can still drop a queued frame. Connection-local
  messages and traffic that bypasses this hub are outside the capture boundary.

To review writes, filter `:write_request` by `timestamp` and the entries in
`details.writes`. Filter by `ingress.certificate_sha256` or `ingress.uuid` for
the sending SC peer. Use `destination_vmac` or `egress.uuid` for the receiving
SC peer, and `npci.source` and `npci.destination` for addresses carried by
routers. The peer's certificate fingerprint identifies its TLS certificate.
The VMAC and UUID are asserted during BACnet/SC registration. Map these
addresses to your site inventory to search by a device name or instance.

Join `:write_result` events using `details.write_id`. Retransmissions of an
outstanding write share that ID. A result can record an acknowledgment,
error, rejection, or server abort observed on the reverse path. An
acknowledgment records the BACnet response to the request. Determining
the device's effective value requires a separate observation.
`:reply_not_observed` marks an outstanding request whose 60-second reply
window expired. `:write_diagnostic` reports identifiable writes that could
not be decoded or whose segments could not be assembled within audit limits.

The hub continues forwarding while the bounded audit queue or sink is
unavailable. Poll `BACnet.Stack.Transport.ScTransport.Hub.audit_status/1`
for queue drops, sink failures, and correlation losses.
After a capture gap the hub continues recording writes and pauses
reply matching for one reply window. Captures still queued at hub shutdown
or when audit settings change may be lost.

See also `BACnet.Stack.Transport.ScTransport.Audit`.

## Certificate revocation lists

The typical setup is to have the site CA publish a signed CRL at a stable
distribution-point URI for each issuer. Include that URI in the issuer's operational
certificates. Use the site's device-management channel to deliver each list
to every node and hub, including both issuers' lists during CA rotation.
Keep a local copy and reload it before starting the SC transports after a restart.

Load the PEM CRL into OTP's SSL cache under the URI from the certificate.
The default OTP 27 cache accepts an HTTP distribution-point URI as its lookup
key. Preloading the file lets TLS look it up locally during the handshake.
Use the URI and local path for your deployment. See the
[OTP SSL CRL cache documentation](https://www.erlang.org/docs/27/apps/ssl/ssl_crl_cache.html#insert/2).

```elixir
{:ok, _apps} = Application.ensure_all_started(:ssl)

:ok =
  :ssl_crl_cache.insert(
    ~c"http://pki.example.net/sc-issuer.crl",
    {:file, ~c"/etc/bacstack/sc-issuer-crl.pem"}
  )
```

Set `crl_check: :peer` in the startup options for
`BACnet.Stack.Transport.ScTransport.Node.open/2` and
`BACnet.Stack.Transport.ScTransport.Hub.start_link/1`. For a new
`BACnet.Stack.Transport.ScTransport.ManagedPort`, put it in `:transport`.
The managed port stores that setting in its snapshot and applies it to its
node and any local hub. OTP then requires a valid revocation result for the
peer certificate during TLS authentication. A missing or stale CRL can
prevent new connections. See [OTP TLS certificate options](https://www.erlang.org/docs/27/apps/ssl/ssl.html#t:common_option_cert/0).

Refresh each cached list before its `nextUpdate` and alert if refresh fails.
The new list applies at the next full TLS handshake. When a revocation must
take effect immediately, load the updated CRL before reconnecting affected
sessions. Use `BACnet.Stack.Transport.ScTransport.Hub.restart_connections/1`
to restart a hub's peer sessions while keeping its listener open.

## Secure factory reset

Addendum bj requires the finished device to provide a secure out-of-band
factory reset. The application or device host must implement that reset.
Restrict access to a trusted local administrator or a physical service
mechanism. BACnet `ReinitializeDevice` operations on a ManagedPort apply or
restart its configuration and do not put the device into factory defaults.

During a factory reset, the host needs to:

1. Stop all SC nodes, listeners, and managed ports before clearing their
   storage. Keep them stopped until the reset has completed.
2. Erase the operational certificates, their private keys, and the trusted
   site issuers across **all** SC ports. This includes staged uploads and
   generated CSR keys in ManagedPort snapshots, as well as any bootstrap
   credential copies held in host configuration or a key store.
3. Erase other site-sensitive device data and prevent recovery from local
   copies under the device's control. Use an erase mechanism appropriate for
   the storage medium. For example, where data is encrypted under a dedicated
   storage key, the device can destroy that key as part of the reset.
4. Verify that a reboot leaves the device without site credentials. Gate
   startup so an old bootstrap configuration cannot reinstall erased material.
   Enrollment for the next site must be an explicit local operation.

Treat a reset as incomplete if the device cannot erase or verify its
site-sensitive state. Test the reset on the actual device, including when a
certificate change is pending and when the device hosts multiple SC ports.

## Transport quick start

Run `mix run examples/bacnet_sc.exs` from the checkout to see two nodes
exchange traffic over primary and failover hubs on loopback.

A regular BACnet client receives SC datagrams through the same transport
callback used by other transports. The following connects it to an existing
hub using the PEM files from the enrollment example. The example reads the persistent UUID and VMAC created at enrollment. Use the
current VMAC of the destination device for unicast requests.

```elixir
alias BACnet.Stack.Client
alias BACnet.Stack.ClientHelper
alias BACnet.Stack.Segmentator
alias BACnet.Stack.SegmentsStore
alias BACnet.Stack.Transport.ScTransport.Credentials
alias BACnet.Stack.Transport.ScTransport.Node, as: ScNode

directory = "sc-site"
{:ok, credentials} =
  Credentials.from_pem(
    File.read!(Path.join(directory, "node.pem")),
    File.read!(Path.join(directory, "node-key.pem")),
    [File.read!(Path.join(directory, "ca.pem"))]
  )

{:ok, node} =
  ScNode.open(:sc_client,
    primary_hub_uri: "wss://hub.example:443/",
    device_uuid: File.read!(Path.join(directory, "node-uuid")),
    vmac: File.read!(Path.join(directory, "node-vmac")),
    credentials: credentials
  )

{:ok, segmentator} = Segmentator.start_link([])
{:ok, segments_store} = SegmentsStore.start_link([])
{:ok, client} =
  Client.start_link(
    name: :sc_client,
    transport: {ScNode, node},
    segmentator: segmentator,
    segments_store: segments_store
  )

connected? =
  Enum.any?(1..100, fn _attempt ->
    Process.sleep(100)
    ScNode.status(node).active == :primary
  end)

unless connected?, do: raise("BACnet/SC hub connection did not become active")
{:ok, devices} = ClientHelper.who_is(client, 2_000)
```

Use `:failover_hub_uri` for a backup and `:status_receiver` to receive
`{:sc_vmac, transport_pid, new_vmac}` if a VMAC collision requires a new
address. Persist the new VMAC when your application owns the node identity.

Use a bracketed address in an IPv6 URI such as `wss://[::1]:4443/`.
For a hostname that should resolve over IPv6, set `ip_family: :inet6`
in the node options. A hub selects the listening family from its `:ip`
tuple and binds IPv4 by default. The Node and Hub moduledocs describe
the configurable timers.

## Certificate enrollment example

Run the example on OTP 27 or later. Give it a directory that does not exist.

```sh
mix run examples/bacnet_sc_certificates.exs demo ./sc-demo
```

The demo creates a local P-256 CA, issues an operational certificate for the
BACstack node, and signs the CSR of a second device. It starts that second
device as a loopback hub, then opens the BACstack node and sends a Who-Is
broadcast. The example leaves the generated credentials in the private output
directory.

For a separate device, have it generate a key and export its PEM CSR. Review
the identity in the request before issuing a certificate.

```sh
mix run examples/bacnet_sc_certificates.exs issue ./sc-site ./hub-csr.pem
```

Install `peer.pem` and `ca.pem` on the hub alongside the hub's existing private
key. Configure the hub to trust `ca.pem` and start its SC listener. Keep
`ca-key.pem` with the issuer and `node-key.pem` with the node.

```sh
mix run examples/bacnet_sc_certificates.exs connect ./sc-site wss://hub.example:443/
```

## Managed Network Port

Start `BACnet.Stack.Transport.ScTransport.ManagedPort` under a supervisor.
Standalone mode is the default. Supply the
Device and Network Port instance numbers, vendor ID, and the four certificate
File instances. Supply a private storage directory and the initial operational
certificate, private key, and issuer certificates locally. The service persists
active and pending settings and retains its Device UUID on restart. The
`:authorize` callback receives the decoded request and originating VMAC and
routed source. Grant write and certificate-file access only to management peers
trusted by your site.

### Start a standalone ManagedPort

This example connects the managed device to a running BACnet/SC hub.
Replace the hub URI and choose the Device instance and vendor ID for your
installation. Put the device's operational certificate, matching private
key, and site issuer certificate in `./sc-node/` as `node.pem`,
`node-key.pem`, and `ca.pem`. The hub must trust the issuer that signed
the device certificate, and the managed port must trust the issuer that
signed the hub certificate.

Run this in an existing BACstack application or paste it into `iex -S mix`
from the checkout:

```elixir
alias BACnet.Stack.Transport.ScTransport.ManagedPort
alias BACnet.Stack.Transport.ScTransport.Node, as: ScNode

directory = Path.expand("sc-node")

children = [
  {ManagedPort,
   name: :managed_sc_port,
   mode: :standalone,
   storage_dir: Path.join(directory, "state"),
   device_instance: 123,
   device_name: "Standalone SC device",
   port_instance: 1,
   vendor_id: 0,
   file_instances: %{operational: 10, issuer_1: 11, issuer_2: 12, csr: 13},
   certificate_pem: File.read!(Path.join(directory, "node.pem")),
   private_key_pem: File.read!(Path.join(directory, "node-key.pem")),
   issuer_pems: [File.read!(Path.join(directory, "ca.pem"))],
   transport: [primary_hub_uri: "wss://hub.example:443/"]}
]

{:ok, _supervisor} = Supervisor.start_link(children, strategy: :one_for_one)
%{transport: transport} = ManagedPort.endpoints(:managed_sc_port)
ScNode.status(transport).active
```

In an existing application, add the child to your application's supervisor.
The managed port creates the Device, SC Network Port, and four certificate
File objects. It creates `./sc-node/state` for its private snapshot and
restores the active settings and credentials from that snapshot on restart.
The snapshot contains private keys and is written with mode `0600`. Losing
it loses the automatically assigned Device UUID, pending changes, and any
credentials installed since bootstrap.

The hub connection starts asynchronously. Recheck `ScNode.status(transport).active`
until it reports `:primary`, then send Who-Is for Device 123 from another node
on the same SC network. The port answers discovery and property reads with
the default access policy. To permit configuration changes or certificate
file access, provide a site-specific `:authorize` callback.

For a self-contained loopback demo that generates its own credentials, run
this from the BACstack checkout:

```sh
mix run examples/bacnet_sc_managed_port.exs
```

The script starts a loopback hub, a supervised standalone ManagedPort, and
a separate SC node. The second node sends Who-Is and prints the Device
instance and APDU limit from the I-Am response, along with its source VMAC. The
script generates a temporary CA and operational credentials and removes
the private snapshot directory on exit.

### Hosted mode

An application that already owns the BACnet Device and Network Port can
start the managed port with `mode: :hosted`. Pass the process that serializes
object operations as `:host` and pass its initial objects as `:objects`.

```elixir
objects = %{
  device: device,
  port: network_port,
  files: %{operational: operational, issuer_1: issuer_1, issuer_2: issuer_2, csr: csr}
}

{BACnet.Stack.Transport.ScTransport.ManagedPort,
 [
   mode: :hosted,
   host: MyApplication.BACnetHost,
   objects: objects,
   storage_dir: storage_dir,
   certificate_pem: certificate_pem,
   private_key_pem: private_key_pem,
   issuer_pems: issuer_pems,
   authorize: authorize
 ]}
```

Create the Device with its existing UUID and the local SC Network Port at
revision 24 or later with Command execution enabled. The Network Port
references the four local stream-access Files. Make the CSR File read-only.
For a hub-capable Network Port, supply the listener binding in `:hub` and
set hub enable and accept URIs on the Network Port. The host includes these
objects in its own Object_List and supplies the device's supported services.

1. The host creates and registers its Device, SC Network Port, and four File
   objects, then starts ManagedPort in hosted mode.
2. The host calls `ManagedPort.refresh_objects/2` and retains its returned
   objects before serving reads. Refresh restores persisted managed settings
   and supplies live status and certificate file metadata.
3. In its serialized request loop, the host passes the original confirmed
   client notification and current objects to `ManagedPort.handle_request/3`.
   The managed port uses those objects and replies for requests it handles.
   The host stores the returned objects before processing the next operation.
4. For `:unhandled`, the host dispatches and replies. If a managed write
   returns `{:error, :refresh_required}`, explicitly refresh and retain
   the objects before retrying the request. This is also how a host
   refreshes SC properties for a mixed ReadPropertyMultiple request.

### Certificate rotation

To replace an operational certificate over BACnet:

1. If introducing a new CA, write its certificate to the unused issuer File on
   each peer, validate the changes and activate them before replacing any
   operational certificate. Leave the old issuer configured during the transition.
2. Write `GENERATE_CSR_FILE` to the Network Port's Command property. Read the
   CSR using AtomicReadFile and submit it to the site CA. The matching private key
   remains in the managed port.
3. Set the operational certificate File's size to zero, then upload the signed PEM
   using AtomicWriteFile in stream mode. Read `Command_Validation_Result` after
   issuing `VALIDATE_CHANGES`. Use `DISCARD_CHANGES` to revert staged writes.
4. Send ReinitializeDevice with `ACTIVATE_CHANGES` or `WARMSTART`. The port
   prepares the runtime and saves the proposed snapshot before queuing
   SimpleACK on the current connection. It retires affected sessions after
   queuing the reply. A preparation or persistence error returns a BACnet
   error and keeps changes pending. For offline maintenance, call
   `ManagedPort.activate/1` locally in standalone mode or
   `ManagedPort.activate/2` with the host's current objects. After reconnect,
   check the connector status and `Changes_Pending`.
5. After all devices use certificates from the new CA, clear the old issuer File,
   validate and activate. Affected sessions reconnect and verify the peer again.

The Network Port stores `SC_Hub_Function_Accept_URIs` for BACnet clients
to read. Listener configuration comes from the local `:hub` options.
`SC_Hub_Function_Binding` is read-only and reports the decimal TCP port.

`Current_Health` reports the live connection outcome. An active primary or
failover connection is healthy. With a configured hub and no active connection,
it shows the latest connector failure or `NETWORK_DOWN` while there is no
specific error. A port with no configured connector reports success.
`Command_Validation_Result` separately reports the outcome of validating
pending settings and certificate uploads.

## Independent interoperability check

Configure a third-party BACnet/SC node or test client with its own operational
certificate, UUID and VMAC under the same site CA. Join the BACstack primary
hub and exchange a Who-Is/I-Am broadcast and a unicast ReadProperty request with
the managed BACstack node. Take the primary offline, verify both nodes can
exchange messages via the failover hub, then restore the primary and check that
both connectors return to it. Repeat with the independent implementation as
the hub and BACstack as a node. Use the independent management client to read
the SC Network Port and exercise a certificate renewal.

The November 2026 loopback result and its coverage limits are recorded
in the [interoperability test record](bacnet_sc_interoperability.md).
