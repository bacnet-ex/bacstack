defmodule BACnet.Protocol.EventAlgorithms.DoubleOutOfRange do
  @moduledoc """
  Implements the BACnet event algorithm `DoubleOutOfRange`.

  The DoubleOutOfRange event algorithm detects whether the monitored value exceeds
  a range defined by a high limit and a low limit. Each of these limits may be
  enabled or disabled. If disabled, the normal range has no lower limit or no
  higher limit respectively. In order to reduce jitter of the resulting event state,
  a deadband is applied when the value is in the process of returning to the normal range.

  For more specific information about the event algorithm, consult ASHRAE 135 13.3.13.

  This module uses `BACnet.Protocol.EventAlgorithms.OutOfRange` as underlying implementation.
  """

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.EventAlgorithms.OutOfRange, as: BaseImpl
  alias BACnet.Protocol.EventParameters.DoubleOutOfRange, as: Params
  alias BACnet.Protocol.EventParameters.OutOfRange, as: BaseParams
  alias BACnet.Protocol.LimitEnable
  alias BACnet.Protocol.NotificationParameters.DoubleOutOfRange, as: Notify
  alias BACnet.Protocol.NotificationParameters.OutOfRange, as: BaseNotify
  alias BACnet.Protocol.StatusFlags

  use TypedStruct

  # Disable dialyzer for these functions as Dialyzer won't silence about these
  # and these functions are used for converting between the base implementation
  # and this "referrer" module - so they are fine
  # We are relying on unit tests to verify they are working
  @dialyzer {:nowarn_function, to_base_params: 1}
  @dialyzer {:nowarn_function, to_base_struct: 1}
  @dialyzer {:nowarn_function, to_notify: 1}
  @dialyzer {:nowarn_function, to_params: 1}
  @dialyzer {:nowarn_function, to_struct: 1}
  @dialyzer {:no_opaque, new: 3}
  @dialyzer {:no_return, new: 3}
  @dialyzer {:no_opaque, execute: 1}
  @dialyzer {:no_return, execute: 1}
  @dialyzer {:no_opaque, update: 2}
  @dialyzer {:no_return, update: 2}

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
    monitored_value
    |> BaseImpl.new(limit_enable, to_base_params(params))
    |> to_struct()
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
    case BaseImpl.execute(to_base_struct(state)) do
      {type, new_state} -> {type, to_struct(new_state)}
      {type, new_state, notify} -> {type, to_struct(new_state), to_notify(notify)}
    end
  end

  @doc """
  Updates the state using the given parameters (`limit_enable`, `monitored_value`,
  `parameters`, `status_flags`).
  """
  @spec update(t(), Keyword.t()) :: t()
  def update(%__MODULE__{} = state, params) when is_list(params) do
    clean_params =
      Enum.map(params, fn
        {:parameters, %Params{} = params} -> {:parameters, to_base_params(params)}
        term -> term
      end)

    state
    |> to_base_struct()
    |> BaseImpl.update(clean_params)
    |> to_struct()
  end

  @spec to_base_params(Params.t()) :: BaseParams.t()
  defp to_base_params(params), do: %{params | __struct__: BaseParams}

  @spec to_base_struct(t()) :: BaseImpl.t()
  defp to_base_struct(state),
    do: %{state | __struct__: BaseImpl, parameters: to_base_params(state.parameters)}

  @spec to_notify(BaseNotify.t()) :: Notify.t()
  defp to_notify(notify), do: %{notify | __struct__: Notify}

  @spec to_params(BaseParams.t()) :: Params.t()
  defp to_params(params), do: %{params | __struct__: Params}

  @spec to_struct(BaseImpl.t()) :: t()
  defp to_struct(state),
    do: %{state | __struct__: __MODULE__, parameters: to_params(state.parameters)}
end
