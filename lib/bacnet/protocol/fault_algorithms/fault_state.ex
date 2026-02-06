defmodule BACnet.Protocol.FaultAlgorithms.FaultState do
  @moduledoc """
  Represents the BACnet fault algorithm `FaultState`.

  The FAULT_STATE fault algorithm detects whether the monitored value
  equals a value that is listed as a fault value. The monitored value
  may be of any discrete or enumerated datatype, including Boolean.
  If internal operational reliability is unreliable, then the
  internal reliability takes precedence over evaluation of the monitored value.

  For more specific information about the fault algorithm, consult ASHRAE 135 13.4.5.
  """

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.FaultParameters.FaultState, as: Params
  alias BACnet.Protocol.PropertyState

  require Constants
  use TypedStruct

  @typedoc """
  Representative type for the event algorithm.
  """
  typedstruct visibility: :opaque do
    field :current_reliability, Constants.reliability(), enforce: true
    field :monitored_value, PropertyState.t(), enforce: true
    field :parameters, Params.t(), enforce: true
    field :last_value, PropertyState.t(), enforce: false
  end

  @doc """
  Creates a new algorithm state.
  """
  @spec new(PropertyState.t(), Params.t()) :: t()
  def new(%PropertyState{} = monitored_value, %Params{} = params) do
    unless Enum.all?(
             params.fault_values,
             &(is_struct(&1, PropertyState) and monitored_value.type == &1.type)
           ) do
      raise ArgumentError,
            "Expected each fault value to be the same type " <>
              "as the monitored value, got: " <>
              "monitored_value=#{inspect(monitored_value)}, " <>
              "params=#{inspect(params)}"
    end

    %__MODULE__{
      current_reliability: Constants.macro_assert_name(:reliability, :no_fault_detected),
      monitored_value: monitored_value,
      parameters: params,
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
  > (a) If pCurrentReliability is NO_FAULT_DETECTED, and pMonitoredValue is equal
  > to any of the values in pFaultValues, then indicate a transition
  > to the MULTI_STATE_FAULT reliability.
  >
  > (b) If pCurrentReliability is MULTI_STATE_FAULT, and pMonitoredValue is not
  > equal to any of the values contained in pFaultValues, then indicate
  > a transition to the NO_FAULT_DETECTED reliability.
  >
  > (c) Optional: If pCurrentReliability is MULTI_STATE_FAULT, and pMonitoredValue
  > is equal one of the values contained in pFaultValues that is different from
  > the value that caused the last transition to MULTI_STATE_FAULT,
  > then indicate a transition to the MULTI_STATE_FAULT reliability.
  """
  @spec execute(t()) ::
          {:event, new_state :: t(), new_reliability :: Constants.reliability()}
          | {:no_event, new_state :: t()}
  def execute(%__MODULE__{} = state) do
    current_normal =
      state.current_reliability == Constants.macro_assert_name(:reliability, :no_fault_detected)

    offnormal = Enum.find(state.parameters.fault_values, &(&1 == state.monitored_value))

    offnormal_event = offnormal != nil and state.last_value != offnormal
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
          last_value: offnormal
      }

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
        unless is_struct(value, PropertyState) do
          raise ArgumentError,
                "Expected PropertyState struct for monitored_value, got: #{inspect(value)}"
        end

        unless Enum.all?(state.parameters.fault_values, &(value.type == &1.type)) do
          raise ArgumentError,
                "Expected monitored_value to be the same type " <>
                  "as the each fault value, got: " <>
                  "monitored_value=#{inspect(value)}, " <>
                  "params=#{inspect(state.parameters)}"
        end

        %{acc | monitored_value: value}

      {:parameters, value}, acc ->
        unless is_struct(value, Params) do
          raise ArgumentError,
                "Expected EventParameters.FaultState struct for params, got: #{inspect(value)}"
        end

        unless Enum.all?(
                 value.fault_values,
                 &(is_struct(&1, PropertyState) and state.monitored_value.type == &1.type)
               ) do
          raise ArgumentError,
                "Expected each fault value to be the same type " <>
                  "as the monitored value, got: " <>
                  "monitored_value=#{inspect(state.monitored_value)}, " <>
                  "params=#{inspect(value)}"
        end

        %{acc | parameters: value}

      {key, _value}, _acc ->
        raise ArgumentError, "Unknown key #{key}"
    end)
  end
end
