defmodule BACnet.Protocol.EventAlgorithms.ChangeOfLifeSafety do
  @moduledoc """
  Implements the BACnet event algorithm `ChangeOfLifeSafety`.

  The ChangeOfLifeSafety event algorithm detects whether the monitored value equals
  a value that is listed as an alarm value or life safety alarm value.
  Event state transitions are also indicated if the value of the mode algorithm changed
  since the last transition indicated. In this case, any time delays are overridden
  and the transition is indicated immediately.

  For more specific information about the event algorithm, consult ASHRAE 135 13.3.8.
  """

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.EventParameters.ChangeOfLifeSafety, as: Params
  alias BACnet.Protocol.NotificationParameters.ChangeOfLifeSafety, as: Notify
  alias BACnet.Protocol.StatusFlags

  require Constants
  use TypedStruct

  @typedoc """
  Representative type for the event algorithm.
  """
  typedstruct visibility: :opaque do
    field :current_state, Constants.event_state(), enforce: true
    field :monitored_value, Constants.life_safety_state(), enforce: true
    field :mode, Constants.life_safety_mode(), enforce: true
    field :status_flags, StatusFlags.t(), enforce: true
    field :operation_expected, Constants.life_safety_operation(), enforce: true
    field :parameters, Params.t(), enforce: true
    field :dt_normal, DateTime.t() | nil, enforce: true
    field :dt_offnormal, DateTime.t() | nil, enforce: true
    field :dt_life_alarm, DateTime.t() | nil, enforce: true
    field :last_value, Constants.life_safety_operation(), enforce: false
    field :last_mode, Constants.life_safety_mode(), enforce: false
  end

  @doc """
  Creates a new algorithm state.
  """
  @spec new(
          Constants.life_safety_state(),
          Constants.life_safety_mode(),
          Constants.life_safety_operation(),
          Params.t()
        ) :: t()
  def new(monitored_value, mode, operation_expected, %Params{} = params) do
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

    unless Constants.has_by_name(:life_safety_operation, operation_expected) do
      raise ArgumentError,
            "Expected operation_expected to be a valid life_safety_operation constant, " <>
              "got: #{inspect(operation_expected)}"
    end

    %__MODULE__{
      current_state: Constants.macro_assert_name(:event_state, :normal),
      monitored_value: monitored_value,
      mode: mode,
      status_flags: StatusFlags.from_bitstring({false, false, false, false}),
      operation_expected: operation_expected,
      parameters: params,
      dt_normal: nil,
      dt_offnormal: nil,
      dt_life_alarm: nil,
      last_value: nil,
      last_mode: mode
    }
  end

  @doc """
  Calculates the new state for the current state and parameters.
  Prior to this function invocation, the state should have been
  updated with `update/2`, if any of the properties has changed.

  `:delayed_event` helps identifying whether the algorithm needs
  to be called periodically in order to overcome the `time_delay`
  and trigger a state change. As soon as `:event` or `:no_event`
  is given as flag, it means the caller can go back to event
  orientated calling.

  The `status_flags` field of the notifications parameters is
  updated from the state with the correct `in_alarm` state,
  however to ensure the Status Flags have an overall correct status,
  the user has to make sure all bits are correctly.

  ASHRAE 135:
  > The conditions evaluated by this event algorithm are:
  >
  > (a) If pCurrentState is NORMAL, and pMonitoredValue is equal to any of the values
  > contained in pAlarmValues, and remains within the set of values of pAlarmValues
  > either for pTimeDelay or for pMode changes, then indicate a transition
  > to the OFFNORMAL event state.
  >
  > (b) If pCurrentState is NORMAL, and pMonitoredValue is equal to any of the values
  > contained in pLifeSafetyAlarmValues, and remains within the set of values of
  > pLifeSafetyAlarmValues either for pTimeDelay or for pMode changes,
  > then indicate a transition to the LIFE_SAFETY_ALARM event state.
  >
  > (c) If pCurrentState is NORMAL, and pMode changes, then indicate a transition
  > to the NORMAL event state.
  >
  > (d) If pCurrentState is OFFNORMAL, and pMonitoredValue is not equal to any of the
  > values contained in pAlarmValues and pLifeSafetyAlarmValues either for
  > pTimeDelayNormal or for pMode changes, then indicate a transition
  > to the NORMAL event state.
  >
  > (e) If pCurrentState is OFFNORMAL, and pMonitoredValue is equal to any of the values
  > contained in pLifeSafetyAlarmValues, and remains within the set of values of
  > pLifeSafetyAlarmValues either for pTimeDelay or for pMode changes,
  > then indicate a transition to the LIFE_SAFETY_ALARM event state.
  >
  > (f) Optional: If pCurrentState is OFFNORMAL, and pMonitoredValue is equal to one of
  > the values contained in pAlarmValues that is different from the value causing
  > the last transition to OFFNORMAL, and remains equal to that value for pTimeDelay,
  > then indicate a transition to the OFFNORMAL event state.
  >
  > (g) If pCurrentState is OFFNORMAL, and pMode changes, then indicate a transition
  > to the OFFNORMAL event state.
  >
  > (h) If pCurrentState is LIFE_SAFETY_ALARM, and pMonitoredValue is not equal to any
  > of the values contained in pAlarmValues and pLifeSafetyAlarmValues either for
  > pTimeDelayNormal or for pMode changes, then indicate a transition
  > to the NORMAL event state.
  >
  > (i) If pCurrentState is LIFE_SAFETY_ALARM, and pMonitoredValue is equal to any
  > of the values contained in pAlarmValues, and remains within the set of values
  > of pAlarmValues either for pTimeDelay or for pMode changes,
  > then indicate a transition to the OFFNORMAL event state.
  >
  > (j) Optional: If pCurrentState is LIFE_SAFETY_ALARM, and pMonitoredValue is equal
  > to one of the values contained in pLifeSafetyAlarmValues that is different
  > from the value causing the last transition to LIFE_SAFETY_ALARM,
  > and remains equal to that value for pTimeDelay,
  > then indicate a transition to the LIFE_SAFETY_ALARM event state.
  >
  > (k) If pCurrentState is LIFE_SAFETY_ALARM, and pMode changes, then indicate
  > a transition to the LIFE_SAFETY_ALARM event state.
  """
  @spec execute(t()) ::
          {:event, new_state :: t(), Notify.t()}
          | {:delayed_event | :no_event, new_state :: t()}
  def execute(%__MODULE__{} = state) do
    current_normal = state.current_state == Constants.macro_assert_name(:event_state, :normal)

    current_offnormal =
      state.current_state == Constants.macro_assert_name(:event_state, :offnormal)

    current_life_alarm =
      state.current_state == Constants.macro_assert_name(:event_state, :life_safety_alarm)

    offnormal = Enum.find(state.parameters.alarm_values, &(&1 == state.monitored_value))

    life_alarm =
      Enum.find(state.parameters.life_safety_alarm_values, &(&1 == state.monitored_value))

    mode_change = state.last_mode != state.mode

    normal_event =
      (not current_normal and offnormal == nil and life_alarm == nil and
         state.last_value != state.monitored_value) or (current_normal and mode_change)

    offnormal_event =
      ((not current_offnormal or offnormal != state.last_value) and offnormal != nil and
         state.last_value != state.monitored_value) or
        (current_offnormal and offnormal != nil and mode_change)

    life_alarm_event =
      ((not current_life_alarm or life_alarm != state.last_value) and life_alarm != nil and
         state.last_value != state.monitored_value) or
        (current_life_alarm and life_alarm != nil and mode_change)

    # Suppress normal event on offnormal or life alarm event
    normal_event = normal_event and not offnormal_event and not life_alarm_event

    offnormal_dt =
      cond do
        offnormal_event and not mode_change and state.parameters.time_delay > 0 ->
          state.dt_offnormal || get_dt(state.parameters.time_delay)

        not current_offnormal and not mode_change ->
          state.dt_offnormal

        true ->
          nil
      end

    normal_dt =
      cond do
        normal_event and not mode_change and
            (state.parameters.time_delay_normal || state.parameters.time_delay) > 0 ->
          state.dt_normal ||
            get_dt(state.parameters.time_delay_normal || state.parameters.time_delay)

        not current_normal and not mode_change ->
          state.dt_normal

        true ->
          nil
      end

    life_alarm_dt =
      cond do
        life_alarm_event and not mode_change and state.parameters.time_delay > 0 ->
          state.dt_life_alarm || get_dt(state.parameters.time_delay)

        not current_life_alarm and not mode_change ->
          state.dt_life_alarm

        true ->
          nil
      end

    current_dt = get_dt(0)

    {event, new_event_state} =
      cond do
        life_alarm_event and life_alarm_dt == nil ->
          {true, Constants.macro_assert_name(:event_state, :life_safety_alarm)}

        life_alarm_event and DateTime.compare(current_dt, life_alarm_dt) != :lt ->
          {true, Constants.macro_assert_name(:event_state, :life_safety_alarm)}

        offnormal_event and offnormal_dt == nil ->
          {true, Constants.macro_assert_name(:event_state, :offnormal)}

        offnormal_event and DateTime.compare(current_dt, offnormal_dt) != :lt ->
          {true, Constants.macro_assert_name(:event_state, :offnormal)}

        normal_event and normal_dt == nil ->
          {true, Constants.macro_assert_name(:event_state, :normal)}

        normal_event and DateTime.compare(current_dt, normal_dt) != :lt ->
          {true, Constants.macro_assert_name(:event_state, :normal)}

        true ->
          {false, state.current_state}
      end

    new_state = %__MODULE__{
      state
      | current_state: new_event_state,
        dt_normal: unless(event, do: normal_dt),
        dt_offnormal: unless(event, do: offnormal_dt),
        dt_life_alarm: unless(event, do: life_alarm_dt),
        last_value:
          if(event,
            do:
              cond do
                life_alarm_event -> life_alarm
                offnormal_event -> offnormal
                normal_event -> nil
              end,
            else: state.last_value
          ),
        last_mode: state.mode
    }

    compute_return(event, state, new_state)
  end

  @doc """
  Updates the state using the given parameters (`mode`, `monitored_value`,
  `operation_expected`, `parameters`, `status_flags`).
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

      {:operation_expected, value}, acc ->
        unless Constants.has_by_name(:life_safety_operation, value) do
          raise ArgumentError,
                "Expected a life safety operation constant for operation_expected, got: #{inspect(value)}"
        end

        %{acc | operation_expected: value}

      {:parameters, value}, acc ->
        unless is_struct(value, Params) do
          raise ArgumentError,
                "Expected EventParameters.ChangeOfLifeSafety struct for params, got: #{inspect(value)}"
        end

        %{acc | parameters: value}

      {:status_flags, value}, acc ->
        unless is_struct(value, StatusFlags) do
          raise ArgumentError,
                "Expected StatusFlags struct for status_flags, got: #{inspect(value)}"
        end

        %{acc | status_flags: value}

      {key, _value}, _acc ->
        raise ArgumentError, "Unknown key #{key}"
    end)
  end

  @spec compute_return(boolean(), t(), t()) ::
          {:event, t(), Notify.t()} | {:delayed_event | :no_event, t()}
  defp compute_return(event, old_state, new_state)

  defp compute_return(
         true,
         %__MODULE__{} = _state,
         %__MODULE__{current_state: state2} = state
       ) do
    notify = %Notify{
      new_state: state.monitored_value,
      new_mode: state.mode,
      operation_expected: state.operation_expected,
      status_flags: %{
        state.status_flags
        | in_alarm: state2 != Constants.macro_assert_name(:event_state, :normal)
      }
    }

    {:event, state, notify}
  end

  defp compute_return(
         false,
         %__MODULE__{} = _state,
         %__MODULE__{dt_normal: dtn, dt_offnormal: dto, dt_life_alarm: dtl} = state
       )
       when dtn != nil or dto != nil or dtl != nil,
       do: {:delayed_event, state}

  defp compute_return(false, _state, state), do: {:no_event, state}

  @spec get_dt(non_neg_integer()) :: DateTime.t()
  defp get_dt(0), do: DateTime.now!(Application.get_env(:bacstack, :default_timezone, "Etc/UTC"))
  defp get_dt(offset), do: DateTime.add(get_dt(0), offset, :second)
end
