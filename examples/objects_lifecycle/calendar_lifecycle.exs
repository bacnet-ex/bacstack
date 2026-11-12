# Run from the repository root:
#   mix run examples/objects_lifecycle/calendar_lifecycle.exs
Code.require_file("calendar_lifecycle_host.exs", __DIR__)

defmodule BACnet.Examples.CalendarLifecycleWalkthrough do
  @moduledoc false

  alias BACnet.Examples.CalendarLifecycleHost, as: Host
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.CalendarEntry
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectExecution.Wakeup
  alias BACnet.Protocol.ObjectTypes.Calendar, as: CalendarObject

  @spec run() :: :ok
  def run() do
    christmas = holiday(12, 25)
    boxing_day = holiday(12, 26)
    {:ok, calendar} = CalendarObject.create(500, "Holidays", %{date_list: [christmas]})

    # The example clock starts just before midnight. The host uses real process
    # timers; advancing this provider lets the walkthrough finish within seconds.
    {:ok, clock} = Agent.start_link(fn -> {~U[2026-12-24 23:59:59.950Z], -50} end)
    {:ok, host} = Host.start_link(calendar, clock: fn -> Agent.get(clock, & &1) end)

    try do
      %Result{object: %{present_value: false}} = Host.snapshot(host)
      show(host, "Initialization on December 24")

      # Only inspect the stored result while waiting: snapshot/1 does not refresh
      # the value, so this change is caused by the scheduled :timer execution.
      Agent.update(clock, fn _previous -> {~U[2026-12-25 00:00:00Z], 0} end)
      await_value(host, true, 200)
      show(host, "Midnight timer on December 25")

      Agent.update(clock, fn _previous -> {~U[2026-12-26 12:00:00Z], 129_600_000} end)
      {:ok, false} = Host.present_value(host)
      show(host, "Fresh read on December 26")

      :ok = Host.write_property(host, :date_list, [boxing_day])
      {:ok, true} = Host.present_value(host)
      show(host, "Date_List write takes effect on the same day")

      :ok = Host.write_property(host, :date_list, [boxing_day])
      show(host, "Same-value write also executes")

      before_rejection = Host.snapshot(host)

      {:error, {:write_access_denied, :present_value}} =
        Host.write_property(host, :present_value, false)

      {:error, _reason} = Host.write_property(host, :date_list, [:invalid_entry])
      ^before_rejection = Host.snapshot(host)
      IO.puts("Rejected writes preserve the stored object, runtime state and wakeup.")

      Agent.update(clock, fn _previous -> {~U[2026-12-25 12:00:00Z], 129_600_001} end)
      :ok = Host.clock_changed(host)
      %Result{object: %{present_value: false}} = Host.snapshot(host)
      show(host, "Backward clock change to December 25")
    after
      GenServer.stop(host)
      Agent.stop(clock)
    end
  end

  @spec holiday(1..12, 1..31) :: CalendarEntry.t()
  defp holiday(month, day) do
    %CalendarEntry{
      type: :date,
      date: %BACnetDate{year: :unspecified, month: month, day: day, weekday: :unspecified},
      date_range: nil,
      week_n_day: nil
    }
  end

  @spec show(GenServer.server(), String.t()) :: :ok
  defp show(host, label) do
    %Result{object: object, next_execution: %Wakeup{wall_time: deadline}} = Host.snapshot(host)

    IO.puts(
      "#{label}: Present_Value=#{object.present_value}; next=#{DateTime.to_iso8601(deadline)}"
    )
  end

  @spec await_value(GenServer.server(), boolean(), non_neg_integer()) :: :ok
  defp await_value(host, expected, attempts)

  defp await_value(_host, _expected, 0), do: raise("Calendar's midnight timer did not execute")

  defp await_value(host, expected, attempts) do
    if Host.snapshot(host).object.present_value == expected do
      :ok
    else
      Process.sleep(10)
      await_value(host, expected, attempts - 1)
    end
  end
end

BACnet.Examples.CalendarLifecycleWalkthrough.run()
