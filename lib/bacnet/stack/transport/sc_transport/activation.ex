if BACstack.MixProject.sc_enabled?() do
  defmodule BACnet.Stack.Transport.ScTransport.Activation do
    @moduledoc """
    Commits pending settings and credentials for a managed SC port.

    Validation and listener preparation take place while existing BACnet/SC
    sessions can still carry a reply. The new snapshot is written before the
    acknowledgment is queued. A preparation, persistence, or reply failure
    restores the previous runtime and leaves the pending changes available.

    Session retirement begins after the reply is queued. A local operation
    uses the same preparation and persistence steps and can run offline.
    """

    alias BACnet.Stack.Transport.ScTransport.Hub
    alias BACnet.Stack.Transport.ScTransport.ManagedPort
    alias BACnet.Stack.Transport.ScTransport.Node
    alias BACnet.Stack.Transport.ScTransport.Store

    @typedoc """
    The ReinitializeDevice operations used to activate the managed port.
    """
    @type operation :: :activate_changes | :warmstart

    @doc """
    Applies the proposed settings and invokes the acknowledgment function
    before retiring connections. Errors include the restored process state,
    since undoing listener preparation can change the hub process reference.
    """
    @spec run(ManagedPort.state(), operation(), (-> :ok | {:error, term()})) ::
            {:ok, ManagedPort.state()} | {:error, term(), ManagedPort.state()}
    def run(state, operation, acknowledge) do
      previous = state.runtime

      with {:ok, next} <- ManagedPort.runtime_config(state.snapshot, :proposed, state.hub_audit),
           {:ok, port} <- ManagedPort.commit_port(state.port, operation),
           {:ok, hub} <- prepare_hub(state.hub, previous.hub, next.hub) do
        next =
          update_in(
            next.node,
            &Keyword.put(&1, :status_receiver, previous.node[:status_receiver])
          )

        proposed = promote(state.snapshot, next.key)

        case Store.write(state.path, proposed) do
          :ok ->
            case acknowledge(acknowledge) do
              :ok ->
                commit_runtime(state, hub, previous, next, operation)
                {:ok, %{state | snapshot: proposed, runtime: next, port: port, hub: hub}}

              {:error, reason} ->
                :ok = restore_snapshot(state)
                rollback(state, hub, previous.hub, next.hub, {:reply_failed, reason})
            end

          {:error, reason} ->
            rollback(state, hub, previous.hub, next.hub, reason)
        end
      else
        {:error, {_property, class, code}} -> {:error, {class, code}, state}
        {:error, reason} -> {:error, reason, state}
      end
    end

    @spec acknowledge((-> :ok | {:error, term()})) :: :ok | {:error, term()}
    defp acknowledge(reply) do
      reply.()
    catch
      :exit, reason -> {:error, reason}
    end

    @spec promote(ManagedPort.snapshot(), binary()) :: ManagedPort.snapshot()
    defp promote(snapshot, key) do
      %{
        Store.promote_credentials(snapshot, key)
        | active: Map.merge(snapshot.active, snapshot.pending),
          pending: %{}
      }
    end

    @spec prepare_hub(pid() | nil, Keyword.t() | nil, Keyword.t() | nil) ::
            {:ok, pid() | nil} | {:error, term()}
    defp prepare_hub(hub, options, options), do: {:ok, hub}

    defp prepare_hub(hub, old, nil) do
      with :ok <- Hub.reconfigure(hub, old, false), do: {:ok, nil}
    end

    defp prepare_hub(nil, _old, new),
      do: Hub.start_link(Keyword.put(new, :hold_connections, true))

    defp prepare_hub(hub, _old, new) do
      with :ok <- Hub.reconfigure(hub, new, false), do: {:ok, hub}
    end

    @spec restore_snapshot(ManagedPort.state()) :: :ok
    defp restore_snapshot(state) do
      case Store.write(state.path, state.snapshot) do
        :ok -> :ok
        {:error, reason} -> exit({:sc_snapshot_rollback_failed, reason})
      end
    end

    @spec rollback(
            ManagedPort.state(),
            pid() | nil,
            Keyword.t() | nil,
            Keyword.t() | nil,
            term()
          ) :: {:error, term(), ManagedPort.state()}
    defp rollback(state, hub, previous, next, reason) do
      case restore_hub(state.hub, hub, previous, next) do
        :ok -> {:error, reason, state}
        {:error, restore_error} -> exit({:sc_listener_rollback_failed, restore_error})
      end
    end

    @spec restore_hub(pid() | nil, pid() | nil, Keyword.t() | nil, Keyword.t() | nil) ::
            :ok | {:error, term()}
    defp restore_hub(_previous_hub, _hub, options, options), do: :ok

    defp restore_hub(previous_hub, nil, _previous, nil),
      do: Hub.finish_reconfigure(previous_hub, false)

    defp restore_hub(nil, hub, nil, _next), do: Hub.close(hub)

    defp restore_hub(hub, hub, previous, _next) do
      with :ok <- Hub.reconfigure(hub, previous, false), do: Hub.finish_reconfigure(hub, false)
    end

    @spec commit_runtime(
            ManagedPort.state(),
            pid() | nil,
            ManagedPort.runtime_config(),
            ManagedPort.runtime_config(),
            operation()
          ) :: :ok
    defp commit_runtime(state, hub, previous, next, operation) do
      restart? = operation == :warmstart

      retire_hub? =
        is_pid(state.hub) and
          (restart? or is_nil(hub) or
             previous.hub[:crl_check] != next.hub[:crl_check] or
             Hub.reconnect_required?(previous.hub[:credentials], next.hub[:credentials]))

      cond do
        retire_hub? and local_hub_active?(state.node, state.hub) ->
          :ok = Node.reconfigure_for_hub_cutover(state.node, next.node)

        restart? or previous.node != next.node ->
          :ok = Node.reconfigure(state.node, next.node, restart?)

        true ->
          :ok
      end

      cond do
        is_nil(hub) and is_pid(state.hub) ->
          Hub.close(state.hub)

        is_pid(hub) ->
          Hub.finish_reconfigure(hub, retire_hub?)

        true ->
          :ok
      end
    end

    @spec local_hub_active?(pid(), pid()) :: boolean()
    defp local_hub_active?(node, hub) do
      status = Node.status(node)

      case Map.get(status, status.active) do
        %{peer: %{uuid: uuid, vmac: vmac}} -> Hub.local_connection?(hub, status.vmac, uuid, vmac)
        _disconnected -> false
      end
    end
  end
end
