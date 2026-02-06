defmodule BACnet.Protocol.EventParameters do
  @moduledoc """
  BACnet has various different types of event parameters.
  Each of them is represented by a different module.

  The event algorithm `AccessEvent` is not supported.

  Consult the module `BACnet.Protocol.EventAlgorithms` for
  details about each event's algorithm.
  """

  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.StatusFlags

  @typedoc """
  Possible BACnet event parameters.
  """
  @type event_parameter ::
          __MODULE__.ChangeOfBitstring.t()
          | __MODULE__.ChangeOfState.t()
          | __MODULE__.ChangeOfValue.t()
          | __MODULE__.CommandFailure.t()
          | __MODULE__.FloatingLimit.t()
          | __MODULE__.OutOfRange.t()
          | __MODULE__.ChangeOfLifeSafety.t()
          | __MODULE__.Extended.t()
          | __MODULE__.BufferReady.t()
          | __MODULE__.UnsignedRange.t()
          | __MODULE__.DoubleOutOfRange.t()
          | __MODULE__.SignedOutOfRange.t()
          | __MODULE__.UnsignedOutOfRange.t()
          | __MODULE__.ChangeOfCharacterString.t()
          | __MODULE__.ChangeOfStatusFlags.t()
          | __MODULE__.None.t()

  defmodule ChangeOfBitstring do
    @moduledoc """
    Represents the BACnet event algorithm `ChangeOfBitstring` parameters.

    The ChangeOfBitstring event algorithm detects whether the monitored value of type BIT STRING equals a value
    that is listed as an alarm value, after applying a bitmask.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.1.
    """

    use TypedStruct

    @typedoc """
    Representative type for the event parameter.
    """
    typedstruct do
      field :alarm_values, [tuple()], enforce: true
      field :bitmask, tuple(), enforce: true
      field :time_delay, non_neg_integer(), enforce: true
      field :time_delay_normal, non_neg_integer()
    end

    @doc false
    def get_tag_number(), do: 0
  end

  defmodule ChangeOfState do
    @moduledoc """
    Represents the BACnet event algorithm `ChangeOfState` parameters.

    The ChangeOfState event algorithm detects whether the monitored value equals a value that is listed as an alarm
    value. The monitored value may be of any discrete or enumerated datatype, including Boolean.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.2.
    """

    use TypedStruct

    @typedoc """
    Representative type for the event parameter.
    """
    typedstruct do
      field :alarm_values, [BACnet.Protocol.PropertyState.t()], enforce: true
      field :time_delay, non_neg_integer(), enforce: true
      field :time_delay_normal, non_neg_integer()
    end

    @doc false
    def get_tag_number(), do: 1
  end

  defmodule ChangeOfValue do
    @moduledoc """
    Represents the BACnet event algorithm `ChangeOfValue` parameters.

    The ChangeOfValue event algorithm, for monitored values of datatype REAL, detects whether the absolute value of
    the monitored value changes by an amount equal to or greater than a positive REAL increment.

    The ChangeOfValue event algorithm, for monitored values of datatype BIT STRING, detects whether the monitored
    value changes in any of the bits specified by a bitmask.

    For detection of change, the value of the monitored value when a transition to NORMAL is indicated shall be used in
    evaluation of the conditions until the next transition to NORMAL is indicated. The initialization of the value used in
    evaluation before the first transition to NORMAL is indicated is a local matter.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.3.
    """

    use TypedStruct

    @typedoc """
    Representative type for the event parameter.
    """
    typedstruct do
      field :increment, float()
      field :bitmask, tuple()
      field :time_delay, non_neg_integer(), enforce: true
      field :time_delay_normal, non_neg_integer()
    end

    @doc false
    def get_tag_number(), do: 2
  end

  defmodule CommandFailure do
    @moduledoc """
    Represents the BACnet event algorithm `CommandFailure` parameters.

    The CommandFailure event algorithm detects whether the monitored value and the feedback value disagree for a time
    period. It may be used, for example, to verify that a process change has occurred after writing a property.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.4.
    """

    use TypedStruct

    @typedoc """
    Representative type for the event parameter.
    """
    typedstruct do
      field :feedback_value, BACnet.Protocol.ApplicationTags.Encoding.t(), enforce: true
      field :time_delay, non_neg_integer(), enforce: true
      field :time_delay_normal, non_neg_integer()
    end

    @doc false
    def get_tag_number(), do: 3
  end

  defmodule FloatingLimit do
    @moduledoc """
    Represents the BACnet event algorithm `FloatingLimit` parameters.

    The FloatingLimit event algorithm detects whether the monitored value exceeds a range defined by a setpoint, a high
    difference limit, a low difference limit and a deadband.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.5.
    """

    use TypedStruct

    @typedoc """
    Representative type for the event parameter.
    """
    typedstruct do
      field :setpoint, BACnet.Protocol.DeviceObjectPropertyRef.t(), enforce: true
      field :low_diff_limit, float(), enforce: true
      field :high_diff_limit, float(), enforce: true
      field :deadband, float(), enforce: true
      field :time_delay, non_neg_integer(), enforce: true
      field :time_delay_normal, non_neg_integer()
    end

    @doc false
    def get_tag_number(), do: 4
  end

  defmodule OutOfRange do
    @moduledoc """
    Represents the BACnet event algorithm `OutOfRange` parameters.

    The OutOfRange event algorithm detects whether the monitored value exceeds a range defined by a high limit and a
    low limit. Each of these limits may be enabled or disabled. If disabled, the normal range has no higher limit or no lower limit.
    In order to reduce jitter of the resulting event state, a deadband is applied when the value is in the process of returning to the
    normal range.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.6.
    """

    use TypedStruct

    @typedoc """
    Representative type for the event parameter.
    """
    typedstruct do
      field :low_limit, float(), enforce: true
      field :high_limit, float(), enforce: true
      field :deadband, float(), enforce: true
      field :time_delay, non_neg_integer(), enforce: true
      field :time_delay_normal, non_neg_integer()
    end

    @doc false
    def get_tag_number(), do: 5
  end

  defmodule ChangeOfLifeSafety do
    @moduledoc """
    Represents the BACnet event algorithm `ChangeOfLifeSafety` parameters.

    The ChangeOfLifeSafety event algorithm detects whether the monitored value equals a value that is listed as an
    alarm value or life safety alarm value. Event state transitions are also indicated if the value of the mode parameter changed
    since the last transition indicated. In this case, any time delays are overridden and the transition is indicated immediately.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.8.
    """

    use TypedStruct

    @typedoc """
    Representative type for the event parameter.
    """
    typedstruct do
      field :mode, BACnet.Protocol.DeviceObjectPropertyRef.t(), enforce: true
      field :alarm_values, [BACnet.Protocol.Constants.life_safety_state()], enforce: true

      field :life_safety_alarm_values, [BACnet.Protocol.Constants.life_safety_state()],
        enforce: true

      field :time_delay, non_neg_integer(), enforce: true
      field :time_delay_normal, non_neg_integer()
    end

    @doc false
    def get_tag_number(), do: 8
  end

  defmodule Extended do
    @moduledoc """
    Represents the BACnet event algorithm `Extended` parameters.

    The Extended event algorithm detects event conditions based on a proprietary event algorithm. The proprietary event
    algorithm uses parameters and conditions defined by the vendor. The algorithm is identified by a vendor-specific event type
    that is in the scope of the vendor's vendor identification code. The algorithm may, at the vendor's discretion, indicate a new
    event state, a transition to the same event state, or no transition to the Event-State-Detection. The indicated new event states
    may be NORMAL, and any OffNormal event state. FAULT event state may not be indicated by this algorithm. For the
    purpose of proprietary evaluation of unreliability conditions that may result in FAULT event state, a FAULT_EXTENDED
    fault algorithm shall be used.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.10.
    """

    use TypedStruct

    @typedoc """
    Representative type for the event parameter.
    """
    typedstruct do
      field :vendor_id, BACnet.Protocol.ApplicationTags.unsigned16(), enforce: true
      field :extended_event_type, non_neg_integer(), enforce: true
      field :parameters, BACnet.Protocol.ApplicationTags.encoding_list(), enforce: true
    end

    @doc false
    def get_tag_number(), do: 9
  end

  defmodule BufferReady do
    @moduledoc """
    Represents the BACnet event algorithm `BufferReady` parameters.

    The BufferReady event algorithm detects whether a defined number of records have been added to a log buffer since
    start of operation or the previous event, whichever is most recent.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.7.
    """

    use TypedStruct

    @typedoc """
    Representative type for the event parameter.
    """
    typedstruct do
      field :threshold, non_neg_integer(), enforce: true
      field :previous_count, BACnet.Protocol.ApplicationTags.unsigned32(), enforce: true
    end

    @doc false
    def get_tag_number(), do: 10
  end

  defmodule UnsignedRange do
    @moduledoc """
    Represents the BACnet event algorithm `UnsignedRange` parameters.

    The UnsignedRange event algorithm detects whether the monitored value exceeds a range defined by a high limit and
    a low limit.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.9.
    """

    use TypedStruct

    @typedoc """
    Representative type for the event parameter.
    """
    typedstruct do
      field :low_limit, non_neg_integer(), enforce: true
      field :high_limit, non_neg_integer(), enforce: true
      field :time_delay, non_neg_integer(), enforce: true
      field :time_delay_normal, non_neg_integer()
    end

    @doc false
    def get_tag_number(), do: 11
  end

  # AccessEvent (13, 13.3.12) not implemented

  defmodule DoubleOutOfRange do
    @moduledoc """
    Represents the BACnet event algorithm `DoubleOutOfRange` parameters.

    The DoubleOutOfRange event algorithm detects whether the monitored value exceeds a range defined by a high
    limit and a low limit. Each of these limits may be enabled or disabled. If disabled, the normal range has no lower limit or no
    higher limit respectively. In order to reduce jitter of the resulting event state, a deadband is applied when the value is in the
    process of returning to the normal range.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.13.
    """

    use TypedStruct

    @typedoc """
    Representative type for the event parameter.
    """
    typedstruct do
      field :low_limit, float(), enforce: true
      field :high_limit, float(), enforce: true
      field :deadband, float(), enforce: true
      field :time_delay, non_neg_integer(), enforce: true
      field :time_delay_normal, non_neg_integer()
    end

    @doc false
    def get_tag_number(), do: 14
  end

  defmodule SignedOutOfRange do
    @moduledoc """
    Represents the BACnet event algorithm `SignedOutOfRange` parameters.

    The SignedOutOfRange event algorithm detects whether the monitored value exceeds a range defined by a high
    limit and a low limit. Each of these limits may be enabled or disabled. If disabled, the normal range has no lower limit or no
    higher limit respectively. In order to reduce jitter of the resulting event state, a deadband is applied when the value is in the
    process of returning to the normal range.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.14.
    """

    use TypedStruct

    @typedoc """
    Representative type for the event parameter.
    """
    typedstruct do
      field :low_limit, integer(), enforce: true
      field :high_limit, integer(), enforce: true
      field :deadband, integer(), enforce: true
      field :time_delay, non_neg_integer(), enforce: true
      field :time_delay_normal, non_neg_integer()
    end

    @doc false
    def get_tag_number(), do: 15
  end

  defmodule UnsignedOutOfRange do
    @moduledoc """
    Represents the BACnet event algorithm `UnsignedOutOfRange` parameters.

    The UnsignedOutOfRange event algorithm detects whether the monitored value exceeds a range defined by a high
    limit and a low limit. Each of these limits may be enabled or disabled. If disabled, the normal range has no lower limit or no
    higher limit respectively. In order to reduce jitter of the resulting event state, a deadband is applied when the value is in the
    process of returning to the normal range.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.15.
    """

    use TypedStruct

    @typedoc """
    Representative type for the event parameter.
    """
    typedstruct do
      field :low_limit, non_neg_integer(), enforce: true
      field :high_limit, non_neg_integer(), enforce: true
      field :deadband, non_neg_integer(), enforce: true
      field :time_delay, non_neg_integer(), enforce: true
      field :time_delay_normal, non_neg_integer()
    end

    @doc false
    def get_tag_number(), do: 16
  end

  defmodule ChangeOfCharacterString do
    @moduledoc """
    Represents the BACnet event algorithm `ChangeOfCharacterString` parameters.

    The ChangeOfCharacterString event algorithm detects whether the monitored value matches a character string
    that is listed as an alarm value. Alarm values are of type BACnetOptionalCharacterString, and may also be NULL or an
    empty character string.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.16.
    """

    use TypedStruct

    @typedoc """
    Representative type for the event parameter.
    """
    typedstruct do
      field :alarm_values, [String.t() | nil], enforce: true
      field :time_delay, non_neg_integer(), enforce: true
      field :time_delay_normal, non_neg_integer()
    end

    @doc false
    def get_tag_number(), do: 17
  end

  defmodule ChangeOfStatusFlags do
    @moduledoc """
    Represents the BACnet event algorithm `ChangeOfStatusFlags` parameters.

    The ChangeOfStatusFlags event algorithm detects whether a significant flag of the monitored value of type
    BACnetStatusFlags has the value TRUE.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.11.
    """

    use TypedStruct

    @typedoc """
    Representative type for the event parameter.
    """
    typedstruct do
      field :selected_flags, BACnet.Protocol.StatusFlags.t(), enforce: true
      field :time_delay, non_neg_integer(), enforce: true
      field :time_delay_normal, non_neg_integer()
    end

    @doc false
    def get_tag_number(), do: 18
  end

  defmodule None do
    @moduledoc """
    Represents the BACnet event algorithm `None` parameters.

    This event algorithm has no parameters, no conditions, and does not indicate
    any transitions of event state. The NONE algorithm is used when only fault detection
    is in use by an object.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.17.
    """

    @typedoc """
    Representative type for the event parameter.
    """
    @type t :: %__MODULE__{}

    defstruct []

    @doc false
    def get_tag_number(), do: 20
  end

  # TODO: Docs
  @spec encode(event_parameter(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding()} | {:error, term()}
  def encode(event_params, opts \\ [])

  def encode(%ChangeOfBitstring{} = params, opts) do
    with true <- is_integer(params.time_delay) and params.time_delay >= 0,
         true <- is_tuple(params.bitmask),
         true <- is_list(params.alarm_values) and Enum.all?(params.alarm_values, &is_tuple/1),
         {:ok, time_delay, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.time_delay}, opts),
         {:ok, bitmask, _header} <-
           ApplicationTags.encode_value({:bitstring, params.bitmask}, opts),
         {:ok, alarm_values} <-
           Enum.reduce_while(params.alarm_values, {:ok, []}, fn bitstr, {:ok, acc} ->
             {:cont, {:ok, [{:bitstring, bitstr} | acc]}}
           end) do
      {:ok,
       {:constructed,
        {0,
         [
           tagged: {0, time_delay, byte_size(time_delay)},
           tagged: {1, bitmask, byte_size(bitmask)},
           constructed: {2, Enum.reverse(alarm_values), 0}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%ChangeOfState{} = params, opts) do
    with true <- is_integer(params.time_delay) and params.time_delay >= 0,
         true <- is_list(params.alarm_values) and Enum.all?(params.alarm_values, &is_atom/1),
         {:ok, time_delay, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.time_delay}, opts),
         {:ok, alarm_values} <-
           Enum.reduce_while(params.alarm_values, {:ok, []}, fn enum, {:ok, acc} ->
             case Constants.by_name(:property_state, enum) do
               {:ok, val} -> {:cont, {:ok, [{:enumerated, val} | acc]}}
               :error -> {:halt, {:error, {:unknown_property_state, enum}}}
             end
           end) do
      {:ok,
       {:constructed,
        {1,
         [
           tagged: {0, time_delay, byte_size(time_delay)},
           constructed: {1, Enum.reverse(alarm_values), 0}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%ChangeOfValue{} = params, opts) do
    with true <- is_integer(params.time_delay) and params.time_delay >= 0,
         true <- is_tuple(params.bitmask) or is_nil(params.bitmask),
         true <- is_float(params.increment) or is_nil(params.increment),
         {:ok, time_delay, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.time_delay}, opts),
         {:ok, bits} <-
           (if params.bitmask do
              case ApplicationTags.encode_value({:bitstring, params.bitmask}) do
                {:ok, bytes, _header} -> {:ok, {:tagged, {0, bytes, byte_size(bytes)}}}
                term -> term
              end
            else
              {:ok, nil}
            end),
         {:ok, float} <-
           (if params.increment do
              case ApplicationTags.encode_value({:real, params.increment}) do
                {:ok, bytes, _header} -> {:ok, {:tagged, {1, bytes, byte_size(bytes)}}}
                term -> term
              end
            else
              {:ok, nil}
            end) do
      {:ok,
       {:constructed,
        {2,
         [
           tagged: {0, time_delay, byte_size(time_delay)},
           constructed: {1, bits || float, 0}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%CommandFailure{} = params, opts) do
    with true <- is_integer(params.time_delay) and params.time_delay >= 0,
         true <- is_struct(params.feedback_value, DeviceObjectPropertyRef),
         {:ok, time_delay, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.time_delay}, opts),
         {:ok, feedback} <- DeviceObjectPropertyRef.encode(params.feedback_value, opts) do
      {:ok,
       {:constructed,
        {3,
         [
           tagged: {0, time_delay, byte_size(time_delay)},
           constructed: {1, feedback, 0}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%FloatingLimit{} = params, opts) do
    with true <- is_integer(params.time_delay) and params.time_delay >= 0,
         true <- is_struct(params.setpoint, DeviceObjectPropertyRef),
         true <- is_float(params.low_diff_limit),
         true <- is_float(params.high_diff_limit),
         true <- is_float(params.deadband),
         {:ok, time_delay, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.time_delay}, opts),
         {:ok, setpoint} <- DeviceObjectPropertyRef.encode(params.setpoint, opts),
         {:ok, low_diff_limit, _header} <-
           ApplicationTags.encode_value({:real, params.low_diff_limit}, opts),
         {:ok, high_diff_limit, _header} <-
           ApplicationTags.encode_value({:real, params.high_diff_limit}, opts),
         {:ok, deadband, _header} <-
           ApplicationTags.encode_value({:real, params.deadband}, opts) do
      {:ok,
       {:constructed,
        {4,
         [
           tagged: {0, time_delay, byte_size(time_delay)},
           constructed: {1, setpoint, 0},
           tagged: {2, low_diff_limit, byte_size(low_diff_limit)},
           tagged: {3, high_diff_limit, byte_size(high_diff_limit)},
           tagged: {4, deadband, byte_size(deadband)}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%OutOfRange{} = params, opts) do
    with true <- is_integer(params.time_delay) and params.time_delay >= 0,
         true <- is_float(params.low_limit),
         true <- is_float(params.high_limit),
         true <- is_float(params.deadband),
         {:ok, time_delay, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.time_delay}, opts),
         {:ok, low_limit, _header} <-
           ApplicationTags.encode_value({:real, params.low_limit}, opts),
         {:ok, high_limit, _header} <-
           ApplicationTags.encode_value({:real, params.high_limit}, opts),
         {:ok, deadband, _header} <-
           ApplicationTags.encode_value({:real, params.deadband}, opts) do
      {:ok,
       {:constructed,
        {5,
         [
           tagged: {0, time_delay, byte_size(time_delay)},
           tagged: {1, low_limit, byte_size(low_limit)},
           tagged: {2, high_limit, byte_size(high_limit)},
           tagged: {3, deadband, byte_size(deadband)}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%ChangeOfLifeSafety{} = params, opts) do
    with true <- is_integer(params.time_delay) and params.time_delay >= 0,
         true <- is_struct(params.mode, DeviceObjectPropertyRef),
         true <- is_list(params.alarm_values) and Enum.all?(params.alarm_values, &is_atom/1),
         true <-
           is_list(params.life_safety_alarm_values) and
             Enum.all?(params.life_safety_alarm_values, &is_atom/1),
         {:ok, time_delay, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.time_delay}, opts),
         {:ok, ls_alarm_values} <-
           Enum.reduce_while(params.life_safety_alarm_values, {:ok, []}, fn enum, {:ok, acc} ->
             case Constants.by_name(:life_safety_state, enum) do
               {:ok, val} -> {:cont, {:ok, [{:enumerated, val} | acc]}}
               :error -> {:halt, {:error, {:unknown_life_safety_alarm_value, enum}}}
             end
           end),
         {:ok, alarm_values} <-
           Enum.reduce_while(params.alarm_values, {:ok, []}, fn enum, {:ok, acc} ->
             case Constants.by_name(:life_safety_state, enum) do
               {:ok, val} -> {:cont, {:ok, [{:enumerated, val} | acc]}}
               :error -> {:halt, {:error, {:unknown_alarm_value, enum}}}
             end
           end),
         {:ok, mode} <- DeviceObjectPropertyRef.encode(params.mode, opts) do
      {:ok,
       {:constructed,
        {8,
         [
           tagged: {0, time_delay, byte_size(time_delay)},
           constructed: {1, ls_alarm_values, 0},
           constructed: {2, alarm_values, 0},
           constructed: {3, mode, 0}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%Extended{} = params, opts) do
    with true <-
           is_integer(params.vendor_id) and params.vendor_id >= 0 and params.vendor_id <= 65_535,
         true <- is_integer(params.extended_event_type) and params.extended_event_type >= 0,
         {:ok, vendor_id, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.vendor_id}, opts),
         {:ok, extended_event_type, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.extended_event_type}, opts) do
      {:ok,
       {:constructed,
        {9,
         [
           tagged: {0, vendor_id, byte_size(vendor_id)},
           tagged: {1, extended_event_type, byte_size(extended_event_type)},
           constructed: {2, params.parameters, 0}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%BufferReady{} = params, opts) do
    with true <-
           is_integer(params.threshold) and params.threshold >= 0 and
             ApplicationTags.valid_int?(params.previous_count, 32),
         true <- is_integer(params.previous_count) and params.previous_count >= 0,
         {:ok, threshold, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.threshold}, opts),
         {:ok, previous_count, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.previous_count}, opts) do
      {:ok,
       {:constructed,
        {10,
         [
           tagged: {0, threshold, byte_size(threshold)},
           tagged: {1, previous_count, byte_size(previous_count)}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%UnsignedRange{} = params, opts) do
    with true <- is_integer(params.time_delay) and params.time_delay >= 0,
         true <- is_integer(params.low_limit) and params.low_limit >= 0,
         true <- is_integer(params.high_limit) and params.high_limit >= 0,
         {:ok, time_delay, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.time_delay}, opts),
         {:ok, low_limit, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.low_limit}, opts),
         {:ok, high_limit, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.high_limit}, opts) do
      {:ok,
       {:constructed,
        {11,
         [
           tagged: {0, time_delay, byte_size(time_delay)},
           tagged: {1, low_limit, byte_size(low_limit)},
           tagged: {2, high_limit, byte_size(high_limit)}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%DoubleOutOfRange{} = params, opts) do
    with true <- is_integer(params.time_delay) and params.time_delay >= 0,
         true <- is_float(params.low_limit),
         true <- is_float(params.high_limit),
         true <- is_float(params.deadband),
         {:ok, time_delay, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.time_delay}, opts),
         {:ok, low_limit, _header} <-
           ApplicationTags.encode_value({:double, params.low_limit}, opts),
         {:ok, high_limit, _header} <-
           ApplicationTags.encode_value({:double, params.high_limit}, opts),
         {:ok, deadband, _header} <-
           ApplicationTags.encode_value({:double, params.deadband}, opts) do
      {:ok,
       {:constructed,
        {14,
         [
           tagged: {0, time_delay, byte_size(time_delay)},
           tagged: {1, low_limit, byte_size(low_limit)},
           tagged: {2, high_limit, byte_size(high_limit)},
           tagged: {3, deadband, byte_size(deadband)}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%SignedOutOfRange{} = params, opts) do
    with true <- is_integer(params.time_delay) and params.time_delay >= 0,
         true <- is_integer(params.low_limit),
         true <- is_integer(params.high_limit),
         true <- is_integer(params.deadband) and params.deadband >= 0,
         {:ok, time_delay, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.time_delay}, opts),
         {:ok, low_limit, _header} <-
           ApplicationTags.encode_value({:signed_integer, params.low_limit}, opts),
         {:ok, high_limit, _header} <-
           ApplicationTags.encode_value({:signed_integer, params.high_limit}, opts),
         {:ok, deadband, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.deadband}, opts) do
      {:ok,
       {:constructed,
        {15,
         [
           tagged: {0, time_delay, byte_size(time_delay)},
           tagged: {1, low_limit, byte_size(low_limit)},
           tagged: {2, high_limit, byte_size(high_limit)},
           tagged: {3, deadband, byte_size(deadband)}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%UnsignedOutOfRange{} = params, opts) do
    with true <- is_integer(params.time_delay) and params.time_delay >= 0,
         true <- is_integer(params.low_limit) and params.low_limit >= 0,
         true <- is_integer(params.high_limit) and params.high_limit >= 0,
         true <- is_integer(params.deadband) and params.deadband >= 0,
         {:ok, time_delay, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.time_delay}, opts),
         {:ok, low_limit, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.low_limit}, opts),
         {:ok, high_limit, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.high_limit}, opts),
         {:ok, deadband, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.deadband}, opts) do
      {:ok,
       {:constructed,
        {16,
         [
           tagged: {0, time_delay, byte_size(time_delay)},
           tagged: {1, low_limit, byte_size(low_limit)},
           tagged: {2, high_limit, byte_size(high_limit)},
           tagged: {3, deadband, byte_size(deadband)}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%ChangeOfCharacterString{} = params, opts) do
    with true <- is_integer(params.time_delay) and params.time_delay >= 0,
         true <-
           is_list(params.alarm_values) and
             Enum.all?(
               params.alarm_values,
               &(is_nil(&1) or (is_binary(&1) and String.valid?(&1)))
             ),
         {:ok, time_delay, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.time_delay}, opts),
         alvalues when is_list(alvalues) <-
           Enum.map(params.alarm_values, fn
             nil -> {:null, nil}
             str -> {:character_string, str}
           end) do
      {:ok,
       {:constructed,
        {17,
         [
           tagged: {0, time_delay, byte_size(time_delay)},
           constructed: {1, alvalues, 0}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%ChangeOfStatusFlags{} = params, opts) do
    with true <- is_integer(params.time_delay) and params.time_delay >= 0,
         true <- is_struct(params.selected_flags, StatusFlags),
         {:ok, time_delay, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.time_delay}, opts),
         {:ok, flags, _header} <-
           ApplicationTags.encode_value(StatusFlags.to_bitstring(params.selected_flags), opts) do
      {:ok,
       {:constructed,
        {18,
         [
           tagged: {0, time_delay, byte_size(time_delay)},
           tagged: {1, flags, byte_size(flags)}
         ], 0}}}
    end
  end

  def encode(%None{} = _params, _opts) do
    {:ok, {:constructed, {20, {:null, nil}, 0}}}
  end

  # TODO: Docs
  @spec parse(binary()) :: {:ok, event_parameter()} | {:error, term()}
  def parse(event_values_tag)

  # 0 = Change Of Bitstring
  def parse({:constructed, {0, event_values, 0}}) do
    case event_values do
      [
        tagged: {0, time_delay_raw, _length},
        tagged: {1, bitmask_raw, _length2},
        constructed: {2, seq_bitstrings, _length3}
      ] ->
        with {:ok, {:unsigned_integer, time_delay}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, time_delay_raw),
             {:ok, {:bitstring, bitmask}} <-
               ApplicationTags.unfold_to_type(:bitstring, bitmask_raw),
             {:ok, alarm_values} <-
               Enum.reduce_while(seq_bitstrings, {:ok, []}, fn
                 {:bitstring, bits}, {:ok, acc} -> {:cont, {:ok, [bits | acc]}}
                 _term, _acc -> {:halt, {:error, :invalid_alarm_values_parameter}}
               end) do
          event = %ChangeOfBitstring{
            alarm_values: Enum.reverse(alarm_values),
            bitmask: bitmask,
            time_delay: time_delay,
            time_delay_normal: nil
          }

          {:ok, event}
        else
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_event_values}
    end
  end

  # 1 = Change Of State
  def parse({:constructed, {1, event_values, 0}}) do
    case event_values do
      [
        tagged: {0, time_delay_raw, _length},
        constructed: {1, seq_propstates, _length2}
      ] ->
        with {:ok, {:unsigned_integer, time_delay}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, time_delay_raw),
             {:ok, alarm_values} <-
               Enum.reduce_while(seq_propstates, {:ok, []}, fn
                 term, acc ->
                   case BACnet.Protocol.PropertyState.parse(List.wrap(term)) do
                     {:ok, {state, _rest}} -> {:ok, [state | acc]}
                     _term -> {:halt, {:error, :invalid_alarm_values_parameter}}
                   end
               end) do
          event = %ChangeOfState{
            alarm_values: Enum.reverse(alarm_values),
            time_delay: time_delay,
            time_delay_normal: nil
          }

          {:ok, event}
        else
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_event_values}
    end
  end

  # 2 = Change Of Value
  def parse({:constructed, {2, event_values, 0}}) do
    case event_values do
      [
        tagged: {0, time_delay_raw, _length},
        constructed: {1, cov_criteria_raw, _length2}
      ] ->
        with {:ok, {:unsigned_integer, time_delay}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, time_delay_raw),
             {:ok, {increment, bitmask}} <-
               (case cov_criteria_raw do
                  {:tagged, {0, _con, _len}} ->
                    with {:ok, {:bitstring, bitmask}} <-
                           ApplicationTags.unfold_to_type(:bitstring, cov_criteria_raw),
                         do: {:ok, {nil, bitmask}}

                  {:tagged, {1, _con, _len}} ->
                    with {:ok, {:real, increment}} <-
                           ApplicationTags.unfold_to_type(:real, cov_criteria_raw),
                         do: {:ok, {increment, nil}}

                  _term ->
                    {:error, :invalid_cov_criteria}
                end) do
          event = %ChangeOfValue{
            increment: increment,
            bitmask: bitmask,
            time_delay: time_delay,
            time_delay_normal: nil
          }

          {:ok, event}
        else
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_event_values}
    end
  end

  # 3 = Command Failure
  def parse({:constructed, {3, event_values, 0}}) do
    case event_values do
      [
        tagged: {0, time_delay_raw, _length},
        constructed: {_context2, 1, feedback_value, _length3}
      ] ->
        with {:ok, {:unsigned_integer, time_delay}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, time_delay_raw),
             {:ok, feedback_value} <- DeviceObjectPropertyRef.parse(feedback_value) do
          event = %CommandFailure{
            feedback_value: feedback_value,
            time_delay: time_delay,
            time_delay_normal: nil
          }

          {:ok, event}
        else
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_event_values}
    end
  end

  # 4 = Floating Limit
  def parse({:constructed, {4, event_values, 0}}) do
    case event_values do
      [
        tagged: {0, time_delay_raw, _length},
        constructed: {1, setpoint_ref_raw, _length2},
        tagged: {2, low_diff_raw, _length3},
        tagged: {3, high_diff_raw, _length4},
        tagged: {4, deadband_raw, _length5}
      ] ->
        with {:ok, {:unsigned_integer, time_delay}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, time_delay_raw),
             {:ok, setpoint_ref} <- DeviceObjectPropertyRef.parse(setpoint_ref_raw),
             {:ok, {:real, low_diff}} <-
               ApplicationTags.unfold_to_type(:real, low_diff_raw),
             {:ok, {:real, high_diff}} <-
               ApplicationTags.unfold_to_type(:real, high_diff_raw),
             {:ok, {:real, deadband}} <-
               ApplicationTags.unfold_to_type(:real, deadband_raw) do
          event = %FloatingLimit{
            setpoint: setpoint_ref,
            low_diff_limit: low_diff,
            high_diff_limit: high_diff,
            deadband: deadband,
            time_delay: time_delay,
            time_delay_normal: nil
          }

          {:ok, event}
        else
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_event_values}
    end
  end

  # 5 = Out Of Range
  def parse({:constructed, {5, event_values, 0}}) do
    case event_values do
      [
        tagged: {0, time_delay_raw, _length},
        tagged: {1, low_limit_raw, _length2},
        tagged: {2, high_limit_raw, _length3},
        tagged: {3, deadband_raw, _length4}
      ] ->
        with {:ok, {:unsigned_integer, time_delay}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, time_delay_raw),
             {:ok, {:real, low_limit}} <-
               ApplicationTags.unfold_to_type(:real, low_limit_raw),
             {:ok, {:real, high_limit}} <-
               ApplicationTags.unfold_to_type(:real, high_limit_raw),
             {:ok, {:real, deadband}} <-
               ApplicationTags.unfold_to_type(:real, deadband_raw) do
          event = %OutOfRange{
            low_limit: low_limit,
            high_limit: high_limit,
            deadband: deadband,
            time_delay: time_delay,
            time_delay_normal: nil
          }

          {:ok, event}
        else
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_event_values}
    end
  end

  # 8 = Change Of Life Safety
  def parse({:constructed, {8, event_values, 0}}) do
    case event_values do
      [
        tagged: {0, time_delay_raw, _length},
        constructed: {1, life_safety_state_raw, _length2},
        constructed: {2, alarm_values_raw, _length3},
        constructed: {3, mode_raw, _length4}
      ] ->
        with {:ok, {:unsigned_integer, time_delay}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, time_delay_raw),
             {:ok, ls_alarm_values} <-
               Enum.reduce_while(life_safety_state_raw, {:ok, []}, fn pack, {:ok, acc} ->
                 case ApplicationTags.unfold_to_type(:enumerated, pack) do
                   {:ok, {:enumerated, value}} ->
                     with {:ok, value_c} <-
                            Constants.by_value_with_reason(
                              :life_safety_state,
                              value,
                              {:unknown_life_safety_alarm_value, pack}
                            ) do
                       {:cont, {:ok, [value_c | acc]}}
                     end

                   term ->
                     {:halt, term}
                 end
               end),
             {:ok, alarm_values} <-
               Enum.reduce_while(alarm_values_raw, {:ok, []}, fn pack, {:ok, acc} ->
                 case ApplicationTags.unfold_to_type(:enumerated, pack) do
                   {:ok, {:enumerated, value}} ->
                     with {:ok, value_c} <-
                            Constants.by_value_with_reason(
                              :life_safety_state,
                              value,
                              {:unknown_alarm_value, pack}
                            ) do
                       {:cont, {:ok, [value_c | acc]}}
                     end

                   term ->
                     {:halt, term}
                 end
               end),
             {:ok, mode} <- DeviceObjectPropertyRef.parse(mode_raw) do
          event = %ChangeOfLifeSafety{
            mode: mode,
            alarm_values: Enum.reverse(alarm_values),
            life_safety_alarm_values: Enum.reverse(ls_alarm_values),
            time_delay: time_delay,
            time_delay_normal: nil
          }

          {:ok, event}
        else
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_event_values}
    end
  end

  # 9 = Extended
  def parse({:constructed, {9, event_values, 0}}) do
    case event_values do
      [
        tagged: {0, vendor_id_raw, _length},
        tagged: {1, ext_event_raw, _length2},
        # TODO: May be not constructed (tagged)
        constructed: {_con, 2, parameters, _length3}
      ] ->
        with {:ok, {:unsigned_integer, vendor_id}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, vendor_id_raw),
             :ok <-
               if(ApplicationTags.valid_int?(vendor_id, 16),
                 do: :ok,
                 else: {:error, :invalid_vendor_id_value}
               ),
             {:ok, {:unsigned_integer, ext_event}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, ext_event_raw) do
          event = %Extended{
            vendor_id: vendor_id,
            extended_event_type: ext_event,
            parameters: parameters
          }

          {:ok, event}
        else
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_event_values}
    end
  end

  # 10 = Buffer Ready
  def parse({:constructed, {10, event_values, 0}}) do
    case event_values do
      [
        tagged: {0, threshold_raw, _length},
        tagged: {1, previous_count_raw, _length2}
      ] ->
        with {:ok, {:unsigned_integer, threshold}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, threshold_raw),
             {:ok, {:unsigned_integer, previous_count}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, previous_count_raw),
             :ok <-
               if(ApplicationTags.valid_int?(previous_count, 32),
                 do: :ok,
                 else: {:error, :invalid_previous_count_value}
               ) do
          event = %BufferReady{
            threshold: threshold,
            previous_count: previous_count
          }

          {:ok, event}
        else
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_event_values}
    end
  end

  # 11 = Unsigned Range
  def parse({:constructed, {11, event_values, 0}}) do
    case event_values do
      [
        tagged: {0, time_delay_raw, _length},
        tagged: {1, low_limit_raw, _length2},
        tagged: {2, high_limit_raw, _length3}
      ] ->
        with {:ok, {:unsigned_integer, time_delay}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, time_delay_raw),
             {:ok, {:unsigned_integer, low_limit}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, low_limit_raw),
             {:ok, {:unsigned_integer, high_limit}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, high_limit_raw) do
          event = %UnsignedRange{
            low_limit: low_limit,
            high_limit: high_limit,
            time_delay: time_delay,
            time_delay_normal: nil
          }

          {:ok, event}
        else
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_event_values}
    end
  end

  # 13 = Access Event
  def parse({:constructed, {13, _event_values, 0}}) do
    {:error, :not_supported_event_type}
  end

  # 14 = Double Out Of Range
  def parse({:constructed, {14, event_values, 0}}) do
    case event_values do
      [
        tagged: {0, time_delay_raw, _length},
        tagged: {1, low_limit_raw, _length2},
        tagged: {2, high_limit_raw, _length3},
        tagged: {3, deadband_raw, _length4}
      ] ->
        with {:ok, {:unsigned_integer, time_delay}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, time_delay_raw),
             {:ok, {:double, low_limit}} <-
               ApplicationTags.unfold_to_type(:double, low_limit_raw),
             {:ok, {:double, high_limit}} <-
               ApplicationTags.unfold_to_type(:double, high_limit_raw),
             {:ok, {:double, deadband}} <-
               ApplicationTags.unfold_to_type(:double, deadband_raw) do
          event = %DoubleOutOfRange{
            low_limit: low_limit,
            high_limit: high_limit,
            deadband: deadband,
            time_delay: time_delay,
            time_delay_normal: nil
          }

          {:ok, event}
        else
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_event_values}
    end
  end

  # 15 = Signed Out Of Range
  def parse({:constructed, {15, event_values, 0}}) do
    case event_values do
      [
        tagged: {0, time_delay_raw, _length},
        tagged: {1, low_limit_raw, _length2},
        tagged: {2, high_limit_raw, _length3},
        tagged: {3, deadband_raw, _length4}
      ] ->
        with {:ok, {:unsigned_integer, time_delay}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, time_delay_raw),
             {:ok, {:signed_integer, low_limit}} <-
               ApplicationTags.unfold_to_type(:signed_integer, low_limit_raw),
             {:ok, {:signed_integer, high_limit}} <-
               ApplicationTags.unfold_to_type(:signed_integer, high_limit_raw),
             {:ok, {:unsigned_integer, deadband}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, deadband_raw) do
          event = %SignedOutOfRange{
            low_limit: low_limit,
            high_limit: high_limit,
            deadband: deadband,
            time_delay: time_delay,
            time_delay_normal: nil
          }

          {:ok, event}
        else
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_event_values}
    end
  end

  # 16 = Unsigned Out Of Range
  def parse({:constructed, {16, event_values, 0}}) do
    case event_values do
      [
        tagged: {0, time_delay_raw, _length},
        tagged: {1, low_limit_raw, _length2},
        tagged: {2, high_limit_raw, _length3},
        tagged: {3, deadband_raw, _length4}
      ] ->
        with {:ok, {:unsigned_integer, time_delay}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, time_delay_raw),
             {:ok, {:unsigned_integer, low_limit}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, low_limit_raw),
             {:ok, {:unsigned_integer, high_limit}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, high_limit_raw),
             {:ok, {:unsigned_integer, deadband}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, deadband_raw) do
          event = %UnsignedOutOfRange{
            low_limit: low_limit,
            high_limit: high_limit,
            deadband: deadband,
            time_delay: time_delay,
            time_delay_normal: nil
          }

          {:ok, event}
        else
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_event_values}
    end
  end

  # 17 = Change Of Character String
  def parse({:constructed, {17, event_values, 0}}) do
    case event_values do
      [
        tagged: {0, time_delay_raw, _length},
        constructed: {1, strings, _length2}
      ] ->
        with {:ok, {:unsigned_integer, time_delay}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, time_delay_raw),
             alvalues when is_list(alvalues) <-
               Enum.map(strings, fn
                 {:null, _nil} -> nil
                 {:character_string, str} -> str
               end) do
          event = %ChangeOfCharacterString{
            alarm_values: alvalues,
            time_delay: time_delay,
            time_delay_normal: nil
          }

          {:ok, event}
        else
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_event_values}
    end
  end

  # 18 = Change Of Status Flags
  def parse({:constructed, {18, event_values, 0}}) do
    case event_values do
      [
        tagged: {0, time_delay_raw, _length},
        tagged: {1, sel_flags_raw, _length2}
      ] ->
        with {:ok, {:unsigned_integer, time_delay}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, time_delay_raw),
             {:ok, {:bitstring, sel_flags_bs}} <-
               ApplicationTags.unfold_to_type(:bitstring, sel_flags_raw),
             %StatusFlags{} = sel_flags <- StatusFlags.from_bitstring(sel_flags_bs) do
          event = %ChangeOfStatusFlags{
            selected_flags: sel_flags,
            time_delay: time_delay,
            time_delay_normal: nil
          }

          {:ok, event}
        else
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_event_values}
    end
  end

  # 20 = None
  def parse({:constructed, {20, event_values, 0}}) do
    case event_values do
      {:null, nil} -> {:ok, %None{}}
      _term -> {:error, :invalid_event_values}
    end
  end

  def parse(_event_values_tag) do
    {:error, :invalid_tag}
  end

  @doc """
  Validates whether the given event parameter is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(event_parameter()) :: boolean()
  def valid?(t)

  for module <- [
        __MODULE__.ChangeOfBitstring,
        __MODULE__.ChangeOfState,
        __MODULE__.ChangeOfValue,
        __MODULE__.CommandFailure,
        __MODULE__.FloatingLimit,
        __MODULE__.OutOfRange,
        __MODULE__.ChangeOfLifeSafety,
        __MODULE__.Extended,
        __MODULE__.BufferReady,
        __MODULE__.UnsignedRange,
        __MODULE__.DoubleOutOfRange,
        __MODULE__.SignedOutOfRange,
        __MODULE__.UnsignedOutOfRange,
        __MODULE__.ChangeOfCharacterString,
        __MODULE__.ChangeOfStatusFlags,
        __MODULE__.None
      ] do
    var = Macro.var(:t, __MODULE__)

    def valid?(%unquote(module){} = unquote(var)) do
      unquote(BACnet.BeamTypes.generate_valid_clause(module, __ENV__))
    end
  end
end
