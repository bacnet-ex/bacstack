defmodule BACnet.Protocol.EventParameters do
  @moduledoc """
  BACnet event parameters describe the specific configuration and thresholds
  used by each event algorithm (see `BACnet.Protocol.EventAlgorithms`).

  Every object that supports intrinsic or algorithmic event reporting uses one
  of these parameter structures inside its `event_parameters` property. The
  choice of parameter type determines what conditions will cause the object to
  transition between NORMAL, OFFNORMAL, FAULT, and other event states, and what
  additional data is included in the resulting event notifications.

  This module provides the top-level encoding and parsing functions for all
  supported event parameter variants. The individual parameter modules
  (ChangeOfBitstring, OutOfRange, BufferReady, etc.) contain the actual fields
  and logic for each algorithm.

  Note: The `AccessEvent` algorithm and its parameters are not supported.

  ### Examples

  Common event parameter configurations (these are CHOICE variants):

  ```elixir
  # OutOfRange (very common for analog alarming)
  iex> %EventParameters.OutOfRange{
  ...>   time_delay: 30,
  ...>   low_limit: 10.0,
  ...>   high_limit: 90.0,
  ...>   deadband: 2.0
  ...> }

  # ChangeOfState
  iex> %EventParameters.ChangeOfState{
  ...>   time_delay: 0,
  ...>   alarm_values: [true]
  ...> }

  # BufferReady (for trend logs)
  iex> %EventParameters.BufferReady{
  ...>   notification_threshold: 100,
  ...>   previous_notification_count: 0
  ...> }
  ```

  These are placed inside the object's `event_parameters` property. Different objects support different subsets of these parameter types.
  """

  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.EventParameters.BufferReady
  alias BACnet.Protocol.EventParameters.ChangeOfBitstring
  alias BACnet.Protocol.EventParameters.ChangeOfCharacterString
  alias BACnet.Protocol.EventParameters.ChangeOfLifeSafety
  alias BACnet.Protocol.EventParameters.ChangeOfState
  alias BACnet.Protocol.EventParameters.ChangeOfStatusFlags
  alias BACnet.Protocol.EventParameters.ChangeOfValue
  alias BACnet.Protocol.EventParameters.CommandFailure
  alias BACnet.Protocol.EventParameters.DoubleOutOfRange
  alias BACnet.Protocol.EventParameters.Extended
  alias BACnet.Protocol.EventParameters.FloatingLimit
  alias BACnet.Protocol.EventParameters.None
  alias BACnet.Protocol.EventParameters.OutOfRange
  alias BACnet.Protocol.EventParameters.SignedOutOfRange
  alias BACnet.Protocol.EventParameters.UnsignedOutOfRange
  alias BACnet.Protocol.EventParameters.UnsignedRange
  alias BACnet.Protocol.StatusFlags

  @typedoc """
  Possible BACnet event parameters.
  """
  @type event_parameter ::
          ChangeOfBitstring.t()
          | ChangeOfState.t()
          | ChangeOfValue.t()
          | CommandFailure.t()
          | FloatingLimit.t()
          | OutOfRange.t()
          | ChangeOfLifeSafety.t()
          | Extended.t()
          | BufferReady.t()
          | UnsignedRange.t()
          | DoubleOutOfRange.t()
          | SignedOutOfRange.t()
          | UnsignedOutOfRange.t()
          | ChangeOfCharacterString.t()
          | ChangeOfStatusFlags.t()
          | None.t()

  @doc """
  Encodes an EventParameters struct (any of the algorithm variants) into the application-tag encoding.
  """
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
             ApplicationTags.valid_int?(params.threshold, 32),
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

  @doc """
  Parses the encoded event values from a notification or Event Enrollment object
  back into the corresponding EventParameters variant struct.
  """
  @spec parse(binary()) :: {:ok, event_parameter()} | {:error, term()}
  def parse(event_values_tag)

  # 0 = Change Of Bitstring
  def parse({:constructed, {0, event_values, 0}}) do
    case List.wrap(event_values) do
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
    case List.wrap(event_values) do
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
    case List.wrap(event_values) do
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
    case List.wrap(event_values) do
      [
        tagged: {0, time_delay_raw, _length},
        constructed: {_context2, 1, feedback_value, _length3}
      ] ->
        with {:ok, {:unsigned_integer, time_delay}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, time_delay_raw),
             {:ok, {feedback_value, _tags}} <- DeviceObjectPropertyRef.parse(feedback_value) do
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
    case List.wrap(event_values) do
      [
        tagged: {0, time_delay_raw, _length},
        constructed: {1, setpoint_ref_raw, _length2},
        tagged: {2, low_diff_raw, _length3},
        tagged: {3, high_diff_raw, _length4},
        tagged: {4, deadband_raw, _length5}
      ] ->
        with {:ok, {:unsigned_integer, time_delay}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, time_delay_raw),
             {:ok, {setpoint_ref, _tags}} <- DeviceObjectPropertyRef.parse(setpoint_ref_raw),
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
    case List.wrap(event_values) do
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
    case List.wrap(event_values) do
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
             {:ok, {mode, _tags}} <- DeviceObjectPropertyRef.parse(mode_raw) do
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
    case List.wrap(event_values) do
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
    case List.wrap(event_values) do
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
    case List.wrap(event_values) do
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
    case List.wrap(event_values) do
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
    case List.wrap(event_values) do
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
    case List.wrap(event_values) do
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
    case List.wrap(event_values) do
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
    case List.wrap(event_values) do
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
    case List.wrap(event_values) do
      [{:null, nil}] -> {:ok, %None{}}
      _term -> {:error, :invalid_event_values}
    end
  end

  # 20 = None
  def parse({:tagged, {20, "", 0}}) do
    {:ok, %None{}}
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
        ChangeOfBitstring,
        ChangeOfState,
        ChangeOfValue,
        CommandFailure,
        FloatingLimit,
        OutOfRange,
        ChangeOfLifeSafety,
        Extended,
        BufferReady,
        UnsignedRange,
        DoubleOutOfRange,
        SignedOutOfRange,
        UnsignedOutOfRange,
        ChangeOfCharacterString,
        ChangeOfStatusFlags,
        None
      ] do
    var = Macro.var(:t, __MODULE__)

    def valid?(%unquote(module){} = unquote(var)) do
      unquote(BACnet.BeamTypes.generate_valid_clause(module, __ENV__))
    end
  end
end
