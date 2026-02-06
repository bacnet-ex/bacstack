defmodule BACnet.Protocol.FaultParameters do
  @moduledoc """
  BACnet has various different types of fault parameters.
  Each of them is represented by a different module.

  Consult the module `BACnet.Protocol.FaultAlgorithms` for
  details about each fault's algorithm.
  """

  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef

  @typedoc """
  Possible BACnet fault parameters.
  """
  @type fault_parameter ::
          __MODULE__.None.t()
          | __MODULE__.FaultCharacterString.t()
          | __MODULE__.FaultExtended.t()
          | __MODULE__.FaultLifeSafety.t()
          | __MODULE__.FaultState.t()
          | __MODULE__.FaultStatusFlags.t()

  defmodule None do
    @moduledoc """
    Represents the BACnet fault algorithm `None` parameters.

    The NONE fault algorithm is a placeholder for the case where no fault algorithm is applied by the object.
    This fault algorithm has no parameters, no conditions, and does not indicate any transitions of reliability.

    For more specific information about the fault algorithm, consult ASHRAE 135 13.4.1.
    """

    @typedoc """
    Representative type for the fault parameter.
    """
    @type t :: %__MODULE__{}

    defstruct []

    @doc false
    def get_tag_number(), do: 0
  end

  defmodule FaultCharacterString do
    @moduledoc """
    Represents the BACnet fault algorithm `FaultCharacterString` parameters.

    The FAULT_CHRACTERSTRING fault algorithm detects whether the monitored value matches a
    character string that is listed as a fault value. Fault values are of type
    BACnetOptionalCharacterString and may also be NULL or an empty character string.

    For more specific information about the fault algorithm, consult ASHRAE 135 13.4.2.
    """

    use TypedStruct

    @typedoc """
    Representative type for the fault parameter.
    """
    typedstruct do
      field :fault_values, [String.t()], enforce: true
    end

    @doc false
    def get_tag_number(), do: 1
  end

  defmodule FaultExtended do
    @moduledoc """
    Represents the BACnet fault algorithm `FaultExtended` parameters.

    The FAULT_EXTENDED fault algorithm detects fault conditions based on a
    proprietary fault algorithm. The proprietary fault algorithm uses parameters
    and conditions defined by the vendor. The algorithm is identified by a
    vendor-specific fault type that is in the scope of the vendor's
    vendor identification code. The algorithm may, at the vendor's discretion,
    indicate a new reliability, a transition to the same reliability, or
    no transition to the reliability-evaluation process.

    For more specific information about the fault algorithm, consult ASHRAE 135 13.4.3.
    """

    use TypedStruct

    @typedoc """
    Representative type for the fault parameter.
    """
    typedstruct do
      field :vendor_id, BACnet.Protocol.ApplicationTags.unsigned16(), enforce: true
      field :extended_fault_type, non_neg_integer(), enforce: true
      field :parameters, BACnet.Protocol.ApplicationTags.encoding_list(), enforce: true
    end

    @doc false
    def get_tag_number(), do: 2
  end

  defmodule FaultLifeSafety do
    @moduledoc """
    Represents the BACnet fault algorithm `FaultLifeSafety` parameters.

    The FAULT_LIFE_SAFETY fault algorithm detects whether the monitored value equals
    a value that is listed as a fault value.
    The monitored value is of type BACnetLifeSafetyState. If internal operational
    reliability is unreliable, then the internal reliability takes precedence over
    evaluation of the monitored value.

    In addition, this algorithm monitors a life safety mode value. If reliability is
    MULTI_STATE_FAULT, then new transitions to MULTI_STATE_FAULT are indicated upon
    change of the mode value.

    For more specific information about the fault algorithm, consult ASHRAE 135 13.4.4.
    """

    use TypedStruct

    @typedoc """
    Representative type for the fault parameter.
    """
    typedstruct do
      field :mode, BACnet.Protocol.DeviceObjectPropertyRef.t(), enforce: true
      field :fault_values, [BACnet.Protocol.Constants.life_safety_state()], enforce: true
    end

    @doc false
    def get_tag_number(), do: 3
  end

  defmodule FaultState do
    @moduledoc """
    Represents the BACnet fault algorithm `FaultState` parameters.

    The FAULT_STATE fault algorithm detects whether the monitored value
    equals a value that is listed as a fault value. The monitored value
    may be of any discrete or enumerated datatype, including Boolean.
    If internal operational reliability is unreliable, then the
    internal reliability takes precedence over evaluation of the monitored value.

    For more specific information about the fault algorithm, consult ASHRAE 135 13.4.5.
    """

    use TypedStruct

    @typedoc """
    Representative type for the fault parameter.
    """
    typedstruct do
      field :fault_values, [BACnet.Protocol.PropertyState.t()], enforce: true
    end

    @doc false
    def get_tag_number(), do: 4
  end

  defmodule FaultStatusFlags do
    @moduledoc """
    Represents the BACnet fault algorithm `FaultStatusFlags` parameters.

    The FAULT_STATUS_FLAGS fault algorithm detects whether the monitored
    status flags are indicating a fault condition.

    For more specific information about the fault algorithm, consult ASHRAE 135 13.4.6.
    """

    use TypedStruct

    @typedoc """
    Representative type for the fault parameter.
    """
    typedstruct do
      field :status_flags, BACnet.Protocol.DeviceObjectPropertyRef.t(), enforce: true
    end

    @doc false
    def get_tag_number(), do: 5
  end

  # TODO: Docs
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
             case Constants.by_name(:property_state, enum) do
               {:ok, val} -> {:cont, {:ok, [{:enumerated, val} | acc]}}
               :error -> {:halt, {:error, {:unknown_property_State, enum}}}
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
    with true <- is_list(params.fault_values) and Enum.all?(params.fault_values, &is_atom/1),
         {:ok, fault_values} <-
           Enum.reduce_while(params.fault_values, {:ok, []}, fn enum, {:ok, acc} ->
             case Constants.by_name(:property_state, enum) do
               {:ok, val} -> {:cont, {:ok, [{:enumerated, val} | acc]}}
               :error -> {:halt, {:error, {:unknown_property_State, enum}}}
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
    with true <- is_struct(params.status_flags, StatusFlags),
         {:ok, flags} <- DeviceObjectPropertyRef.encode(params.status_flags, opts) do
      {:ok,
       {:constructed,
        {5,
         [
           constructed: {0, flags, 0}
         ], 0}}}
    end
  end

  # TODO: Docs
  @spec parse(binary()) :: {:ok, fault_parameter()} | {:error, term()}
  def parse(fault_values_tag)

  # 0 = None
  def parse({:constructed, {0, fault_values_tags, 0}}) do
    case fault_values_tags do
      {:null, nil} -> {:ok, %None{}}
      _term -> {:error, :invalid_fault_values}
    end
  end

  # 1 = Fault Character String
  def parse({:constructed, {1, fault_values_tags, 0}}) do
    case fault_values_tags do
      [
        constructed: {0, strings, _length2}
      ] ->
        with favalues when is_list(favalues) <-
               Enum.map(strings, fn {:character_string, str} -> str end) do
          fault = %FaultCharacterString{
            fault_values: favalues
          }

          {:ok, fault}
        else
          {:error, _err} = err -> err
        end

      _term ->
        {:error, :invalid_fault_values}
    end
  end

  # 2 = Extended
  def parse({:constructed, {2, fault_values_tags, 0}}) do
    case fault_values_tags do
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
    case fault_values_tags do
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
                              :property_state,
                              value,
                              {:unknown_property_state, value}
                            ) do
                       {:cont, {:ok, [value_c | acc]}}
                     end

                   term ->
                     {:halt, term}
                 end
               end),
             {:ok, mode} <- DeviceObjectPropertyRef.parse(mode_raw) do
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
    case fault_values_tags do
      [
        constructed: {0, seq_propstates, _length2}
      ] ->
        with {:ok, fault_values} <-
               Enum.reduce_while(seq_propstates, {:ok, []}, fn
                 term, acc ->
                   case BACnet.Protocol.PropertyState.parse(List.wrap(term)) do
                     {:ok, {state, _rest}} -> {:ok, [state | acc]}
                     _term -> {:halt, {:error, :invalid_fault_values_parameter}}
                   end
               end) do
          fault = %FaultState{
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

  # 5 = Fault Status Flags
  def parse({:constructed, {5, fault_values_tags, 0}}) do
    case fault_values_tags do
      [
        constructed: {0, status_flags_ref_raw, _length2}
      ] ->
        with {:ok, status_flags_ref} <- DeviceObjectPropertyRef.parse(status_flags_ref_raw) do
          fault = %FaultStatusFlags{
            status_flags: status_flags_ref
          }

          {:ok, fault}
        else
          {:error, _err} = err -> err
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
        __MODULE__.FaultCharacterString,
        __MODULE__.FaultExtended,
        __MODULE__.FaultLifeSafety,
        __MODULE__.FaultState,
        __MODULE__.FaultStatusFlags,
        __MODULE__.None
      ] do
    var = Macro.var(:t, __MODULE__)

    def valid?(%unquote(module){} = unquote(var)) do
      unquote(BACnet.BeamTypes.generate_valid_clause(module, __ENV__))
    end
  end
end
