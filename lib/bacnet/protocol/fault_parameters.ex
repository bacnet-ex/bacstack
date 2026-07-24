defmodule BACnet.Protocol.FaultParameters do
  @moduledoc """
  BACnet fault parameters configure the conditions under which an object
  should report a FAULT event state (as opposed to NORMAL or OFFNORMAL).

  Fault algorithms are separate from event algorithms. While event algorithms
  detect alarm conditions, fault algorithms detect problems with the reliability
  of the input data or the object itself (e.g. sensor failure, out-of-range
  values that indicate hardware problems, etc.).

  This module provides encoding and parsing for all supported fault parameter
  types. The individual modules under this namespace contain the fields for
  each specific fault detection algorithm.

  ### Examples

  ```elixir
  # Fault out of range (common)
  iex> %FaultParameters.OutOfRange{
  ...>   min_normal_value: 0.0,
  ...>   max_normal_value: 100.0
  ...> }

  # Fault extended (vendor specific)
  iex> %FaultParameters.Extended{
  ...>   vendor_id: 42,
  ...>   extended_fault_type: 1,
  ...>   parameters: []
  ...> }
  ```
  """

  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.FaultParameters.FaultCharacterString
  alias BACnet.Protocol.FaultParameters.FaultExtended
  alias BACnet.Protocol.FaultParameters.FaultLifeSafety
  alias BACnet.Protocol.FaultParameters.FaultState
  alias BACnet.Protocol.FaultParameters.FaultStatusFlags
  alias BACnet.Protocol.FaultParameters.None
  alias BACnet.Protocol.PropertyState

  @typedoc """
  Possible BACnet fault parameters.
  """
  @type fault_parameter ::
          None.t()
          | FaultCharacterString.t()
          | FaultExtended.t()
          | FaultLifeSafety.t()
          | FaultState.t()
          | FaultStatusFlags.t()

  @doc """
  Encodes a fault parameter variant into BACnet application tag encoding.

  Used when configuring objects that support fault detection or when building
  event enrollment records that include fault parameters.
  """
  @spec encode(fault_parameter(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding()} | {:error, term()}
  def encode(fault_params, opts \\ [])

  def encode(%None{} = _params, _opts) do
    {:ok, {:constructed, {0, {:null, nil}, 0}}}
  end

  def encode(%FaultCharacterString{} = params, _opts) do
    with true <-
           is_list(params.fault_values) and
             Enum.all?(params.fault_values, &(is_binary(&1) and String.valid?(&1))),
         favalues when is_list(favalues) <-
           Enum.map(params.fault_values, &{:character_string, &1}) do
      {:ok,
       {:constructed,
        {1,
         [
           constructed: {0, favalues, 0}
         ], 0}}}
    else
      false ->
        {:error, :invalid_params}
        # {:error, _err} = err -> err
    end
  end

  def encode(%FaultExtended{} = params, opts) do
    with true <-
           is_integer(params.vendor_id) and params.vendor_id >= 0 and params.vendor_id <= 65_535,
         true <- is_integer(params.extended_fault_type) and params.extended_fault_type >= 0,
         {:ok, vendor_id, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.vendor_id}, opts),
         {:ok, extended_fault_type, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, params.extended_fault_type}, opts) do
      {:ok,
       {:constructed,
        {2,
         [
           tagged: {0, vendor_id, byte_size(vendor_id)},
           tagged: {1, extended_fault_type, byte_size(extended_fault_type)},
           constructed: {2, params.parameters, 0}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%FaultLifeSafety{} = params, opts) do
    with true <- is_struct(params.mode, DeviceObjectPropertyRef),
         true <- is_list(params.fault_values) and Enum.all?(params.fault_values, &is_atom/1),
         {:ok, fault_values} <-
           Enum.reduce_while(params.fault_values, {:ok, []}, fn enum, {:ok, acc} ->
             case Constants.by_name(:life_safety_state, enum) do
               {:ok, val} -> {:cont, {:ok, [{:enumerated, val} | acc]}}
               :error -> {:halt, {:error, {:unknown_life_safety_fault_value, enum}}}
             end
           end),
         {:ok, mode} <- DeviceObjectPropertyRef.encode(params.mode, opts) do
      {:ok,
       {:constructed,
        {3,
         [
           constructed: {0, fault_values, 0},
           constructed: {1, mode, 0}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%FaultState{} = params, _opts) do
    with true <-
           is_list(params.fault_values) and
             Enum.all?(params.fault_values, &is_struct(&1, PropertyState)),
         {:ok, fault_values} <-
           Enum.reduce_while(params.fault_values, {:ok, []}, fn enum, {:ok, acc} ->
             case PropertyState.encode(enum) do
               {:ok, [val]} -> {:cont, {:ok, [val | acc]}}
               {:error, _err} = err -> {:halt, {:error, err}}
             end
           end) do
      {:ok,
       {:constructed,
        {4,
         [
           constructed: {0, Enum.reverse(fault_values), 0}
         ], 0}}}
    else
      false -> {:error, :invalid_params}
      {:error, _err} = err -> err
    end
  end

  def encode(%FaultStatusFlags{} = params, opts) do
    with true <- is_struct(params.status_flags, DeviceObjectPropertyRef),
         {:ok, flags} <- DeviceObjectPropertyRef.encode(params.status_flags, opts) do
      {:ok,
       {:constructed,
        {5,
         [
           constructed: {0, flags, 0}
         ], 0}}}
    end
  end

  @doc """
  Parses a constructed application tag into the corresponding fault parameter
  struct. The inverse of `encode/2`.
  """
  @spec parse(binary()) :: {:ok, fault_parameter()} | {:error, term()}
  def parse(fault_values_tag)

  # 0 = None
  def parse({:constructed, {0, fault_values_tags, 0}}) do
    case List.wrap(fault_values_tags) do
      [{:null, nil}] -> {:ok, %None{}}
      _term -> {:error, :invalid_fault_values}
    end
  end

  # 0 = None
  def parse({:tagged, {0, "", 0}}) do
    {:ok, %None{}}
  end

  # 1 = Fault Character String
  def parse({:constructed, {1, fault_values_tags, 0}}) do
    case List.wrap(fault_values_tags) do
      [
        constructed: {0, strings, _length2}
      ]
      when is_list(strings) ->
        new_strings =
          Enum.reduce_while(strings, [], fn
            {:character_string, str}, acc -> {:cont, [str | acc]}
            _other, _acc -> {:halt, {:error, :invalid_fault_values}}
          end)

        case new_strings do
          favalues when is_list(favalues) ->
            fault = %FaultCharacterString{
              fault_values: Enum.reverse(new_strings)
            }

            {:ok, fault}

          {:error, _err} = err ->
            err
        end

      _term ->
        {:error, :invalid_fault_values}
    end
  end

  # 2 = Extended
  def parse({:constructed, {2, fault_values_tags, 0}}) do
    case List.wrap(fault_values_tags) do
      [
        tagged: {0, vendor_id_raw, _length},
        tagged: {1, ext_fault_raw, _length2},
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
             {:ok, {:unsigned_integer, ext_fault}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, ext_fault_raw) do
          fault = %FaultExtended{
            vendor_id: vendor_id,
            extended_fault_type: ext_fault,
            parameters: parameters
          }

          {:ok, fault}
        else
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_fault_values}
    end
  end

  # 3 = Fault Life Safety
  def parse({:constructed, {3, fault_values_tags, 0}}) do
    case List.wrap(fault_values_tags) do
      [
        constructed: {0, fault_values_raw, _length3},
        constructed: {1, mode_raw, _length4}
      ] ->
        with {:ok, fault_values} <-
               Enum.reduce_while(fault_values_raw, {:ok, []}, fn pack, {:ok, acc} ->
                 case ApplicationTags.unfold_to_type(:enumerated, pack) do
                   {:ok, {:enumerated, value}} ->
                     with {:ok, value_c} <-
                            Constants.by_value_with_reason(
                              :life_safety_state,
                              value,
                              {:unknown_life_safety_fault_value, value}
                            ) do
                       {:cont, {:ok, [value_c | acc]}}
                     end

                   term ->
                     {:halt, term}
                 end
               end),
             {:ok, {mode, _tags}} <- DeviceObjectPropertyRef.parse(mode_raw) do
          fault = %FaultLifeSafety{
            mode: mode,
            fault_values: Enum.reverse(fault_values)
          }

          {:ok, fault}
        else
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_fault_values}
    end
  end

  # 4 = Fault State
  def parse({:constructed, {4, fault_values_tags, 0}}) do
    case List.wrap(fault_values_tags) do
      [
        constructed: {0, seq_propstates, _length2}
      ] ->
        case Enum.reduce_while(seq_propstates, {:ok, []}, fn
               term, acc ->
                 case BACnet.Protocol.PropertyState.parse(List.wrap(term)) do
                   {:ok, {state, _rest}} -> {:ok, [state | acc]}
                   _term -> {:halt, {:error, :invalid_fault_values_parameter}}
                 end
             end) do
          {:ok, fault_values} ->
            fault = %FaultState{
              fault_values: Enum.reverse(fault_values)
            }

            {:ok, fault}

          {:error, _err} = err ->
            err
        end

      _term ->
        {:error, :invalid_fault_values}
    end
  end

  # 5 = Fault Status Flags
  def parse({:constructed, {5, fault_values_tags, 0}}) do
    case List.wrap(fault_values_tags) do
      [
        constructed: {0, status_flags_ref_raw, _length2}
      ] ->
        case DeviceObjectPropertyRef.parse(status_flags_ref_raw) do
          {:ok, {status_flags_ref, _tags}} ->
            fault = %FaultStatusFlags{
              status_flags: status_flags_ref
            }

            {:ok, fault}

          {:error, _err} = err ->
            err
        end

      _term ->
        {:error, :invalid_fault_values}
    end
  end

  def parse(_fault_values_tag) do
    {:error, :invalid_tag}
  end

  @doc """
  Validates whether the given fault parameter is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(fault_parameter()) :: boolean()
  def valid?(t)

  for module <- [
        FaultCharacterString,
        FaultExtended,
        FaultLifeSafety,
        FaultState,
        FaultStatusFlags,
        None
      ] do
    var = Macro.var(:t, __MODULE__)

    def valid?(%unquote(module){} = unquote(var)) do
      unquote(BACnet.BeamTypes.generate_valid_clause(module, __ENV__))
    end
  end
end
