defmodule BACnet.Protocol.EventAlgorithms.ChangeOfStatusFlags do
  @moduledoc """
  Implements the BACnet event algorithm `ChangeOfStatusFlags`.

  The ChangeOfStatusFlags event algorithm detects whether a significant flag of the
  monitored value of type BACnetStatusFlags has the value TRUE.

  For more specific information about the event algorithm, consult ASHRAE 135 13.3.11.
  """

  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.EventParameters.ChangeOfStatusFlags, as: Params
  alias BACnet.Protocol.NotificationParameters.ChangeOfStatusFlags, as: Notify
  alias BACnet.Protocol.StatusFlags

  require Constants
  use TypedStruct

  @typedoc """
  Representative type for the event algorithm.
  """
  typedstruct visibility: :opaque do
    field :current_state, Constants.event_state(), enforce: true
    field :monitored_value, StatusFlags.t(), enforce: true
    field :present_value, Encoding.t(), enforce: false
    field :parameters, Params.t(), enforce: true
    field :dt_normal, DateTime.t() | nil, enforce: true
    field :dt_offnormal, DateTime.t() | nil, enforce: true
    field :last_value, non_neg_integer(), enforce: false
  end

  @doc """
  Creates a new algorithm state.
  """
  @spec new(StatusFlags.t(), Encoding.t() | nil, Params.t()) :: t()
  def new(%StatusFlags{} = monitored_value, present_value \\ nil, %Params{} = params) do
    unless is_nil(present_value) or is_struct(present_value, Encoding) do
      raise ArgumentError,
            "Expected nil or an Encoding struct for present_value, got: #{inspect(present_value)}"
    end

    %__MODULE__{
      current_state: Constants.macro_assert_name(:event_state, :normal),
      monitored_value: monitored_value,
      present_value: present_value,
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
  > (a) If pCurrentState is NORMAL, and pMonitoredValue has a value of TRUE
  > in any of its flags that also has a value of TRUE in the corresponding
  > flag in pSelectedFlags for pTimeDelay, then indicate a transition to the
  > OFFNORMAL event state.
  >
  > (b) If pCurrentState is OFFNORMAL, and pMonitoredValue has none of its
  > flags set to TRUE that also has a value of TRUE in the corresponding flag
  > in the pSelectedFlags event parameter for pTimeDelayNormal, then indicate
  > a transition to the NORMAL event state.
  >
  > (c) If pCurrentState is OFFNORMAL, and the set of selected flags of
  > pMonitoredValue that have a value of TRUE changes, then indicate a transition
  > to the OFFNORMAL event state.
  """
  @spec execute(t()) ::
          {:event, new_state :: t(), Notify.t()}
          | {:delayed_event | :no_event, new_state :: t()}
  def execute(%__MODULE__{} = state) do
    current_normal = state.current_state == Constants.macro_assert_name(:event_state, :normal)

    offnormal =
      Bitwise.band(sf_to_int(state.monitored_value), sf_to_int(state.parameters.selected_flags))

    offnormal_event = offnormal > 0 and state.last_value != offnormal
    normal_event = not current_normal and offnormal == 0 and state.last_value != offnormal

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
  Updates the state using the given parameters (`monitored_value`, `parameters`, `present_value`).
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
                "Expected EventParameters.ChangeOfStatusFlags struct for params, got: #{inspect(value)}"
        end

        %{acc | parameters: value}

      {:present_value, value}, acc ->
        unless is_nil(value) or is_struct(value, Encoding) do
          raise ArgumentError,
                "Expected nil or an Encoding struct for present_value, got: #{inspect(value)}"
        end

        %{acc | present_value: value}

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
         %__MODULE__{} = state
       ) do
    notify = %Notify{
      present_value: state.present_value,
      referenced_flags: state.monitored_value
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

  @spec sf_to_int(StatusFlags.t()) :: non_neg_integer()
  defp sf_to_int(%StatusFlags{} = flags) do
    <<int::integer-size(4)>> =
      <<intify(flags.in_alarm)::size(1), intify(flags.fault)::size(1),
        intify(flags.overridden)::size(1), intify(flags.out_of_service)::size(1)>>

    int
  end

  @spec intify(boolean()) :: 0 | 1
  defp intify(true), do: 1
  defp intify(false), do: 0
end
