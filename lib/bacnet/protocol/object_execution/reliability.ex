defmodule BACnet.Protocol.ObjectExecution.Reliability do
  @moduledoc """
  Reconciles reported and manual Reliability for objects that retain those two
  values across lifecycle steps.
  """

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectExecution.Context

  @typedoc "Reliability value retained for a selected property."
  @type value :: Constants.reliability() | non_neg_integer() | nil

  @typedoc "Reliability inputs to retain with the object's execution state."
  @type state :: %{reported_reliability: value(), manual_reliability: value()}

  @doc """
  Applies the reported/manual policy after a property write or execution step.

  A Reliability write refreshes the reported value. While out of service, it
  also supplies the manual value. When evaluation is inhibited, the effective value is the manual value or
  `:no_fault_detected`. The instance needs the optional Reliability property
  to retain either value.
  """
  @spec reconcile_reported(struct(), Context.t()) ::
          {:ok, struct(), state()} | {:error, term()}
  def reconcile_reported(%module{} = object, %Context{} = context) do
    if module.has_property?(object, :reliability) do
      previous = Context.previous_state(context)
      written? = Context.written_property(context) == :reliability

      reported =
        if is_nil(previous) or written? or is_nil(previous.reported_reliability),
          do: object.reliability,
          else: previous.reported_reliability

      manual =
        cond do
          object.out_of_service != true -> nil
          is_nil(previous) or written? -> object.reliability
          previous.out_of_service -> previous.manual_reliability
          true -> nil
        end

      value =
        if object.reliability_evaluation_inhibit,
          do: manual || :no_fault_detected,
          else: reported

      with {:ok, updated} <- module.update_property(object, :reliability, value) do
        {:ok, updated, %{reported_reliability: reported, manual_reliability: manual}}
      end
    else
      {:ok, object, %{reported_reliability: nil, manual_reliability: nil}}
    end
  end
end
