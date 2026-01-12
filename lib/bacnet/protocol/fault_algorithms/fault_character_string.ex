defmodule BACnet.Protocol.FaultAlgorithms.FaultCharacterString do
  @moduledoc """
  Represents the BACnet fault algorithm `FaultCharacterString`.

  The FAULT_CHARACTERSTRING fault algorithm detects whether the monitored value matches a
  character string that is listed as a fault value. Fault values are of type
  BACnetOptionalCharacterString and may also be NULL or an empty character string.

  For more specific information about the fault algorithm, consult ASHRAE 135 13.4.2.
  """

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.FaultParameters.FaultCharacterString, as: Params

  require Constants
  use TypedStruct

  @typedoc """
  Representative type for the event algorithm.
  """
  typedstruct visibility: :opaque do
    field :current_reliability, Constants.reliability(), enforce: true
    field :monitored_value, String.t(), enforce: true
    field :parameters, Params.t(), enforce: true
    field :last_fault_value, String.t(), enforce: false
  end

  @doc """
  Creates a new algorithm state.
  """
  @spec new(String.t(), Params.t()) :: t()
  def new(monitored_value, %Params{} = params) when is_binary(monitored_value) do
    unless String.valid?(monitored_value) do
      raise ArgumentError,
            "Expected monitored_value to be a valid UTF-8 string, " <>
              "got: #{inspect(monitored_value)}"
    end

    %__MODULE__{
      current_reliability: Constants.macro_assert_name(:reliability, :no_fault_detected),
      monitored_value: monitored_value,
      parameters: params,
      last_fault_value: nil
    }
  end

  @doc """
  Calculates the new state for the current state and parameters.
  Prior to this function invocation, the state should have been
  updated with `update/2`, if any of the properties has changed.

  ASHRAE 135:
  > The conditions evaluated by this fault algorithm are:
  >
  > (a) If pCurrentReliability is NO_FAULT_DETECTED, and pMonitoredValue matches
  > one of the values in pFaultValues, then indicate a transition
  > to the MULTI_STATE_FAULT reliability.
  >
  > (b) If pCurrentReliability is MULTI_STATE_FAULT, and pMonitoredValue does not
  > match any of the values contained in pFaultValues,
  > then indicate a transition to the NO_FAULT_DETECTED reliability.
  >
  > (c) Optional: If pCurrentReliability is MULTI_STATE_FAULT, and pMonitoredValue
  > matches one of the values contained in pFaultValues that is different
  > from the value that caused the last transition to MULTI_STATE_FAULT,
  > then indicate a transition to the MULTI_STATE_FAULT reliability.
  """
  @spec execute(t()) ::
          {:event, new_state :: t(), new_reliability :: Constants.reliability()}
          | {:no_event, new_state :: t()}
  def execute(%__MODULE__{} = state) do
    current_normal =
      state.current_reliability == Constants.macro_assert_name(:reliability, :no_fault_detected)

    monitored_empty = byte_size(state.monitored_value) == 0

    offnormal =
      Enum.find(state.parameters.fault_values, fn val ->
        val != nil and
          ((monitored_empty and byte_size(val) == 0) or
             (byte_size(val) > 0 and String.contains?(state.monitored_value, val)))
      end)

    offnormal_event = offnormal != nil and state.last_fault_value != offnormal
    normal_event = not current_normal and offnormal == nil and state.last_fault_value != offnormal

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
          last_fault_value: offnormal
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
        unless is_binary(value) and String.valid?(value) do
          raise ArgumentError,
                "Expected a valid UTF-8 string for monitored_value, got: #{inspect(value)}"
        end

        %{acc | monitored_value: value}

      {:parameters, value}, acc ->
        unless is_struct(value, Params) do
          raise ArgumentError,
                "Expected EventParameters.FaultCharacterString struct for params, got: #{inspect(value)}"
        end

        %{acc | parameters: value}

      {key, _value}, _acc ->
        raise ArgumentError, "Unknown key #{key}"
    end)
  end
end
