defmodule BACnet.Protocol.EventAlgorithms.CommandFailure do
  @moduledoc """
  Implements the BACnet event algorithm `CommandFailure`.

  The CommandFailure event algorithm detects whether the monitored value and the feedback value
  disagree for a time period. It may be used, for example, to verify that a process change
  has occurred after writing a property.

  For more specific information about the event algorithm, consult ASHRAE 135 13.3.4.
  """

  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.EventParameters.CommandFailure, as: Params
  alias BACnet.Protocol.NotificationParameters.CommandFailure, as: Notify
  alias BACnet.Protocol.StatusFlags

  require Constants
  use TypedStruct

  @typedoc """
  Representative type for the event algorithm.
  """
  typedstruct visibility: :opaque do
    field :current_state, Constants.event_state(), enforce: true
    field :monitored_value, Encoding.t(), enforce: true
    field :status_flags, StatusFlags.t(), enforce: true
    field :parameters, Params.t(), enforce: true
    field :dt_normal, DateTime.t() | nil, enforce: true
    field :dt_offnormal, DateTime.t() | nil, enforce: true
    field :last_value, Encoding.t(), enforce: false
  end

  @doc """
  Creates a new algorithm state.

  The `encoding` field of `Encoding` structs is ignored.
  """
  @spec new(Encoding.t(), Params.t()) :: t()
  def new(%Encoding{} = monitored_value, %Params{} = params) do
    unless monitored_value.type == params.feedback_value.type or
             typeof(monitored_value.value) == typeof(params.feedback_value.value) do
      raise ArgumentError,
            "Expected monitored value and feedback value (from params) " <>
              "have the same type or value datatype, got: " <>
              "monitored_value=#{inspect(monitored_value)}, " <>
              "params=#{inspect(params)}"
    end

    %__MODULE__{
      current_state: Constants.macro_assert_name(:event_state, :normal),
      monitored_value: monitored_value,
      status_flags: StatusFlags.from_bitstring({false, false, false, false}),
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
  > (a) If pCurrentState is NORMAL, and pFeedbackValue is not equal to
  > pMonitoredValue for pTimeDelay, then indicate a transition to
  > the OFFNORMAL event state.
  >
  > (b) If pCurrentState is OFFNORMAL, and pMonitoredValue is equal to
  > pMonitoredValue for pTimeDelayNormal, then indicate a transition to
  > the NORMAL event state.
  """
  @spec execute(t()) ::
          {:event, new_state :: t(), Notify.t()}
          | {:delayed_event | :no_event, new_state :: t()}
  def execute(%__MODULE__{} = state) do
    current_normal = state.current_state == Constants.macro_assert_name(:event_state, :normal)

    offnormal =
      if state.monitored_value.value != state.parameters.feedback_value.value,
        do: state.monitored_value.value

    offnormal_event = current_normal and offnormal != nil
    normal_event = not current_normal and offnormal == nil

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

    {event, new_event_state} =
      cond do
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
        last_value: if(event, do: offnormal, else: state.last_value)
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
        unless is_struct(value, Encoding) and
                 (value.type == state.parameters.feedback_value.type or
                    typeof(value.value) == typeof(state.parameters.feedback_value.value)) do
          raise ArgumentError,
                "Expected a Encoding struct for monitored_value " <>
                  "with matching types for the monitored_value and parameters feedback_value" <>
                  ", got: #{inspect(value)}"
        end

        %{acc | monitored_value: value}

      {:parameters, value}, acc ->
        unless is_struct(value, Params) and
                 (state.monitored_value.type == value.feedback_value.type or
                    typeof(state.monitored_value.value) == typeof(value.feedback_value.value)) do
          raise ArgumentError,
                "Expected EventParameters.CommandFailure struct for params " <>
                  "with matching types for feedback_value and the monitored_value" <>
                  ", got: #{inspect(value)}"
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
      command_value: state.monitored_value,
      feedback_value: state.parameters.feedback_value,
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
         %__MODULE__{dt_normal: dtn, dt_offnormal: dto} = state
       )
       when dtn != nil or dto != nil,
       do: {:delayed_event, state}

  defp compute_return(false, _state, state), do: {:no_event, state}

  @spec get_dt(non_neg_integer()) :: DateTime.t()
  defp get_dt(0), do: DateTime.now!(Application.get_env(:bacstack, :default_timezone, "Etc/UTC"))
  defp get_dt(offset), do: DateTime.add(get_dt(0), offset, :second)

  @spec typeof(term()) :: atom()
  defp typeof(a) do
    cond do
      is_atom(a) -> :atom
      is_binary(a) -> :binary
      is_bitstring(a) -> :bitstring
      is_boolean(a) -> :boolean
      is_float(a) -> :float
      is_integer(a) -> :integer
      is_tuple(a) -> :tuple
      true -> raise ArgumentError, "Incomplete typeof list - unknown type - got: #{inspect(a)}"
    end
  end
end
