defmodule BACnet.Test.Protocol.ObjectExecution.ReliabilityTest do
  use ExUnit.Case, async: true

  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Reliability
  alias BACnet.Protocol.ObjectTypes.DateValue

  test "reconciles reported and manual values and preserves an unselected property" do
    date = BACnetDate.from_date(~D[2026-11-11])
    {:ok, object} = DateValue.create(1, "Date", %{present_value: date})

    assert {:ok, ^object, %{reported_reliability: nil, manual_reliability: nil}} =
             Reliability.reconcile_reported(object, Context.new(:initialization))

    {:ok, object} =
      DateValue.create(1, "Date", %{
        present_value: date,
        out_of_service: true,
        reliability: :process_error,
        reliability_evaluation_inhibit: true
      })

    assert {:ok, %{reliability: :process_error}, state} =
             Reliability.reconcile_reported(object, Context.new(:initialization))

    assert state == %{reported_reliability: :process_error, manual_reliability: :process_error}
    {:ok, candidate} = DateValue.update_property(object, :reliability, :communication_failure)

    context =
      Context.new({:application_write, 103, nil, nil},
        state: Map.put(state, :out_of_service, true)
      )

    assert {:ok, %{reliability: :communication_failure},
            %{
              reported_reliability: :communication_failure,
              manual_reliability: :communication_failure
            }} =
             Reliability.reconcile_reported(candidate, context)
  end
end
