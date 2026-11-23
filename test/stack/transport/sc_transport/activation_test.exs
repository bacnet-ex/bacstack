defmodule BACnet.Test.Stack.Transport.ScTransport.ActivationTest do
  alias BACnet.Protocol.ObjectTypes.NetworkPort
  alias BACnet.Stack.Transport.ScTransport.Activation
  alias BACnet.Stack.Transport.ScTransport.Hub
  alias BACnet.Stack.Transport.ScTransport.ManagedPort
  alias BACnet.Stack.Transport.ScTransport.Node
  alias BACnet.Stack.Transport.ScTransport.Store

  use BACnet.Test.Stack.Case, async: false

  @moduletag skip: not BACstack.MixProject.sc_enabled?()

  @loopback {127, 0, 0, 1}
  @file_ids %{operational: 10, issuer_1: 11, issuer_2: 12, csr: 13}

  setup do
    ca_key = X509.PrivateKey.new_ec(:secp256r1)
    ca = X509.Certificate.self_signed(ca_key, "/CN=Activation CA", template: :root_ca)
    %{ca: ca, ca_key: ca_key, ca_pem: X509.Certificate.to_pem(ca)}
  end

  test "activates replacement credentials even after the running certificate expires", context do
    managed = start_managed(context)
    {expired, replacement} = stage_renewal(managed, context)
    state = :sys.get_state(managed)

    assert {:error, {:operational_certificate_file, :security, :certificate_expired}} =
             Store.runtime_config(state.snapshot, :active)

    assert :ok = ManagedPort.activate(managed)

    assert {:ok, %{certificates: %{operational: ^replacement}, uploads: uploads}} =
             Store.read(state.path)

    assert uploads == %{}
    assert state.snapshot.certificates.operational == expired
    assert :ok = stop_supervised(ManagedPort)
  end

  test "recovers a staged certificate on explicit startup and preserves pending settings",
       context do
    opts = managed_options(context, [], [])
    managed = start_supervised!({ManagedPort, opts})
    %{path: path} = stage_local_setting(managed, :network_number, 12)
    {expired, replacement} = stage_renewal(managed, context)
    assert :ok = stop_supervised(ManagedPort)
    assert {:error, _reason} = start_supervised({ManagedPort, opts})

    assert {:ok, %{certificates: %{operational: ^expired}, uploads: %{operational: ^replacement}}} =
             Store.read(path)

    opts = Keyword.put(opts, :recover_expired_certificate, true)
    recovered = start_supervised!({ManagedPort, opts})

    assert {:ok,
            %{
              certificates: %{operational: ^replacement},
              uploads: uploads,
              active: active,
              pending: %{network_number: 12}
            }} = Store.read(path)

    assert uploads == %{}
    assert active.network_number == 0

    assert :ok = ManagedPort.activate(recovered)
    assert {:ok, %{active: %{network_number: 12}}} = Store.read(path)
    assert :ok = stop_supervised(ManagedPort)
  end

  test "restores the pending snapshot on reply failure and activates it offline", context do
    managed = start_managed(context)

    state = stage_local_setting(managed, :network_number, 12)

    assert {:error, {:reply_failed, :app_timeout}, ^state} =
             Activation.run(state, :activate_changes, fn ->
               assert {:ok, %{active: %{network_number: 12}, pending: pending}} =
                        Store.read(state.path)

               assert pending == %{}
               {:error, :app_timeout}
             end)

    assert {:ok, %{pending: %{network_number: 12}}} = Store.read(state.path)
    %{transport: node} = ManagedPort.endpoints(managed)
    assert Node.status(node).active == nil
    assert :ok = ManagedPort.activate(managed)
    assert {:ok, %{active: %{network_number: 12}, pending: pending}} = Store.read(state.path)
    assert pending == %{}

    enable = stage_local_setting(managed, :sc_hub_function_enable, true)

    assert {:error, {:reply_failed, :noproc}, ^enable} =
             Activation.run(enable, :activate_changes, fn -> exit(:noproc) end)

    assert %{hub: nil} = ManagedPort.endpoints(managed)
    assert :ok = ManagedPort.activate(managed)
    assert %{hub: hub} = ManagedPort.endpoints(managed)
    bound_port = Hub.port(hub)

    reconfigure = stage_local_setting(managed, :sc_connect_wait_timeout, 12)

    assert {:error, {:reply_failed, :app_timeout}, ^reconfigure} =
             Activation.run(reconfigure, :activate_changes, fn ->
               assert %{admissions_held: true, config: %{connect_wait_timeout: 12}} =
                        :sys.get_state(hub)

               {:error, :app_timeout}
             end)

    assert %{admissions_held: false, config: %{connect_wait_timeout: 10}} = :sys.get_state(hub)
    assert Hub.port(hub) == bound_port

    assert {:ok, %{hub: ^hub, snapshot: %{active: %{sc_connect_wait_timeout: 12}}} = activated} =
             Activation.run(reconfigure, :activate_changes, fn -> :ok end)

    assert %{admissions_held: false, config: %{connect_wait_timeout: 12}} = :sys.get_state(hub)
    assert Hub.port(hub) == bound_port

    assert {:ok, %{active: %{sc_connect_wait_timeout: 12}, pending: pending}} =
             Store.read(activated.path)

    assert pending == %{}
    :sys.replace_state(managed, fn _state -> activated end)

    disable = stage_local_setting(managed, :sc_hub_function_enable, false)

    assert {:error, {:reply_failed, :app_timeout}, ^disable} =
             Activation.run(disable, :activate_changes, fn ->
               assert %{admissions_held: true} = :sys.get_state(hub)
               {:error, :app_timeout}
             end)

    assert %{admissions_held: false} = :sys.get_state(hub)
    assert :ok = ManagedPort.activate(managed)
    assert %{hub: nil} = ManagedPort.endpoints(managed)
    refute Process.alive?(hub)
    assert :ok = stop_supervised(ManagedPort)
  end

  test "keeps the active snapshot when validation, listener preparation, or persistence fails",
       context do
    managed = start_managed(context)
    state = :sys.get_state(managed)
    missing = %{state | path: Path.join(state.path, "missing")}

    assert {:error, _reason, ^missing} =
             Activation.run(missing, :activate_changes, fn ->
               flunk("persistence failed before reply")
             end)

    invalid = stage_local_setting(managed, :sc_primary_hub_uri, "ws://invalid/")

    assert {:error, {:property, :value_out_of_range}, ^invalid} =
             Activation.run(invalid, :activate_changes, fn ->
               flunk("validation failed before reply")
             end)

    {:ok, occupied} = :gen_tcp.listen(0, ip: @loopback)
    {:ok, port} = :inet.port(occupied)
    enable = stage_local_setting(managed, :sc_hub_function_enable, true)

    snapshot = %{
      enable.snapshot
      | pending: %{sc_hub_function_enable: true},
        hub: [ip: @loopback, port: port]
    }

    prepared = %{enable | snapshot: snapshot}
    Process.flag(:trap_exit, true)

    assert {:error, _reason, ^prepared} =
             Activation.run(prepared, :warmstart, fn ->
               flunk("listener did not bind before reply")
             end)

    :ok = :gen_tcp.close(occupied)
    assert :ok = stop_supervised(ManagedPort)
  end

  test "queues the reply through the local hub before retiring it", context do
    {:ok, socket} = :gen_tcp.listen(0, ip: @loopback)
    {:ok, port} = :inet.port(socket)
    :ok = :gen_tcp.close(socket)
    uri = "wss://127.0.0.1:#{port}/"

    managed =
      start_managed(context, [port: port, enabled: true],
        primary_hub_uri: uri,
        min_reconnect_time: 2
      )

    %{hub: hub, transport: node} = ManagedPort.endpoints(managed)

    assert Enum.any?(1..100, fn _attempt ->
             Process.sleep(20)
             Node.status(node).active == :primary
           end)

    state = stage_local_setting(managed, :sc_hub_function_enable, false)
    assert :ok = Node.flush(node)

    assert {:ok, %{hub: nil}} =
             Activation.run(state, :warmstart, fn ->
               assert Process.alive?(hub)
               assert Node.status(node).active == :primary
               assert {:ok, %{active: %{sc_hub_function_enable: false}}} = Store.read(state.path)
               :ok
             end)

    # Under load, the process may still be alive directly on the check
    refute not Enum.any?(1..100, fn _attempt ->
             Process.sleep(20)
             not Process.alive?(hub)
           end)

    assert :ok = stop_supervised(ManagedPort)
  end

  defp start_managed(context, hub \\ [], transport \\ []) do
    start_supervised!({ManagedPort, managed_options(context, hub, transport)})
  end

  defp managed_options(context, hub, transport) do
    {cert, key} = certificate(context, "Local activation")
    directory = Path.join(System.tmp_dir!(), "bacstack-sc-#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf(directory) end)

    [
      storage_dir: directory,
      device_instance: 123,
      port_instance: 1,
      file_instances: @file_ids,
      vendor_id: 0,
      certificate_pem: cert,
      private_key_pem: key,
      issuer_pems: [context.ca_pem],
      hub: Keyword.merge([ip: @loopback, port: 0, enabled: false], hub),
      transport: transport
    ]
  end

  defp stage_renewal(managed, context) do
    validity = X509.Certificate.Validity.new(~U[2000-01-01 00:00:00Z], ~U[2001-01-01 00:00:00Z])
    {expired, old_key} = certificate(context, "Expired certificate", validity: validity)
    {replacement, new_key} = certificate(context, "Replacement certificate")

    :sys.replace_state(managed, fn state ->
      {:ok, port} = NetworkPort.stage_external_change(state.port)

      snapshot = %{
        state.snapshot
        | certificates: %{state.snapshot.certificates | operational: expired},
          active_key: old_key,
          uploads: %{operational: replacement},
          csr_key: new_key
      }

      :ok = Store.write(state.path, snapshot)
      %{state | snapshot: snapshot, port: port}
    end)

    {expired, replacement}
  end

  defp stage_local_setting(managed, property, value) do
    :sys.replace_state(managed, fn state ->
      {:ok, port} = NetworkPort.update_property(state.port, property, value)
      snapshot = %{state.snapshot | pending: Map.put(state.snapshot.pending, property, value)}
      :ok = Store.write(state.path, snapshot)
      %{state | port: port, snapshot: snapshot}
    end)
  end

  defp certificate(context, name, opts \\ []) do
    key = X509.PrivateKey.new_ec(:secp256r1)

    certificate =
      X509.Certificate.new(
        X509.PublicKey.derive(key),
        "/CN=#{name}",
        context.ca,
        context.ca_key,
        Keyword.put(opts, :template, :server)
      )

    {X509.Certificate.to_pem(certificate), X509.PrivateKey.to_pem(key)}
  end
end
