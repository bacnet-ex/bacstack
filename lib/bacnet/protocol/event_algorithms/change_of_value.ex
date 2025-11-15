defmodule BACnet.Protocol.EventAlgorithms.ChangeOfValue do
  @moduledoc """
  Implements the BACnet event algorithm `ChangeOfValue`.

  The ChangeOfValue event algorithm, for monitored values of datatype REAL, detects
  whether the absolute value of the monitored value changes by an amount equal to
  or greater than a positive REAL increment.

  The ChangeOfValue event algorithm, for monitored values of datatype BIT STRING,
  detects whether the monitored value changes in any of the bits specified by a bitmask.

  For detection of change, the value of the monitored value when a transition to NORMAL
  is indicated shall be used in evaluation of the conditions until the next transition
  to NORMAL is indicated. The initialization of the value used in evaluation before
  the first transition to NORMAL is indicated is a local matter.

  For more specific information about the event algorithm, consult ASHRAE 135 13.3.3.
  """

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.EventParameters.ChangeOfValue, as: Params
  alias BACnet.Protocol.NotificationParameters.ChangeOfValue, as: Notify
  alias BACnet.Protocol.StatusFlags

  require Constants
  use TypedStruct

  @typedoc """
  Representative type for the event algorithm.
  """
  typedstruct visibility: :opaque do
    field :current_state, Constants.event_state(), enforce: true
    field :monitored_value, float() | tuple(), enforce: true
    field :status_flags, StatusFlags.t(), enforce: true
    field :parameters, Params.t(), enforce: true
    field :dt_normal, DateTime.t() | nil, enforce: true
    field :last_value, float() | tuple(), enforce: true
  end

  @doc """
  Creates a new algorithm state.
  """
  @spec new(float() | tuple(), Params.t()) :: t()
  def new(monitored_value, %Params{} = params)
      when is_float(monitored_value) or is_tuple(monitored_value) do
    unless (is_float(monitored_value) and is_float(params.increment)) or
             (is_tuple(monitored_value) and
                Enum.all?(Tuple.to_list(monitored_value), &is_boolean/1) and
                is_tuple(params.bitmask)) do
      raise ArgumentError,
            "One of increment or bitmask has to be set in parameters and " <>
              "must match the monitored value, got: " <>
              "monitored_value=#{inspect(monitored_value)}, params=#{inspect(params)}"
    end

    %__MODULE__{
      current_state: Constants.macro_assert_name(:event_state, :normal),
      monitored_value: monitored_value,
      status_flags: StatusFlags.from_bitstring({false, false, false, false}),
      parameters: params,
      dt_normal: nil,
      last_value: monitored_value
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
  updated from the state with the correct `in_alarm` state (`false`),
  however to ensure the Status Flags have an overall correct status,
  the user has to make sure all bits are correctly.

  ASHRAE 135:
  > The conditions evaluated by this event algorithm, for a monitored value of type REAL, are:
  >
  > (a) If pCurrentState is NORMAL, and the absolute value of pMonitoredValue changes by an amount
  > equal to or greater than pIncrement for pTimeDelayNormal, then indicate a transition
  > to the NORMAL event state.
  >
  > The conditions evaluated by this event algorithm, for a monitored value of type BIT STRING, are:
  >
  > (a) If pCurrentState is NORMAL, and any of the significant bits of pMonitoredValue change state
  > and remain changed for pTimeDelayNormal, then indicate a transition to the NORMAL event state.
  """
  @spec execute(t()) ::
          {:event, new_state :: t(), Notify.t()}
          | {:delayed_event | :no_event, new_state :: t()}
  def execute(%__MODULE__{} = state) do
    normal_event =
      state.current_state == Constants.macro_assert_name(:event_state, :normal) and
        state.last_value != state.monitored_value and
        detect_trigger(state)

    normal_dt =
      cond do
        normal_event and (state.parameters.time_delay_normal || state.parameters.time_delay) > 0 ->
          state.dt_normal ||
            get_dt(state.parameters.time_delay_normal || state.parameters.time_delay)

        normal_event ->
          state.dt_normal

        true ->
          nil
      end

    event =
      cond do
        normal_event and normal_dt == nil ->
          true

        normal_event and DateTime.compare(get_dt(0), normal_dt) != :lt ->
          true

        true ->
          false
      end

    new_state = %{
      state
      | dt_normal: unless(event, do: normal_dt),
        last_value: if(event, do: state.monitored_value, else: state.last_value)
    }

    compute_return(event, state, new_state)
  end

  @doc """
  Updates the state using the given parameters (`monitored_value`, `parameters`, `status_flags`).
  """
  @spec update(t(), Keyword.t()) :: t()
  def update(%__MODULE__{} = state, params) when is_list(params) do
    unless Keyword.keyword?(params) do
      raise ArgumentError, "Expected a keyword list as argument, got: #{inspect(params)}"
    end

    Enum.reduce(params, state, fn
      {:monitored_value, value}, acc ->
        unless (is_float(value) and is_float(acc.parameters.increment)) or
                 (is_tuple(value) and Enum.all?(Tuple.to_list(value), &is_boolean/1) and
                    is_tuple(acc.parameters.bitmask)) do
          raise ArgumentError,
                "Expected a float or tuple of booleans for monitored_value (must match to parameters), " <>
                  "got: #{inspect(value)}"
        end

        %{acc | monitored_value: value}

      {:parameters, value}, acc ->
        unless is_struct(value, Params) and
                 ((is_float(acc.monitored_value) and is_float(value.increment)) or
                    (is_tuple(acc.monitored_value) and is_tuple(value.bitmask))) do
          raise ArgumentError,
                "Expected EventParameters.ChangeOfValue struct for params (must match to monitored_value), " <>
                  "got: #{inspect(value)}"
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

  @spec detect_trigger(t()) :: boolean()
  defp detect_trigger(state)

  defp detect_trigger(%__MODULE__{monitored_value: value} = state) when is_float(value) do
    abs(value - state.last_value) >= abs(state.parameters.increment || 0.0)
  end

  defp detect_trigger(%__MODULE__{monitored_value: value} = state) when is_tuple(value) do
    Bitwise.band(tuple_to_int(value), tuple_to_int(state.parameters.bitmask)) !=
      tuple_to_int(state.last_value)
  end

  @spec compute_return(boolean(), t(), t()) ::
          {:event, t(), Notify.t()} | {:delayed_event | :no_event, t()}
  defp compute_return(event, old_state, new_state)

  defp compute_return(
         true,
         %__MODULE__{} = _state,
         %__MODULE__{last_value: value2} = state
       ) do
    notify = %Notify{
      changed_bits: if(is_tuple(value2), do: value2),
      changed_value: if(is_float(value2), do: value2),
      status_flags: %{state.status_flags | in_alarm: false}
    }

    {:event, state, notify}
  end

  defp compute_return(
         false,
         %__MODULE__{} = _state,
         %__MODULE__{dt_normal: dtn} = state
       )
       when dtn != nil,
       do: {:delayed_event, state}

  defp compute_return(false, _state, state), do: {:no_event, state}

  @spec get_dt(non_neg_integer()) :: DateTime.t()
  defp get_dt(0), do: DateTime.now!(Application.get_env(:bacstack, :default_timezone, "Etc/UTC"))
  defp get_dt(offset), do: DateTime.add(get_dt(0), offset, :second)

  @spec tuple_to_int(tuple()) :: non_neg_integer()
  defp tuple_to_int(tuple) when is_tuple(tuple) do
    BACnet.Internal.tuple_to_int(tuple)
  end
end
