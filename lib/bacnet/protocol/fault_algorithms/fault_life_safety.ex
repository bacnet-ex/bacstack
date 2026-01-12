defmodule BACnet.Protocol.FaultAlgorithms.FaultLifeSafety do
  @moduledoc """
  Represents the BACnet fault algorithm `FaultLifeSafety`.

  The FAULT_LIFE_SAFETY fault algorithm detects whether the monitored value equals
  a value that is listed as a fault value.
  The monitored value is of type BACnetLifeSafetyState. If internal operational
  reliability is unreliable, then the internal reliability takes precedence over
  evaluation of the monitored value.

  In addition, this algorithm monitors a life safety mode value. If reliability is
  MULTI_STATE_FAULT, then new transitions to MULTI_STATE_FAULT are indicated upon
  change of the mode value.

  For more specific information about the fault algorithm, consult ASHRAE 135 13.4.4.
  """

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.FaultParameters.FaultLifeSafety, as: Params

  require Constants
  use TypedStruct

  @typedoc """
  Representative type for the event algorithm.
  """
  typedstruct visibility: :opaque do
    field :current_reliability, Constants.reliability(), enforce: true
    field :monitored_value, Constants.life_safety_state(), enforce: true
    field :mode, Constants.life_safety_mode(), enforce: true
    field :parameters, Params.t(), enforce: true
    field :last_value, String.t(), enforce: false
    field :last_mode, Constants.life_safety_mode(), enforce: false
  end

  @doc """
  Creates a new algorithm state.
  """
  @spec new(Constants.life_safety_state(), Constants.life_safety_mode(), Params.t()) :: t()
  def new(monitored_value, mode, %Params{} = params)
      when is_atom(monitored_value) and is_atom(mode) do
    unless Constants.has_by_name(:life_safety_state, monitored_value) do
      raise ArgumentError,
            "Expected monitored_value to be a valid life_safety_state constant, " <>
              "got: #{inspect(monitored_value)}"
    end

    unless Constants.has_by_name(:life_safety_mode, mode) do
      raise ArgumentError,
            "Expected mode to be a valid life_safety_mode constant, " <>
              "got: #{inspect(mode)}"
    end

    %__MODULE__{
      current_reliability: Constants.macro_assert_name(:reliability, :no_fault_detected),
      monitored_value: monitored_value,
      mode: mode,
      parameters: params,
      last_mode: mode,
      last_value: nil
    }
  end

  @doc """
  Calculates the new state for the current state and parameters.
  Prior to this function invocation, the state should have been
  updated with `update/2`, if any of the properties has changed.

  ASHRAE 135:
  > The conditions evaluated by this fault algorithm are:
  >
  > (a) If pCurrentReliability is NO_FAULT_DETECTED, and pMonitoredValue
  > is equal to any of the values in pFaultValues, then indicate
  > a transition to the MULTI_STATE_FAULT reliability.
  >
  > (b) If pCurrentReliability is MULTI_STATE_FAULT, and pMonitoredValue
  > is not equal to any of the values contained in pFaultValues,
  > then indicate a transition to the NO_FAULT_DETECTED reliability
  >
  > (c) If pCurrentReliability is MULTI_STATE_FAULT, and pMonitoredValue
  > is equal to any of the values contained in pFaultValues,
  > and pMode has changed since the last transition to MULTI_STATE_FAULT,
  > then indicate a transition to the MULTI_STATE_FAULT reliability.
  >
  > (d) Optional: If pCurrentReliability is MULTI_STATE_FAULT,
  > and pMonitoredValue is equal to one of the values contained
  > in pFaultValues that is different from the value causing the last transition
  > to MULTI_STATE_FAULT, then indicate a transition to the
  > MULTI_STATE_FAULT reliability.
  """
  @spec execute(t()) ::
          {:event, new_state :: t(), new_reliability :: Constants.reliability()}
          | {:no_event, new_state :: t()}
  def execute(%__MODULE__{} = state) do
    current_normal =
      state.current_reliability == Constants.macro_assert_name(:reliability, :no_fault_detected)

    current_life_alarm =
      state.current_reliability == Constants.macro_assert_name(:reliability, :multi_state_fault)

    offnormal = Enum.find(state.parameters.fault_values, &(&1 == state.monitored_value))
    mode_change = state.last_mode != state.mode

    offnormal_event =
      (offnormal != nil and state.last_value != offnormal) or (current_life_alarm and mode_change)

    normal_event = not current_normal and offnormal == nil and state.last_value != offnormal

    if offnormal_event or normal_event do
      new_reliability =
        cond do
          offnormal_event ->
            Constants.macro_assert_name(:reliability, :multi_state_fault)

          normal_event ->
            Constants.macro_assert_name(:reliability, :no_fault_detected)
        end

      new_state = %__MODULE__{
        state
        | current_reliability: new_reliability,
          last_value: offnormal,
          last_mode: state.mode
      }

      {:event, new_state, new_reliability}
    else
      {:no_event, state}
    end
  end

  @doc """
  Updates the state using the given parameters (`mode`, `monitored_value`, `parameters`).
  """
  @spec update(t(), Keyword.t()) :: t()
  def update(%__MODULE__{} = state, params) when is_list(params) do
    unless Keyword.keyword?(params) do
      raise ArgumentError, "Expected a keyword list as argument, got: #{inspect(params)}"
    end

    Enum.reduce(params, state, fn
      {:mode, value}, acc ->
        unless Constants.has_by_name(:life_safety_mode, value) do
          raise ArgumentError,
                "Expected a life safety mode constant for mode, got: #{inspect(value)}"
        end

        %{acc | mode: value}

      {:monitored_value, value}, acc ->
        unless Constants.has_by_name(:life_safety_state, value) do
          raise ArgumentError,
                "Expected a life safety state constant for monitored_value, got: #{inspect(value)}"
        end

        %{acc | monitored_value: value}

      {:parameters, value}, acc ->
        unless is_struct(value, Params) do
          raise ArgumentError,
                "Expected EventParameters.FaultLifeSafety struct for params, got: #{inspect(value)}"
        end

        %{acc | parameters: value}

      {key, _value}, _acc ->
        raise ArgumentError, "Unknown key #{key}"
    end)
  end
end
