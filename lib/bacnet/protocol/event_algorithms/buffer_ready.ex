defmodule BACnet.Protocol.EventAlgorithms.BufferReady do
  @moduledoc """
  Implements the BACnet event algorithm `BufferReady`.

  The BufferReady event algorithm detects whether a defined number of records
  have been added to a log buffer since start of operation or the previous event,
  whichever is most recent.

  For more specific information about the event algorithm, consult ASHRAE 135 13.3.7.
  """

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.EventParameters.BufferReady, as: Params
  alias BACnet.Protocol.NotificationParameters.BufferReady, as: Notify

  require Constants
  use TypedStruct

  @typedoc """
  Representative type for the event algorithm.
  """
  typedstruct visibility: :opaque do
    field :current_state, Constants.event_state(), enforce: true
    field :monitored_value, non_neg_integer(), enforce: true
    field :log_buffer, DeviceObjectPropertyRef.t(), enforce: true
    field :parameters, Params.t(), enforce: true
  end

  @doc """
  Creates a new algorithm state.
  """
  @spec new(non_neg_integer(), DeviceObjectPropertyRef.t(), Params.t()) :: t()
  def new(monitored_value, %DeviceObjectPropertyRef{} = log_buffer, %Params{} = params)
      when is_integer(monitored_value) and monitored_value >= 0 and
             monitored_value <= 4_294_967_295 do
    %__MODULE__{
      current_state: Constants.macro_assert_name(:event_state, :normal),
      monitored_value: monitored_value,
      log_buffer: log_buffer,
      parameters: params
    }
  end

  @doc """
  Calculates the new state for the current state and parameters.
  Prior to this function invocation, the state should have been
  updated with `update/2`, if any of the properties has changed.

  `previous_count` of `EventParameters.BufferReady` gets
  automatically updated in the state on event.

  ASHRAE 135:
  > The conditions evaluated by this event algorithm are:
  >
  > (a) If pCurrentState is NORMAL, and pMonitoredValue is greater than
  > or equal to pPreviousCount, and (pMonitoredValue - pPreviousCount)
  > is greater than or equal to pThreshold and pThreshold is greater than 0,
  > then indicate a transition to the NORMAL event state.
  >
  > (b) If pCurrentState is NORMAL, and pMonitoredValue is less than
  > pPreviousCount, and (pMonitoredValue - pPreviousCount + 2^32 - 1)
  > is greater than or equal to pThreshold and pThreshold is greater than 0,
  > then indicate a transition to the NORMAL event state.
  """
  @spec execute(t()) ::
          {:event, new_state :: t(), Notify.t()}
          | {:no_event, state :: t()}
  def execute(%__MODULE__{} = state) do
    normal_event =
      state.current_state == Constants.macro_assert_name(:event_state, :normal) and
        state.parameters.threshold > 0 and
        ((state.monitored_value >= state.parameters.previous_count and
            state.monitored_value - state.parameters.previous_count >= state.parameters.threshold) or
           (state.monitored_value < state.parameters.previous_count and
              state.monitored_value - state.parameters.previous_count + (Integer.pow(2, 32) - 1) >=
                state.parameters.threshold))

    if normal_event do
      notify = %Notify{
        buffer_property: state.log_buffer,
        previous_notification: state.parameters.previous_count,
        current_notification: state.monitored_value
      }

      new_state = %__MODULE__{
        state
        | parameters: %{state.parameters | previous_count: state.monitored_value}
      }

      {:event, new_state, notify}
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
        unless is_integer(value) and value >= 0 and value <= 4_294_967_295 do
          raise ArgumentError,
                "Expected a non negative 32bit integer for monitored_value, " <>
                  "got: #{inspect(value)}"
        end

        %{acc | monitored_value: value}

      {:parameters, value}, acc ->
        unless is_struct(value, Params) do
          raise ArgumentError,
                "Expected EventParameters.BufferReady struct for params, " <>
                  "got: #{inspect(value)}"
        end

        %{acc | parameters: value}

      {key, _value}, _acc ->
        raise ArgumentError, "Unknown key #{key}"
    end)
  end
end
