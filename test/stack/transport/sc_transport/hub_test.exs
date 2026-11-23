defmodule BACnet.Test.Stack.Transport.ScTransport.HubTest do
  alias BACnet.Protocol.SecureConnect.BVLC
  alias BACnet.Stack.Transport.ScTransport.Hub

  use ExUnit.Case, async: true

  @moduletag skip: not BACstack.MixProject.sc_enabled?()

  test "bounds each peer's pending frames and resumes forwarding when a credit is released" do
    ingress = spawn_session()
    target = self()
    other = spawn_session()

    state =
      hub_state()
      |> register(ingress, 2, 2)
      |> register(target, 3, 3)
      |> register(other, 4, 4)

    frame = frame(vmac(3))
    state = Enum.reduce(1..65, state, fn _attempt, acc -> route(acc, ingress, frame) end)
    assert {:reply, %{egress_drops: 1}, ^state} = Hub.handle_call(:status, nil, state)

    credits =
      for _index <- 1..64 do
        assert_receive {:"$gen_cast", {:transmit, %{source: source, destination: nil}, credit}}
        assert source == vmac(2)
        credit
      end

    refute_received {:"$gen_cast", {:transmit, _, _}}

    state = route(state, ingress, frame(BVLC.broadcast()))
    assert {:reply, %{egress_drops: 2}, ^state} = Hub.handle_call(:status, nil, state)

    assert_receive {:session, ^other,
                    {:transmit, %{destination: <<255, 255, 255, 255, 255, 255>>}, _}}

    refute_received {:session, ^ingress, _}

    {:noreply, state} = Hub.handle_info({:sc_egress_done, target, hd(credits)}, state)
    {:noreply, state} = Hub.handle_info({:sc_egress_done, target, hd(credits)}, state)
    state = route(state, ingress, frame)
    state = route(state, ingress, frame)
    assert_receive {:"$gen_cast", {:transmit, _, _}}
    refute_received {:"$gen_cast", {:transmit, _, _}}
    assert {:reply, %{egress_drops: 3}, ^state} = Hub.handle_call(:status, nil, state)
  end

  test "updates VMAC routes on UUID replacement, and an old session exit preserves the new route" do
    ingress = spawn_session()
    previous = spawn_session()
    replacement = spawn_session()

    state =
      hub_state()
      |> register(ingress, 2, 2)
      |> register(previous, 3, 3)
      |> register(replacement, 4, 3)

    assert_receive {:session, ^previous, :disconnect}

    {:noreply, state} =
      Hub.handle_info(
        {:DOWN, state.sessions[previous].monitor, :process, previous, :normal},
        state
      )

    state = route(state, ingress, frame(vmac(3)))
    state = route(state, ingress, frame(vmac(4)))
    assert_receive {:session, ^replacement, {:transmit, _, _}}
    refute_received {:session, ^previous, {:transmit, _, _}}

    {:noreply, state} =
      Hub.handle_info(
        {:DOWN, state.sessions[replacement].monitor, :process, replacement, :normal},
        state
      )

    assert route(state, ingress, frame(vmac(4))) == state
    refute_received {:session, ^replacement, {:transmit, _, _}}
  end

  defp hub_state() do
    struct!(Hub.State,
      config: %{vmac: vmac(1), device_uuid: <<1::128>>},
      listener: make_ref(),
      listener_monitor: make_ref(),
      sessions: %{},
      by_vmac: %{},
      by_uuid: %{},
      egress: %{},
      egress_drops: 0,
      failed: [],
      drain: nil,
      admissions_held: false,
      audit: nil,
      audit_counters: %{}
    )
  end

  defp register(state, pid, address, uuid) do
    session =
      struct!(Hub.Session,
        peer: nil,
        remote: {{127, 0, 0, 1}, 40_000},
        monitor: make_ref(),
        connected_at: nil,
        certificate_sha256: nil
      )

    peer = %{vmac: vmac(address), uuid: <<uuid::128>>, max_bvlc: 65_535, max_npdu: 1497}
    state = put_in(state.sessions[pid], session)
    assert {:reply, :ok, updated} = Hub.handle_call({:register, pid, peer}, nil, state)
    updated
  end

  defp route(state, ingress, frame) do
    assert {:reply, :ok, updated} = Hub.handle_call({:route, ingress, frame}, nil, state)
    updated
  end

  defp frame(destination) do
    %BVLC{
      function: :npdu,
      id: 1,
      source: nil,
      destination: destination,
      destination_options: [],
      data_options: [],
      payload: <<1, 0, 0x10, 8>>
    }
  end

  defp vmac(id), do: <<2, 0, 0, 0, 0, id>>

  defp spawn_session() do
    owner = self()
    spawn_link(fn -> relay_casts(owner) end)
  end

  defp relay_casts(owner) do
    monitor = Process.monitor(owner)
    relay_casts(owner, monitor)
  end

  defp relay_casts(owner, monitor) do
    receive do
      {:"$gen_cast", message} ->
        send(owner, {:session, self(), message})
        relay_casts(owner, monitor)

      {:DOWN, ^monitor, :process, ^owner, _reason} ->
        :ok
    end
  end
end
