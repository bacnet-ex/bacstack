defmodule BACnet.Protocol.EventAlgorithms.OutOfRange do
  @moduledoc """
  Implements the BACnet event algorithm `OutOfRange`.

  The OutOfRange event algorithm detects whether the monitored value exceeds a range
  defined by a high limit and a low limit. Each of these limits may be enabled or disabled.
  If disabled, the normal range has no higher limit or no lower limit.
  In order to reduce jitter of the resulting event state, a deadband is applied when
  the value is in the process of returning to the normal range.

  For more specific information about the event algorithm, consult ASHRAE 135 13.3.6.
  """

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.EventParameters.OutOfRange, as: Params
  alias BACnet.Protocol.LimitEnable
  alias BACnet.Protocol.NotificationParameters.OutOfRange, as: Notify
  alias BACnet.Protocol.StatusFlags

  require Constants
  use TypedStruct

  @const_normal Constants.macro_assert_name(:event_state, :normal)
  @const_high_limit Constants.macro_assert_name(:event_state, :high_limit)
  @const_low_limit Constants.macro_assert_name(:event_state, :low_limit)

  @typedoc """
  Representative type for the event algorithm.
  """
  typedstruct visibility: :opaque do
    field :current_state, Constants.event_state(), enforce: true
    field :monitored_value, float(), enforce: true
    field :status_flags, StatusFlags.t(), enforce: true
    field :limit_enable, LimitEnable.t(), enforce: true
    field :parameters, Params.t(), enforce: true
    field :dt_normal, DateTime.t() | nil, enforce: true
    field :dt_offnormal, DateTime.t() | nil, enforce: true
    field :last_value, float(), enforce: false
  end

  @doc """
  Creates a new algorithm state.
  """
  @spec new(float(), LimitEnable.t(), Params.t()) :: t()
  def new(
        monitored_value,
        %LimitEnable{} = limit_enable,
        %Params{} = params
      )
      when is_float(monitored_value) do
    %__MODULE__{
      current_state: Constants.macro_assert_name(:event_state, :normal),
      monitored_value: monitored_value,
      status_flags: StatusFlags.from_bitstring({false, false, false, false}),
      limit_enable: limit_enable,
      parameters: params,
      dt_normal: nil,
      dt_offnormal: nil,
      last_value: nil
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
  > (a) If pCurrentState is NORMAL, and the HighLimitEnable flag of pLimitEnable is TRUE,
  > and pMonitoredValue is greater than pHighLimit for pTimeDelay, then indicate a transition
  > to the HIGH_LIMIT event state.
  >
  > (b) If pCurrentState is NORMAL, and the LowLimitEnable flag of pLimitEnable is TRUE,
  > and pMonitoredValue is less than pLowLimit for pTimeDelay, then indicate a transition
  > to the LOW_LIMIT event state.
  >
  > (c) If pCurrentState is HIGH_LIMIT, and the HighLimitEnable flag of pLimitEnable is FALSE,
  > then indicate a transition to the NORMAL event state.
  >
  > (d) Optional: If pCurrentState is HIGH_LIMIT, and the LowLimitEnable flag of pLimitEnable is TRUE,
  > and pMonitoredValue is less than pLowLimit for pTimeDelay, then indicate a transition
  > to the LOW_LIMIT event state.
  >
  > (e) If pCurrentState is HIGH_LIMIT, and pMonitoredValue is less than (pHighLimit - pDeadband)
  > for pTimeDelayNormal, then indicate a transition to the NORMAL event state.
  >
  > (f) If pCurrentState is LOW_LIMIT, and the LowLimitEnable flag of pLimitEnable is FALSE,
  > then indicate a transition to the NORMAL event state.
  >
  > (g) Optional: If pCurrentState is LOW_LIMIT, and the HighLimitEnable flag of pLimitEnable is TRUE,
  > and pMonitoredValue is greater than pHighLimit for pTimeDelay, then indicate a transition
  > to the HIGH_LIMIT event state.
  >
  > (h) If pCurrentState is LOW_LIMIT, and pMonitoredValue is greater than (pLowLimit + pDeadband)
  > for pTimeDelayNormal, then indicate a transition to the NORMAL event state.
  """
  @spec execute(t()) ::
          {:event, new_state :: t(), Notify.t()}
          | {:delayed_event | :no_event, new_state :: t()}
  def execute(%__MODULE__{} = state) do
    current_normal = state.current_state == @const_normal
    current_high_limit = state.current_state == @const_high_limit
    current_low_limit = state.current_state == @const_low_limit

    normal_event =
      (((current_high_limit and
           state.monitored_value < state.parameters.high_limit - state.parameters.deadband and
           state.monitored_value > state.parameters.low_limit) or
          (current_low_limit and
             state.monitored_value > state.parameters.low_limit + state.parameters.deadband and
             state.monitored_value < state.parameters.high_limit)) and
         state.last_value != state.monitored_value) or
        (current_high_limit and not state.limit_enable.high_limit_enable) or
        (current_low_limit and not state.limit_enable.low_limit_enable)

    high_event =
      state.limit_enable.high_limit_enable and
        (current_normal or current_low_limit) and
        state.monitored_value > state.parameters.high_limit and
        state.last_value != state.monitored_value

    low_event =
      state.limit_enable.low_limit_enable and
        (current_normal or current_high_limit) and
        state.monitored_value < state.parameters.low_limit and
        state.last_value != state.monitored_value

    offnormal_event = high_event or low_event

    offnormal_dt =
      cond do
        offnormal_event and state.parameters.time_delay > 0 ->
          state.dt_offnormal || get_dt(state.parameters.time_delay)

        current_normal ->
          state.dt_offnormal

        true ->
          nil
      end

    normal_dt =
      cond do
        normal_event and (state.parameters.time_delay_normal || state.parameters.time_delay) > 0 ->
          state.dt_normal ||
            get_dt(state.parameters.time_delay_normal || state.parameters.time_delay)

        not current_normal ->
          state.dt_normal

        true ->
          nil
      end

    current_dt = get_dt(0)

    offnormal_state =
      cond do
        high_event -> @const_high_limit
        low_event -> @const_low_limit
        true -> Constants.macro_assert_name(:event_state, :offnormal)
      end

    {event, new_event_state} =
      cond do
        offnormal_event and offnormal_dt == nil ->
          {true, offnormal_state}

        offnormal_event and DateTime.compare(current_dt, offnormal_dt) != :lt ->
          {true, offnormal_state}

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
        last_value:
          if(event,
            do: state.monitored_value,
            else: state.last_value
          )
    }

    compute_return(event, state, new_state)
  end

  @doc """
  Updates the state using the given parameters (`limit_enable`, `monitored_value`,
  `parameters`, `status_flags`).
  """
  @spec update(t(), Keyword.t()) :: t()
  def update(%__MODULE__{} = state, params) when is_list(params) do
    unless Keyword.keyword?(params) do
      raise ArgumentError, "Expected a keyword list as argument, got: #{inspect(params)}"
    end

    Enum.reduce(params, state, fn
      {:limit_enable, value}, acc ->
        unless is_struct(value, LimitEnable) do
          raise ArgumentError,
                "Expected LimitEnable struct for limit_enable, got: #{inspect(value)}"
        end

        %{acc | limit_enable: value}

      {:monitored_value, value}, acc ->
        unless is_float(value) do
          raise ArgumentError,
                "Expected a float for monitored_value, got: #{inspect(value)}"
        end

        %{acc | monitored_value: value}

      {:parameters, value}, acc ->
        unless is_struct(value, Params) do
          raise ArgumentError,
                "Expected EventParameters.OutOfRange struct for params, got: #{inspect(value)}"
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
         %{current_state: state1} = _state,
         %{last_value: value, current_state: state2} = state
       )
       when state2 == @const_high_limit or
              (state2 == @const_normal and state1 == @const_high_limit) do
    notify = %Notify{
      deadband: state.parameters.deadband,
      exceeding_value: value,
      exceeded_limit: state.parameters.high_limit,
      status_flags: %{state.status_flags | in_alarm: state2 != @const_normal}
    }

    {:event, state, notify}
  end

  defp compute_return(
         true,
         %{current_state: state1} = _state,
         %{last_value: value, current_state: state2} = state
       )
       when state2 == @const_low_limit or
              (state2 == @const_normal and state1 == @const_low_limit) do
    notify = %Notify{
      deadband: state.parameters.deadband,
      exceeding_value: value,
      exceeded_limit: state.parameters.low_limit,
      status_flags: %{state.status_flags | in_alarm: state2 != @const_normal}
    }

    {:event, state, notify}
  end

  defp compute_return(
         false,
         %__MODULE__{} = _state,
         %__MODULE__{dt_normal: dtn, dt_offnormal: dto} = state
       )
       when dtn != nil or dto != nil,
       do: {:delayed_event, state}

  defp compute_return(false, _state, state), do: {:no_event, state}

  @spec get_dt(non_neg_integer()) :: DateTime.t()
  defp get_dt(0), do: DateTime.now!(Application.get_env(:bacstack, :default_timezone, "Etc/UTC"))
  defp get_dt(offset), do: DateTime.add(get_dt(0), offset, :second)
end
