defmodule BACnet.Protocol.NotificationParameters do
  @moduledoc """
  BACnet has various different types of notification parameters.
  Each of them is represented by a different module.

  The event algorithm `AccessEvent` is not supported.

  Consult the module `BACnet.Protocol.EventAlgorithms` for
  details about each event's algorithms.
  Consult the module `BACnet.Protocol.EventParameters` for
  details about each event's parameters.
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.PropertyState
  alias BACnet.Protocol.StatusFlags
  alias BACnet.Protocol.Utility

  import Utility, only: [pattern_extract_tags: 4]

  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  @typedoc """
  Possible BACnet notification parameters.
  """
  @type notification_parameter ::
          __MODULE__.ChangeOfBitstring.t()
          | __MODULE__.ChangeOfState.t()
          | __MODULE__.ChangeOfValue.t()
          | __MODULE__.CommandFailure.t()
          | __MODULE__.FloatingLimit.t()
          | __MODULE__.OutOfRange.t()
          | __MODULE__.ComplexEventType.t()
          | __MODULE__.ChangeOfLifeSafety.t()
          | __MODULE__.Extended.t()
          | __MODULE__.BufferReady.t()
          | __MODULE__.UnsignedRange.t()
          | __MODULE__.DoubleOutOfRange.t()
          | __MODULE__.SignedOutOfRange.t()
          | __MODULE__.UnsignedOutOfRange.t()
          | __MODULE__.ChangeOfCharacterString.t()
          | __MODULE__.ChangeOfStatusFlags.t()
          | __MODULE__.ChangeOfReliability.t()

  defmodule ChangeOfBitstring do
    @moduledoc """
    Represents the BACnet event algorithm `ChangeOfBitstring` notification parameters.

    The ChangeOfBitstring event algorithm detects whether the monitored value of type BIT STRING equals a value
    that is listed as an alarm value, after applying a bitmask.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.1.
    """

    use TypedStruct

    @typedoc """
    Representative type for the notification parameter.
    """
    typedstruct do
      field :referenced_bitstring, tuple(), enforce: true
      field :status_flags, BACnet.Protocol.StatusFlags.t(), enforce: true
    end

    @doc false
    def get_tag_number(), do: 0
  end

  defmodule ChangeOfState do
    @moduledoc """
    Represents the BACnet event algorithm `ChangeOfState` notification parameters.

    The ChangeOfState event algorithm detects whether the monitored value equals a value that is listed as an alarm
    value. The monitored value may be of any discrete or enumerated datatype, including Boolean.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.2.
    """

    use TypedStruct

    @typedoc """
    Representative type for the notification parameter.
    """
    typedstruct do
      field :new_state, PropertyState.t(), enforce: true
      field :status_flags, BACnet.Protocol.StatusFlags.t(), enforce: true
    end

    @doc false
    def get_tag_number(), do: 1
  end

  defmodule ChangeOfValue do
    @moduledoc """
    Represents the BACnet event algorithm `ChangeOfValue` notification parameters.

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
    Representative type for the notification parameter.
    """
    typedstruct do
      field :changed_bits, tuple(), enforce: false
      field :changed_value, float(), enforce: false
      field :status_flags, BACnet.Protocol.StatusFlags.t(), enforce: true
    end

    @doc false
    def get_tag_number(), do: 2
  end

  defmodule CommandFailure do
    @moduledoc """
    Represents the BACnet event algorithm `CommandFailure` notification parameters.

    The CommandFailure event algorithm detects whether the monitored value and the feedback value disagree for a time
    period. It may be used, for example, to verify that a process change has occurred after writing a property.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.4.
    """

    use TypedStruct

    @typedoc """
    Representative type for the notification parameter.
    """
    typedstruct do
      field :command_value, BACnet.Protocol.ApplicationTags.Encoding.t(), enforce: true
      field :status_flags, BACnet.Protocol.StatusFlags.t(), enforce: true
      field :feedback_value, BACnet.Protocol.ApplicationTags.Encoding.t(), enforce: true
    end

    @doc false
    def get_tag_number(), do: 3
  end

  defmodule FloatingLimit do
    @moduledoc """
    Represents the BACnet event algorithm `FloatingLimit` notification parameters.

    The FloatingLimit event algorithm detects whether the monitored value exceeds a range defined by a setpoint, a high
    difference limit, a low difference limit and a deadband.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.5.
    """

    use TypedStruct

    @typedoc """
    Representative type for the notification parameter.
    """
    typedstruct do
      field :reference_value, float(), enforce: true
      field :status_flags, BACnet.Protocol.StatusFlags.t(), enforce: true
      field :setpoint_value, float(), enforce: true
      field :error_limit, float(), enforce: true
    end

    @doc false
    def get_tag_number(), do: 4
  end

  defmodule OutOfRange do
    @moduledoc """
    Represents the BACnet event algorithm `OutOfRange` notification parameters.

    The OutOfRange event algorithm detects whether the monitored value exceeds a range defined by a high limit and a
    low limit. Each of these limits may be enabled or disabled. If disabled, the normal range has no higher limit or no lower limit.
    In order to reduce jitter of the resulting notification state, a deadband is applied when the value is in the process of returning to the
    normal range.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.6.
    """

    use TypedStruct

    @typedoc """
    Representative type for the notification parameter.
    """
    typedstruct do
      field :exceeding_value, float(), enforce: true
      field :status_flags, BACnet.Protocol.StatusFlags.t(), enforce: true
      field :deadband, float(), enforce: true
      field :exceeded_limit, float(), enforce: true
    end

    @doc false
    def get_tag_number(), do: 5
  end

  defmodule ComplexEventType do
    @moduledoc """
    Represents the BACnet event algorithm `ComplexEventType` notification parameters.

    The `ComplexEventType` algorithm is introduced to allow the addition of proprietary event algorithms
    whose notification parameters are not necessarily network-visible.
    """

    use TypedStruct

    @typedoc """
    Representative type for the notification parameter.
    """
    typedstruct do
      field :property_values, [BACnet.Protocol.PropertyValue.t()], enforce: true
    end

    @doc false
    def get_tag_number(), do: 6
  end

  defmodule ChangeOfLifeSafety do
    @moduledoc """
    Represents the BACnet event algorithm `ChangeOfLifeSafety` notification parameters.

    The ChangeOfLifeSafety event algorithm detects whether the monitored value equals a value that is listed as an
    alarm value or life safety alarm value. Event state transitions are also indicated if the value of the mode parameter changed
    since the last transition indicated. In this case, any time delays are overridden and the transition is indicated immediately.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.8.
    """

    use TypedStruct

    @typedoc """
    Representative type for the notification parameter.
    """
    typedstruct do
      field :new_state, BACnet.Protocol.Constants.life_safety_state(), enforce: true
      field :new_mode, BACnet.Protocol.Constants.life_safety_mode(), enforce: true
      field :status_flags, BACnet.Protocol.StatusFlags.t(), enforce: true

      field :operation_expected, BACnet.Protocol.Constants.life_safety_operation(), enforce: true
    end

    @doc false
    def get_tag_number(), do: 8
  end

  defmodule Extended do
    @moduledoc """
    Represents the BACnet event algorithm `Extended` notification parameters.

    The Extended event algorithm detects notification conditions based on a proprietary event algorithm. The proprietary notification
    algorithm uses parameters and conditions defined by the vendor. The algorithm is identified by a vendor-specific notification type
    that is in the scope of the vendor's vendor identification code. The algorithm may, at the vendor's discretion, indicate a new
    notification state, a transition to the same notification state, or no transition to the Event-State-Detection. The indicated new notification states
    may be NORMAL, and any OffNormal notification state. FAULT notification state may not be indicated by this algorithm. For the
    purpose of proprietary evaluation of unreliability conditions that may result in FAULT notification state, a FAULT_EXTENDED
    fault algorithm shall be used.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.10.
    """

    use TypedStruct

    @typedoc """
    Representative type for the notification parameter.
    """
    typedstruct do
      field :vendor_id, BACnet.Protocol.ApplicationTags.unsigned16(), enforce: true
      field :extended_notification_type, non_neg_integer(), enforce: true
      field :parameters, [BACnet.Protocol.ApplicationTags.Encoding.t()], enforce: true
    end

    @doc false
    def get_tag_number(), do: 9
  end

  defmodule BufferReady do
    @moduledoc """
    Represents the BACnet event algorithm `BufferReady` notification parameters.

    The BufferReady event algorithm detects whether a defined number of records have been added to a log buffer since
    start of operation or the previous notification, whichever is most recent.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.7.
    """

    use TypedStruct

    @typedoc """
    Representative type for the notification parameter.
    """
    typedstruct do
      field :buffer_property, DeviceObjectPropertyRef.t(), enforce: true
      field :previous_notification, BACnet.Protocol.ApplicationTags.unsigned32(), enforce: true
      field :current_notification, BACnet.Protocol.ApplicationTags.unsigned32(), enforce: true
    end

    @doc false
    def get_tag_number(), do: 10
  end

  defmodule UnsignedRange do
    @moduledoc """
    Represents the BACnet event algorithm `UnsignedRange` notification parameters.

    The UnsignedRange event algorithm detects whether the monitored value exceeds a range defined by a high limit and
    a low limit.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.9.
    """

    use TypedStruct

    @typedoc """
    Representative type for the notification parameter.
    """
    typedstruct do
      field :exceeding_value, non_neg_integer(), enforce: true
      field :status_flags, BACnet.Protocol.StatusFlags.t(), enforce: true
      field :exceeded_limit, non_neg_integer(), enforce: true
    end

    @doc false
    def get_tag_number(), do: 11
  end

  # AccessEvent (13, 13.3.12) not implemented

  defmodule DoubleOutOfRange do
    @moduledoc """
    Represents the BACnet event algorithm `DoubleOutOfRange` notification parameters.

    The DoubleOutOfRange event algorithm detects whether the monitored value exceeds a range defined by a high
    limit and a low limit. Each of these limits may be enabled or disabled. If disabled, the normal range has no lower limit or no
    higher limit respectively. In order to reduce jitter of the resulting notification state, a deadband is applied when the value is in the
    process of returning to the normal range.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.13.
    """

    use TypedStruct

    @typedoc """
    Representative type for the notification parameter.
    """
    typedstruct do
      field :exceeding_value, float(), enforce: true
      field :status_flags, BACnet.Protocol.StatusFlags.t(), enforce: true
      field :deadband, float(), enforce: true
      field :exceeded_limit, float(), enforce: true
    end

    @doc false
    def get_tag_number(), do: 14
  end

  defmodule SignedOutOfRange do
    @moduledoc """
    Represents the BACnet event algorithm `SignedOutOfRange` notification parameters.

    The SignedOutOfRange event algorithm detects whether the monitored value exceeds a range defined by a high
    limit and a low limit. Each of these limits may be enabled or disabled. If disabled, the normal range has no lower limit or no
    higher limit respectively. In order to reduce jitter of the resulting notification state, a deadband is applied when the value is in the
    process of returning to the normal range.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.14.
    """

    use TypedStruct

    @typedoc """
    Representative type for the notification parameter.
    """
    typedstruct do
      field :exceeding_value, integer(), enforce: true
      field :status_flags, BACnet.Protocol.StatusFlags.t(), enforce: true
      field :deadband, non_neg_integer(), enforce: true
      field :exceeded_limit, integer(), enforce: true
    end

    @doc false
    def get_tag_number(), do: 15
  end

  defmodule UnsignedOutOfRange do
    @moduledoc """
    Represents the BACnet event algorithm `UnsignedOutOfRange` notification parameters.

    The UnsignedOutOfRange event algorithm detects whether the monitored value exceeds a range defined by a high
    limit and a low limit. Each of these limits may be enabled or disabled. If disabled, the normal range has no lower limit or no
    higher limit respectively. In order to reduce jitter of the resulting notification state, a deadband is applied when the value is in the
    process of returning to the normal range.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.15.
    """

    use TypedStruct

    @typedoc """
    Representative type for the notification parameter.
    """
    typedstruct do
      field :exceeding_value, non_neg_integer(), enforce: true
      field :status_flags, BACnet.Protocol.StatusFlags.t(), enforce: true
      field :deadband, non_neg_integer(), enforce: true
      field :exceeded_limit, non_neg_integer(), enforce: true
    end

    @doc false
    def get_tag_number(), do: 16
  end

  defmodule ChangeOfCharacterString do
    @moduledoc """
    Represents the BACnet event algorithm `ChangeOfCharacterString` notification parameters.

    The ChangeOfCharacterString event algorithm detects whether the monitored value matches a character string
    that is listed as an alarm value. Alarm values are of type BACnetOptionalCharacterString, and may also be NULL or an
    empty character string.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.16.
    """

    use TypedStruct

    @typedoc """
    Representative type for the notification parameter.
    """
    typedstruct do
      field :changed_value, String.t(), enforce: true
      field :status_flags, BACnet.Protocol.StatusFlags.t(), enforce: true
      field :alarm_value, String.t(), enforce: true
    end

    @doc false
    def get_tag_number(), do: 17
  end

  defmodule ChangeOfStatusFlags do
    @moduledoc """
    Represents the BACnet event algorithm `ChangeOfStatusFlags` notification parameters.

    The ChangeOfStatusFlags event algorithm detects whether a significant flag of the monitored value of type
    BACnetStatusFlags has the value TRUE.

    For more specific information about the event algorithm, consult ASHRAE 135 13.3.11.
    """

    use TypedStruct

    @typedoc """
    Representative type for the notification parameter.
    """
    typedstruct do
      field :present_value, BACnet.Protocol.ApplicationTags.Encoding.t()
      field :referenced_flags, BACnet.Protocol.StatusFlags.t(), enforce: true
    end

    @doc false
    def get_tag_number(), do: 18
  end

  defmodule ChangeOfReliability do
    @moduledoc """
    Represents the BACnet event algorithm `ChangeOfReliability` notification parameters.

    For all transitions to, or from, the FAULT state, the corresponding notification notification shall use the Event Type
    ChangeOfReliability.

    For more specific information about the fault notification event algorithm, consult ASHRAE 135 13.2.5.3.
    """

    use TypedStruct

    @typedoc """
    Representative type for the notification parameter.
    """
    typedstruct do
      field :reliability, BACnet.Protocol.Constants.reliability(), enforce: true
      field :status_flags, BACnet.Protocol.StatusFlags.t(), enforce: true
      field :property_values, [BACnet.Protocol.PropertyValue.t()], enforce: true
    end

    @doc false
    def get_tag_number(), do: 19
  end

  # TODO: Docs
  @spec parse(ApplicationTags.encoding()) :: {:ok, notification_parameter()} | {:error, term()}
  def parse(notification_values_tag)

  # 0 = Change Of Bitstring
  def parse({:constructed, {0, notification_values, 0}}) do
    case notification_values do
      [
        tagged: {0, bitstring_raw, _length},
        tagged: {1, status_raw, _length2}
      ] ->
        with {:ok, {:bitstring, bitstring}} <-
               ApplicationTags.unfold_to_type(:bitstring, bitstring_raw),
             {:ok, {:bitstring, statusflags_bs}} when tuple_size(statusflags_bs) == 4 <-
               ApplicationTags.unfold_to_type(:bitstring, status_raw),
             %StatusFlags{} = status_flags <- StatusFlags.from_bitstring(statusflags_bs) do
          notification = %ChangeOfBitstring{
            referenced_bitstring: bitstring,
            status_flags: status_flags
          }

          {:ok, notification}
        else
          {:ok, _value} -> {:error, :invalid_notification_values}
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_notification_values}
    end
  end

  # 1 = Change Of State
  def parse({:constructed, {1, notification_values, 0}}) do
    case notification_values do
      [
        constructed: {0, new_state_raw, _length},
        tagged: {1, status_raw, _length2}
      ] ->
        with {:ok, {new_state, _rest}} <-
               PropertyState.parse([new_state_raw]),
             {:ok, {:bitstring, statusflags_bs}} when tuple_size(statusflags_bs) == 4 <-
               ApplicationTags.unfold_to_type(:bitstring, status_raw),
             %StatusFlags{} = status_flags <- StatusFlags.from_bitstring(statusflags_bs) do
          notification = %ChangeOfState{
            new_state: new_state,
            status_flags: status_flags
          }

          {:ok, notification}
        else
          {:ok, _value} -> {:error, :invalid_notification_values}
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_notification_values}
    end
  end

  # 2 = Change Of Value
  def parse({:constructed, {2, notification_values, 0}}) do
    case notification_values do
      [
        constructed: {0, new_value_raw, _length},
        tagged: {1, status_raw, _length2}
      ] ->
        with {:ok, new_value_bits, new_value_real} <-
               (case new_value_raw do
                  {:tagged, {0, term, _len}} ->
                    with {:ok, {:bitstring, bits}} <-
                           ApplicationTags.unfold_to_type(:bitstring, term) do
                      {:ok, bits, nil}
                    end

                  {:tagged, {1, term, _len}} ->
                    with {:ok, {:real, real}} <- ApplicationTags.unfold_to_type(:real, term) do
                      {:ok, nil, real}
                    end
                end),
             {:ok, {:bitstring, statusflags_bs}} when tuple_size(statusflags_bs) == 4 <-
               ApplicationTags.unfold_to_type(:bitstring, status_raw),
             %StatusFlags{} = status_flags <- StatusFlags.from_bitstring(statusflags_bs) do
          notification = %ChangeOfValue{
            changed_bits: new_value_bits,
            changed_value: new_value_real,
            status_flags: status_flags
          }

          {:ok, notification}
        else
          {:ok, _value} -> {:error, :invalid_notification_values}
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_notification_values}
    end
  end

  # 3 = Command Failure
  def parse({:constructed, {3, notification_values, 0}}) do
    case notification_values do
      [
        constructed: {0, command_value, _length},
        tagged: {1, status_raw, _length2},
        constructed: {2, feedback_value, _length3}
      ] ->
        with {:ok, {:bitstring, statusflags_bs}} when tuple_size(statusflags_bs) == 4 <-
               ApplicationTags.unfold_to_type(:bitstring, status_raw),
             %StatusFlags{} = status_flags <- StatusFlags.from_bitstring(statusflags_bs) do
          notification = %CommandFailure{
            command_value: ApplicationTags.Encoding.create!(command_value),
            status_flags: status_flags,
            feedback_value: ApplicationTags.Encoding.create!(feedback_value)
          }

          {:ok, notification}
        else
          {:ok, _value} -> {:error, :invalid_notification_values}
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_notification_values}
    end
  end

  # 4 = Floating Limit
  def parse({:constructed, {4, notification_values, 0}}) do
    case notification_values do
      [
        tagged: {0, ref_value_raw, _length},
        tagged: {1, status_raw, _length2},
        tagged: {2, setpoint_value_raw, _length3},
        tagged: {3, error_limit_raw, _length4}
      ] ->
        with {:ok, {:real, ref_value}} <-
               ApplicationTags.unfold_to_type(:real, ref_value_raw),
             {:ok, {:bitstring, statusflags_bs}} when tuple_size(statusflags_bs) == 4 <-
               ApplicationTags.unfold_to_type(:bitstring, status_raw),
             %StatusFlags{} = status_flags <- StatusFlags.from_bitstring(statusflags_bs),
             {:ok, {:real, setpoint_value}} <-
               ApplicationTags.unfold_to_type(:real, setpoint_value_raw),
             {:ok, {:real, error_limit}} <-
               ApplicationTags.unfold_to_type(:real, error_limit_raw) do
          notification = %FloatingLimit{
            reference_value: ref_value,
            status_flags: status_flags,
            setpoint_value: setpoint_value,
            error_limit: error_limit
          }

          {:ok, notification}
        else
          {:ok, _value} -> {:error, :invalid_notification_values}
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_notification_values}
    end
  end

  # 5 = Out Of Range
  def parse({:constructed, {5, notification_values, 0}}) do
    case notification_values do
      [
        tagged: {0, exceeding_value_raw, _length},
        tagged: {1, status_raw, _length2},
        tagged: {2, deadband_raw, _length3},
        tagged: {3, exceeded_limit_raw, _length4}
      ] ->
        with {:ok, {:real, exceeding_value}} <-
               ApplicationTags.unfold_to_type(:real, exceeding_value_raw),
             {:ok, {:bitstring, statusflags_bs}} when tuple_size(statusflags_bs) == 4 <-
               ApplicationTags.unfold_to_type(:bitstring, status_raw),
             %StatusFlags{} = status_flags <- StatusFlags.from_bitstring(statusflags_bs),
             {:ok, {:real, deadband}} <-
               ApplicationTags.unfold_to_type(:real, deadband_raw),
             {:ok, {:real, exceeded_limit}} <-
               ApplicationTags.unfold_to_type(:real, exceeded_limit_raw) do
          notification = %OutOfRange{
            exceeding_value: exceeding_value,
            status_flags: status_flags,
            deadband: deadband,
            exceeded_limit: exceeded_limit
          }

          {:ok, notification}
        else
          {:ok, _value} -> {:error, :invalid_notification_values}
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_notification_values}
    end
  end

  # 6 = Complex Event Type
  def parse({:constructed, {6, [], 0}}) do
    notification = %ComplexEventType{
      property_values: []
    }

    {:ok, notification}
  end

  # 6 = Complex Event Type
  def parse({:constructed, {6, notification_values, 0}}) when is_list(notification_values) do
    case BACnet.Protocol.PropertyValue.parse_all(notification_values) do
      {:ok, prop_value} ->
        notification = %ComplexEventType{
          property_values: prop_value
        }

        {:ok, notification}

      {:error, _term} = term ->
        term
    end
  end

  # 8 = Change Of Life Safety
  def parse({:constructed, {8, notification_values, 0}}) do
    case notification_values do
      [
        tagged: {0, life_safety_state_raw, _length},
        tagged: {1, life_safety_mode_raw, _length2},
        tagged: {2, status_raw, _length3},
        tagged: {3, life_safety_operation_raw, _length4}
      ] ->
        with {:ok, {:enumerated, life_safety_state}} <-
               ApplicationTags.unfold_to_type(:enumerated, life_safety_state_raw),
             {:ok, ls_state_c} <-
               Constants.by_value_with_reason(
                 :life_safety_state,
                 life_safety_state,
                 {:unknown_life_safety_state, life_safety_state}
               ),
             {:ok, {:enumerated, life_safety_mode}} <-
               ApplicationTags.unfold_to_type(:enumerated, life_safety_mode_raw),
             {:ok, ls_mode_c} <-
               Constants.by_value_with_reason(
                 :life_safety_mode,
                 life_safety_mode,
                 {:unknown_life_safety_mode, life_safety_mode}
               ),
             {:ok, {:bitstring, statusflags_bs}} when tuple_size(statusflags_bs) == 4 <-
               ApplicationTags.unfold_to_type(:bitstring, status_raw),
             %StatusFlags{} = status_flags <- StatusFlags.from_bitstring(statusflags_bs),
             {:ok, {:enumerated, life_safety_operation}} <-
               ApplicationTags.unfold_to_type(:enumerated, life_safety_operation_raw),
             {:ok, ls_operation_c} <-
               Constants.by_value_with_reason(
                 :life_safety_operation,
                 life_safety_operation,
                 {:unknown_life_safety_operation, life_safety_operation}
               ) do
          notification = %ChangeOfLifeSafety{
            new_state: ls_state_c,
            new_mode: ls_mode_c,
            status_flags: status_flags,
            operation_expected: ls_operation_c
          }

          {:ok, notification}
        else
          {:ok, _value} -> {:error, :invalid_notification_values}
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_notification_values}
    end
  end

  # 9 = Extended
  def parse({:constructed, {9, notification_values, 0}}) do
    case notification_values do
      [
        tagged: {0, vendor_id_raw, _length},
        tagged: {1, ext_notification_raw, _length2},
        constructed: {2, parameters, _length3}
      ] ->
        with {:ok, {:unsigned_integer, vendor_id}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, vendor_id_raw),
             :ok <-
               if(ApplicationTags.valid_int?(vendor_id, 16),
                 do: :ok,
                 else: {:error, :invalid_vendor_id_value}
               ),
             {:ok, {:unsigned_integer, ext_notification}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, ext_notification_raw) do
          notification = %Extended{
            vendor_id: vendor_id,
            extended_notification_type: ext_notification,
            parameters: Enum.map(List.wrap(parameters), &ApplicationTags.Encoding.create!/1)
          }

          {:ok, notification}
        else
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_notification_values}
    end
  end

  # 10 = Buffer Ready
  def parse({:constructed, {10, notification_values, 0}}) do
    case notification_values do
      [
        constructed: {0, devobjref_raw, _length},
        tagged: {1, prev_notification_raw, _length2},
        tagged: {2, current_notification_raw, _length3}
      ] ->
        with {:ok, {dev_obj_ref, _rest}} <- DeviceObjectPropertyRef.parse(devobjref_raw),
             {:ok, {:unsigned_integer, prev_notification}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, prev_notification_raw),
             :ok <-
               if(ApplicationTags.valid_int?(prev_notification, 32),
                 do: :ok,
                 else: {:error, :invalid_previous_notification_value}
               ),
             {:ok, {:unsigned_integer, current_notification}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, current_notification_raw),
             :ok <-
               if(ApplicationTags.valid_int?(current_notification, 32),
                 do: :ok,
                 else: {:error, :invalid_current_notification_value}
               ) do
          notification = %BufferReady{
            buffer_property: dev_obj_ref,
            previous_notification: prev_notification,
            current_notification: current_notification
          }

          {:ok, notification}
        else
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_notification_values}
    end
  end

  # 11 = Unsigned Range
  def parse({:constructed, {11, notification_values, 0}}) do
    case notification_values do
      [
        tagged: {0, exceeding_value_raw, _length},
        tagged: {1, status_raw, _length2},
        tagged: {2, exceeded_limit_raw, _length4}
      ] ->
        with {:ok, {:unsigned_integer, exceeding_value}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, exceeding_value_raw),
             {:ok, {:bitstring, statusflags_bs}} when tuple_size(statusflags_bs) == 4 <-
               ApplicationTags.unfold_to_type(:bitstring, status_raw),
             %StatusFlags{} = status_flags <- StatusFlags.from_bitstring(statusflags_bs),
             {:ok, {:unsigned_integer, exceeded_limit}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, exceeded_limit_raw) do
          notification = %UnsignedRange{
            exceeding_value: exceeding_value,
            status_flags: status_flags,
            exceeded_limit: exceeded_limit
          }

          {:ok, notification}
        else
          {:ok, _value} -> {:error, :invalid_notification_values}
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_notification_values}
    end
  end

  # 13 = Access Event
  def parse({:constructed, {13, _notification_values, 0}}) do
    {:error, :not_supported_notification_type}
  end

  # 14 = Double Out Of Range
  def parse({:constructed, {14, notification_values, 0}}) do
    case notification_values do
      [
        tagged: {0, exceeding_value_raw, _length},
        tagged: {1, status_raw, _length2},
        tagged: {2, deadband_raw, _length3},
        tagged: {3, exceeded_limit_raw, _length4}
      ] ->
        with {:ok, {:double, exceeding_value}} <-
               ApplicationTags.unfold_to_type(:double, exceeding_value_raw),
             {:ok, {:bitstring, statusflags_bs}} when tuple_size(statusflags_bs) == 4 <-
               ApplicationTags.unfold_to_type(:bitstring, status_raw),
             %StatusFlags{} = status_flags <- StatusFlags.from_bitstring(statusflags_bs),
             {:ok, {:double, deadband}} <-
               ApplicationTags.unfold_to_type(:double, deadband_raw),
             {:ok, {:double, exceeded_limit}} <-
               ApplicationTags.unfold_to_type(:double, exceeded_limit_raw) do
          notification = %DoubleOutOfRange{
            exceeding_value: exceeding_value,
            status_flags: status_flags,
            deadband: deadband,
            exceeded_limit: exceeded_limit
          }

          {:ok, notification}
        else
          {:ok, _value} -> {:error, :invalid_notification_values}
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_notification_values}
    end
  end

  # 15 = Signed Out Of Range
  def parse({:constructed, {15, notification_values, 0}}) do
    case notification_values do
      [
        tagged: {0, exceeding_value_raw, _length},
        tagged: {1, status_raw, _length2},
        tagged: {2, deadband_raw, _length3},
        tagged: {3, exceeded_limit_raw, _length4}
      ] ->
        with {:ok, {:signed_integer, exceeding_value}} <-
               ApplicationTags.unfold_to_type(:signed_integer, exceeding_value_raw),
             {:ok, {:bitstring, statusflags_bs}} when tuple_size(statusflags_bs) == 4 <-
               ApplicationTags.unfold_to_type(:bitstring, status_raw),
             %StatusFlags{} = status_flags <- StatusFlags.from_bitstring(statusflags_bs),
             {:ok, {:unsigned_integer, deadband}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, deadband_raw),
             {:ok, {:signed_integer, exceeded_limit}} <-
               ApplicationTags.unfold_to_type(:signed_integer, exceeded_limit_raw) do
          notification = %SignedOutOfRange{
            exceeding_value: exceeding_value,
            status_flags: status_flags,
            deadband: deadband,
            exceeded_limit: exceeded_limit
          }

          {:ok, notification}
        else
          {:ok, _value} -> {:error, :invalid_notification_values}
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_notification_values}
    end
  end

  # 16 = Unsigned Out Of Range
  def parse({:constructed, {16, notification_values, 0}}) do
    case notification_values do
      [
        tagged: {0, exceeding_value_raw, _length},
        tagged: {1, status_raw, _length2},
        tagged: {2, deadband_raw, _length3},
        tagged: {3, exceeded_limit_raw, _length4}
      ] ->
        with {:ok, {:unsigned_integer, exceeding_value}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, exceeding_value_raw),
             {:ok, {:bitstring, statusflags_bs}} when tuple_size(statusflags_bs) == 4 <-
               ApplicationTags.unfold_to_type(:bitstring, status_raw),
             %StatusFlags{} = status_flags <- StatusFlags.from_bitstring(statusflags_bs),
             {:ok, {:unsigned_integer, deadband}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, deadband_raw),
             {:ok, {:unsigned_integer, exceeded_limit}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, exceeded_limit_raw) do
          notification = %UnsignedOutOfRange{
            exceeding_value: exceeding_value,
            status_flags: status_flags,
            deadband: deadband,
            exceeded_limit: exceeded_limit
          }

          {:ok, notification}
        else
          {:ok, _value} -> {:error, :invalid_notification_values}
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_notification_values}
    end
  end

  # 17 = Change Of Character String
  def parse({:constructed, {17, notification_values, 0}}) do
    case notification_values do
      [
        tagged: {0, changed_value_raw, _length},
        tagged: {1, status_raw, _length2},
        tagged: {2, alarm_value_raw, _length3}
      ] ->
        with {:ok, {:character_string, changed_value}} <-
               ApplicationTags.unfold_to_type(:character_string, changed_value_raw),
             {:ok, {:bitstring, statusflags_bs}} when tuple_size(statusflags_bs) == 4 <-
               ApplicationTags.unfold_to_type(:bitstring, status_raw),
             %StatusFlags{} = status_flags <- StatusFlags.from_bitstring(statusflags_bs),
             {:ok, {:character_string, alarm_value}} <-
               ApplicationTags.unfold_to_type(:character_string, alarm_value_raw) do
          notification = %ChangeOfCharacterString{
            changed_value: changed_value,
            status_flags: status_flags,
            alarm_value: alarm_value
          }

          {:ok, notification}
        else
          {:ok, _value} -> {:error, :invalid_notification_values}
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_notification_values}
    end
  end

  # 18 = Change Of Status Flags
  def parse({:constructed, {18, notification_values, 0}}) do
    with {:ok, present_value, rest} <-
           (case pattern_extract_tags(notification_values, {:constructed, {0, _v, _l}}, nil, true) do
              {:ok, {:constructed, {0, term, _l}}, rest} ->
                {:ok, ApplicationTags.Encoding.create!(term), rest}

              term ->
                term
            end),
         {:ok, statusflags_bs, _rest} when tuple_size(statusflags_bs) == 4 <-
           pattern_extract_tags(rest, {:tagged, {1, _v, _l}}, :bitstring, false),
         %StatusFlags{} = ref_flags <- StatusFlags.from_bitstring(statusflags_bs) do
      notification = %ChangeOfStatusFlags{
        present_value: present_value,
        referenced_flags: ref_flags
      }

      {:ok, notification}
    else
      {:ok, _value, _rest} -> {:error, :invalid_notification_values}
      {:error, _err} = err -> err
    end
  end

  # 19 = Change Of Reliability
  def parse({:constructed, {19, notification_values, 0}}) do
    case notification_values do
      [
        tagged: {0, reliability_raw, _length},
        tagged: {1, status_raw, _length2},
        # TODO: May be not constructed (tagged)
        constructed: {2, prop_value_raw, _length3}
      ] ->
        with {:ok, {:enumerated, reliability}} <-
               ApplicationTags.unfold_to_type(:enumerated, reliability_raw),
             {:ok, reliability_c} <-
               Constants.by_value_with_reason(
                 :reliability,
                 reliability,
                 {:unknown_reliability, reliability}
               ),
             {:ok, {:bitstring, statusflags_bs}} when tuple_size(statusflags_bs) == 4 <-
               ApplicationTags.unfold_to_type(:bitstring, status_raw),
             %StatusFlags{} = status_flags <- StatusFlags.from_bitstring(statusflags_bs),
             {:ok, prop_value} <-
               if(prop_value_raw == [],
                 do: {:ok, []},
                 else: BACnet.Protocol.PropertyValue.parse_all(prop_value_raw)
               ) do
          notification = %ChangeOfReliability{
            reliability: reliability_c,
            status_flags: status_flags,
            property_values: prop_value
          }

          {:ok, notification}
        else
          {:ok, _value} -> {:error, :invalid_notification_values}
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_notification_values}
    end
  end

  def parse(_notification_values_tag) do
    {:error, :invalid_tag}
  end

  # TODO: Docs
  @spec encode(notification_parameter(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding()} | {:error, term()}
  def encode(notification_params, opts \\ [])

  def encode(%ChangeOfBitstring{} = params, opts) do
    with true <- is_tuple(params.referenced_bitstring),
         true <- is_struct(params.status_flags, StatusFlags),
         {:ok, bits, _header} <-
           ApplicationTags.encode_value({:bitstring, params.referenced_bitstring}, opts),
         {:ok, flags, _header} <-
           ApplicationTags.encode_value(StatusFlags.to_bitstring(params.status_flags), opts) do
      {:ok,
       {:constructed,
        {0,
         [
           tagged: {0, bits, byte_size(bits)},
           tagged: {1, flags, byte_size(flags)}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%ChangeOfState{} = params, opts) do
    with true <- is_struct(params.new_state, PropertyState),
         true <- is_struct(params.status_flags, StatusFlags),
         {:ok, [state]} <-
           PropertyState.encode(params.new_state, opts),
         {:ok, flags, _header} <-
           ApplicationTags.encode_value(StatusFlags.to_bitstring(params.status_flags), opts) do
      {:ok,
       {:constructed,
        {1,
         [
           constructed: {0, state, 0},
           tagged: {1, flags, byte_size(flags)}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%ChangeOfValue{} = params, opts) do
    with true <- is_tuple(params.changed_bits) or is_nil(params.changed_bits),
         true <- is_float(params.changed_value) or is_nil(params.changed_value),
         true <- :erlang.xor(is_nil(params.changed_bits), is_nil(params.changed_value)),
         true <- is_struct(params.status_flags, StatusFlags),
         {:ok, bits} <-
           (if params.changed_bits do
              with {:ok, bytes, _header} <-
                     ApplicationTags.encode_value({:bitstring, params.changed_bits}) do
                {:ok, {:tagged, {0, bytes, byte_size(bytes)}}}
              end
            else
              {:ok, nil}
            end),
         {:ok, float} <-
           (if params.changed_value do
              with {:ok, bytes, _header} <-
                     ApplicationTags.encode_value({:real, params.changed_value}) do
                {:ok, {:tagged, {1, bytes, byte_size(bytes)}}}
              end
            else
              {:ok, nil}
            end),
         {:ok, flags, _header} <-
           ApplicationTags.encode_value(StatusFlags.to_bitstring(params.status_flags), opts) do
      {:ok,
       {:constructed,
        {2,
         [
           constructed: {0, bits || float, 0},
           tagged: {1, flags, byte_size(flags)}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%CommandFailure{} = params, opts) do
    with true <- is_struct(params.command_value, ApplicationTags.Encoding),
         true <- is_struct(params.status_flags, StatusFlags),
         true <- is_struct(params.feedback_value, ApplicationTags.Encoding),
         {:ok, command} <-
           ApplicationTags.Encoding.to_encoding(params.command_value),
         {:ok, flags, _header} <-
           ApplicationTags.encode_value(StatusFlags.to_bitstring(params.status_flags), opts),
         {:ok, feedback} <-
           ApplicationTags.Encoding.to_encoding(params.feedback_value) do
      {:ok,
       {:constructed,
        {3,
         [
           constructed: {0, command, 0},
           tagged: {1, flags, byte_size(flags)},
           constructed: {2, feedback, 0}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%FloatingLimit{} = params, opts) do
    with true <- is_float(params.reference_value),
         true <- is_struct(params.status_flags, StatusFlags),
         true <- is_float(params.setpoint_value),
         true <- is_float(params.error_limit),
         {:ok, refvalue, _header} <-
           ApplicationTags.encode_value({:real, params.reference_value}, opts),
         {:ok, flags, _header} <-
           ApplicationTags.encode_value(StatusFlags.to_bitstring(params.status_flags), opts),
         {:ok, setvalue, _header} <-
           ApplicationTags.encode_value({:real, params.setpoint_value}, opts),
         {:ok, errlimit, _header} <-
           ApplicationTags.encode_value({:real, params.error_limit}, opts) do
      {:ok,
       {:constructed,
        {4,
         [
           tagged: {0, refvalue, byte_size(refvalue)},
           tagged: {1, flags, byte_size(flags)},
           tagged: {2, setvalue, byte_size(setvalue)},
           tagged: {3, errlimit, byte_size(errlimit)}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%OutOfRange{} = params, opts) do
    with true <- is_float(params.exceeding_value),
         true <- is_struct(params.status_flags, StatusFlags),
         true <- is_float(params.deadband),
         true <- is_float(params.exceeded_limit),
         {:ok, excvalue, _header} <-
           ApplicationTags.encode_value({:real, params.exceeding_value}, opts),
         {:ok, flags, _header} <-
           ApplicationTags.encode_value(StatusFlags.to_bitstring(params.status_flags), opts),
         {:ok, deadband, _header} <-
           ApplicationTags.encode_value({:real, params.deadband}, opts),
         {:ok, exclimit, _header} <-
           ApplicationTags.encode_value({:real, params.exceeded_limit}, opts) do
      {:ok,
       {:constructed,
        {5,
         [
           tagged: {0, excvalue, byte_size(excvalue)},
           tagged: {1, flags, byte_size(flags)},
           tagged: {2, deadband, byte_size(deadband)},
           tagged: {3, exclimit, byte_size(exclimit)}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%ComplexEventType{} = params, opts) do
    with true <- is_list(params.property_values),
         {:ok, propval} <-
           BACnet.Protocol.PropertyValue.encode_all(params.property_values, opts) do
      {:ok, {:constructed, {6, propval, 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%ChangeOfLifeSafety{} = params, opts) do
    with true <- is_struct(params.status_flags, StatusFlags),
         {:ok, new_state_c} <-
           Constants.by_name_with_reason(
             :life_safety_state,
             params.new_state,
             {:unknown_life_safety_state, params.new_state}
           ),
         {:ok, new_state, _header} <-
           ApplicationTags.encode_value({:enumerated, new_state_c}, opts),
         {:ok, new_mode_c} <-
           Constants.by_name_with_reason(
             :life_safety_mode,
             params.new_mode,
             {:unknown_life_safety_mode, params.new_mode}
           ),
         {:ok, new_mode, _header} <-
           ApplicationTags.encode_value({:enumerated, new_mode_c}, opts),
         {:ok, flags, _header} <-
           ApplicationTags.encode_value(StatusFlags.to_bitstring(params.status_flags), opts),
         {:ok, lsop_c} <-
           Constants.by_name_with_reason(
             :life_safety_operation,
             params.operation_expected,
             {:unknown_life_safety_operation, params.operation_expected}
           ),
         {:ok, lsop, _header} <-
           ApplicationTags.encode_value({:enumerated, lsop_c}, opts) do
      {:ok,
       {:constructed,
        {8,
         [
           tagged: {0, new_state, byte_size(new_state)},
           tagged: {1, new_mode, byte_size(new_mode)},
           tagged: {2, flags, byte_size(flags)},
           tagged: {3, lsop, byte_size(lsop)}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%Extended{} = params, opts) do
    with true <-
           is_integer(params.vendor_id) and params.vendor_id >= 0 and params.vendor_id <= 65_535,
         true <-
           is_integer(params.extended_notification_type) and
             params.extended_notification_type >= 0,
         true <-
           is_list(params.parameters) and
             Enum.all?(params.parameters, &is_struct(&1, ApplicationTags.Encoding)),
         {:ok, vendor_id, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.vendor_id}, opts),
         {:ok, extended_notification_type, _header} <-
           ApplicationTags.encode_value(
             {:unsigned_integer, params.extended_notification_type},
             opts
           ),
         {:ok, parameters} <-
           Enum.reduce_while(params.parameters, {:ok, []}, fn param, {:ok, acc} ->
             case ApplicationTags.Encoding.to_encoding(param) do
               {:ok, parameters} -> {:cont, {:ok, [parameters | acc]}}
               term -> {:halt, term}
             end
           end) do
      {:ok,
       {:constructed,
        {9,
         [
           tagged: {0, vendor_id, byte_size(vendor_id)},
           tagged: {1, extended_notification_type, byte_size(extended_notification_type)},
           constructed: {2, Enum.reverse(parameters), 0}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%BufferReady{} = params, opts) do
    with true <- is_struct(params.buffer_property, DeviceObjectPropertyRef),
         true <-
           is_integer(params.previous_notification) and params.previous_notification >= 0 and
             ApplicationTags.valid_int?(params.previous_notification, 32),
         true <-
           is_integer(params.current_notification) and params.current_notification >= 0 and
             ApplicationTags.valid_int?(params.current_notification, 32),
         {:ok, bufferobj} <- DeviceObjectPropertyRef.encode(params.buffer_property, opts),
         {:ok, previous_notification, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.previous_notification}, opts),
         {:ok, current_notification, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.current_notification}, opts) do
      {:ok,
       {:constructed,
        {10,
         [
           constructed: {0, bufferobj, 0},
           tagged: {1, previous_notification, byte_size(previous_notification)},
           tagged: {2, current_notification, byte_size(current_notification)}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%UnsignedRange{} = params, opts) do
    with true <- is_integer(params.exceeding_value) and params.exceeding_value >= 0,
         true <- is_struct(params.status_flags, StatusFlags),
         true <- is_integer(params.exceeded_limit) and params.exceeded_limit >= 0,
         {:ok, excvalue, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.exceeding_value}, opts),
         {:ok, flags, _header} <-
           ApplicationTags.encode_value(StatusFlags.to_bitstring(params.status_flags), opts),
         {:ok, exclimit, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.exceeded_limit}, opts) do
      {:ok,
       {:constructed,
        {11,
         [
           tagged: {0, excvalue, byte_size(excvalue)},
           tagged: {1, flags, byte_size(flags)},
           tagged: {2, exclimit, byte_size(exclimit)}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%DoubleOutOfRange{} = params, opts) do
    with true <- is_float(params.exceeding_value),
         true <- is_struct(params.status_flags, StatusFlags),
         true <- is_float(params.deadband),
         true <- is_float(params.exceeded_limit),
         {:ok, excvalue, _header} <-
           ApplicationTags.encode_value({:double, params.exceeding_value}, opts),
         {:ok, flags, _header} <-
           ApplicationTags.encode_value(StatusFlags.to_bitstring(params.status_flags), opts),
         {:ok, deadband, _header} <-
           ApplicationTags.encode_value({:double, params.deadband}, opts),
         {:ok, exclimit, _header} <-
           ApplicationTags.encode_value({:double, params.exceeded_limit}, opts) do
      {:ok,
       {:constructed,
        {14,
         [
           tagged: {0, excvalue, byte_size(excvalue)},
           tagged: {1, flags, byte_size(flags)},
           tagged: {2, deadband, byte_size(deadband)},
           tagged: {3, exclimit, byte_size(exclimit)}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%SignedOutOfRange{} = params, opts) do
    with true <- is_integer(params.exceeding_value),
         true <- is_struct(params.status_flags, StatusFlags),
         true <- is_integer(params.deadband) and params.deadband >= 0,
         true <- is_integer(params.exceeded_limit),
         {:ok, excvalue, _header} <-
           ApplicationTags.encode_value({:signed_integer, params.exceeding_value}, opts),
         {:ok, flags, _header} <-
           ApplicationTags.encode_value(StatusFlags.to_bitstring(params.status_flags), opts),
         {:ok, deadband, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.deadband}, opts),
         {:ok, exclimit, _header} <-
           ApplicationTags.encode_value({:signed_integer, params.exceeded_limit}, opts) do
      {:ok,
       {:constructed,
        {15,
         [
           tagged: {0, excvalue, byte_size(excvalue)},
           tagged: {1, flags, byte_size(flags)},
           tagged: {2, deadband, byte_size(deadband)},
           tagged: {3, exclimit, byte_size(exclimit)}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%UnsignedOutOfRange{} = params, opts) do
    with true <- is_integer(params.exceeding_value) and params.exceeding_value >= 0,
         true <- is_struct(params.status_flags, StatusFlags),
         true <- is_integer(params.deadband) and params.deadband >= 0,
         true <- is_integer(params.exceeded_limit) and params.exceeded_limit >= 0,
         {:ok, excvalue, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.exceeding_value}, opts),
         {:ok, flags, _header} <-
           ApplicationTags.encode_value(StatusFlags.to_bitstring(params.status_flags), opts),
         {:ok, deadband, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.deadband}, opts),
         {:ok, exclimit, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.exceeded_limit}, opts) do
      {:ok,
       {:constructed,
        {16,
         [
           tagged: {0, excvalue, byte_size(excvalue)},
           tagged: {1, flags, byte_size(flags)},
           tagged: {2, deadband, byte_size(deadband)},
           tagged: {3, exclimit, byte_size(exclimit)}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%ChangeOfCharacterString{} = params, opts) do
    with true <- is_binary(params.changed_value) and String.valid?(params.changed_value),
         true <- is_struct(params.status_flags, StatusFlags),
         true <- is_binary(params.alarm_value) and String.valid?(params.alarm_value),
         {:ok, changedvalue, _header} <-
           ApplicationTags.encode_value({:character_string, params.changed_value}, opts),
         {:ok, flags, _header} <-
           ApplicationTags.encode_value(StatusFlags.to_bitstring(params.status_flags), opts),
         {:ok, alvalue, _header} <-
           ApplicationTags.encode_value({:character_string, params.alarm_value}, opts) do
      {:ok,
       {:constructed,
        {17,
         [
           tagged: {0, changedvalue, byte_size(changedvalue)},
           tagged: {1, flags, byte_size(flags)},
           tagged: {2, alvalue, byte_size(alvalue)}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%ChangeOfStatusFlags{} = params, opts) do
    with true <- is_struct(params.referenced_flags, StatusFlags),
         true <-
           is_nil(params.present_value) or
             is_struct(params.present_value, ApplicationTags.Encoding),
         {:ok, flags, _header} <-
           ApplicationTags.encode_value(StatusFlags.to_bitstring(params.referenced_flags), opts),
         {:ok, present_value} <-
           (if params.present_value do
              with {:ok, pv} <-
                     ApplicationTags.Encoding.to_encoding(params.present_value) do
                {:ok, {:constructed, {0, pv, 0}}}
              end
            else
              {:ok, nil}
            end) do
      status_flags = {:tagged, {1, flags, byte_size(flags)}}

      tags =
        case params.present_value do
          nil -> [status_flags]
          _term -> [present_value, status_flags]
        end

      {:ok, {:constructed, {18, tags, 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%ChangeOfReliability{} = params, opts) do
    with true <- is_atom(params.reliability),
         true <- is_struct(params.status_flags, StatusFlags),
         {:ok, reliability_c} <-
           Constants.by_name_with_reason(
             :reliability,
             params.reliability,
             {:unknown_reliability, params.reliability}
           ),
         {:ok, reliability, _header} <-
           ApplicationTags.encode_value({:enumerated, reliability_c}, opts),
         {:ok, flags, _header} <-
           ApplicationTags.encode_value(StatusFlags.to_bitstring(params.status_flags), opts),
         {:ok, propvalue} <-
           BACnet.Protocol.PropertyValue.encode_all(params.property_values, opts) do
      {:ok,
       {:constructed,
        {19,
         [
           tagged: {0, reliability, byte_size(reliability)},
           tagged: {1, flags, byte_size(flags)},
           constructed: {2, propvalue, 0}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Validates whether the given notification parameter is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(notification_parameter()) :: boolean()
  def valid?(t)

  for module <- [
        __MODULE__.ChangeOfBitstring,
        __MODULE__.ChangeOfState,
        __MODULE__.ChangeOfValue,
        __MODULE__.CommandFailure,
        __MODULE__.FloatingLimit,
        __MODULE__.OutOfRange,
        __MODULE__.ComplexEventType,
        __MODULE__.ChangeOfLifeSafety,
        __MODULE__.Extended,
        __MODULE__.BufferReady,
        __MODULE__.UnsignedRange,
        __MODULE__.DoubleOutOfRange,
        __MODULE__.SignedOutOfRange,
        __MODULE__.UnsignedOutOfRange,
        __MODULE__.ChangeOfCharacterString,
        __MODULE__.ChangeOfStatusFlags,
        __MODULE__.ChangeOfReliability
      ] do
    var = Macro.var(:t, __MODULE__)

    def valid?(%unquote(module){} = unquote(var)) do
      unquote(BACnet.BeamTypes.generate_valid_clause(module, __ENV__))
    end
  end
end
