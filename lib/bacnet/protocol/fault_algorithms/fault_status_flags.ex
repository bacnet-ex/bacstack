defmodule BACnet.Protocol.FaultAlgorithms.FaultStatusFlags do
  @moduledoc """
  Represents the BACnet fault algorithm `FaultStatusFlags`.

  The FAULT_STATUS_FLAGS fault algorithm detects whether the monitored
  status flags are indicating a fault condition.

  For more specific information about the fault algorithm, consult ASHRAE 135 13.4.6.
  """

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.FaultParameters.FaultStatusFlags, as: Params
  alias BACnet.Protocol.StatusFlags

  require Constants
  use TypedStruct

  @typedoc """
  Representative type for the event algorithm.
  """
  typedstruct visibility: :opaque do
    field :current_reliability, Constants.reliability(), enforce: true
    field :monitored_value, StatusFlags.t(), enforce: true
    field :parameters, Params.t(), enforce: true
  end

  @doc """
  Creates a new algorithm state.
  """
  @spec new(StatusFlags.t(), Params.t()) :: t()
  def new(%StatusFlags{} = monitored_value, %Params{} = params) do
    %__MODULE__{
      current_reliability: Constants.macro_assert_name(:reliability, :no_fault_detected),
      monitored_value: monitored_value,
      parameters: params
    }
  end

  @doc """
  Calculates the new state for the current state and parameters.
  Prior to this function invocation, the state should have been
  updated with `update/2`, if any of the properties has changed.

  ASHRAE 135:
  > The conditions evaluated by this fault algorithm are:
  >
  > (a) If pCurrentReliability is NO_FAULT_DETECTED,
  > and the FAULT bit in pMonitoredValue is TRUE, then
  > indicate a transition to the MEMBER_FAULT reliability.
  >
  > (b) If pCurrentReliability is MEMBER_FAULT,
  > and the FAULT bit in pMonitoredValue is FALSE,
  > then indicate a transition to the NO_FAULT_DETECTED reliability.
  """
  @spec execute(t()) ::
          {:event, new_state :: t(), new_reliability :: Constants.reliability()}
          | {:no_event, new_state :: t()}
  def execute(%__MODULE__{} = state) do
    current_normal =
      state.current_reliability == Constants.macro_assert_name(:reliability, :no_fault_detected)

    offnormal = state.monitored_value.fault

    offnormal_event = current_normal and offnormal
    normal_event = not current_normal and not offnormal

    if offnormal_event or normal_event do
      new_reliability =
        cond do
          offnormal_event ->
            Constants.macro_assert_name(:reliability, :member_fault)

          normal_event ->
            Constants.macro_assert_name(:reliability, :no_fault_detected)
        end

      new_state = %__MODULE__{state | current_reliability: new_reliability}

      {:event, new_state, new_reliability}
    else
      {:no_event, state}
    end
  end

  @doc """
  Updates the state using the given parameters (`monitored_value`, `parameters`).
  """
  @spec update(t(), Keyword.t()) :: t()
  def update(%__MODULE__{} = state, params) when is_list(params) do
    unless Keyword.keyword?(params) do
      raise ArgumentError, "Expected a keyword list as argument, got: #{inspect(params)}"
    end

    Enum.reduce(params, state, fn
      {:monitored_value, value}, acc ->
        unless is_struct(value, StatusFlags) do
          raise ArgumentError,
                "Expected StatusFlags struct for monitored_value, got: #{inspect(value)}"
        end

        %{acc | monitored_value: value}

      {:parameters, value}, acc ->
        unless is_struct(value, Params) do
          raise ArgumentError,
                "Expected EventParameters.FaultStatusFlags struct for params, got: #{inspect(value)}"
        end

        %{acc | parameters: value}

      {key, _value}, _acc ->
        raise ArgumentError, "Unknown key #{key}"
    end)
  end
end
