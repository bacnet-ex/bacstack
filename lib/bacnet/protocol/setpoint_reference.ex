defmodule BACnet.Protocol.SetpointReference do
  @moduledoc """
  A Setpoint Reference is a nullable pointer to another property that should be
  treated as the setpoint for a control loop object (Loop, Analog Output, etc.).

  When the reference is present, the control algorithm is expected to treat the
  value of the referenced property as its current setpoint rather than using a
  locally configured setpoint. This indirection is extremely useful in cascaded
  control strategies, in demand-limiting applications, and anywhere the desired
  setpoint is computed or selected by some other object in the system.

  The reference uses the common Object Property Reference type so that it can
  point at properties in the same device or, when the full Device + Object form
  is used, at properties in other devices.

  ### Examples (Doc Test)

  ```elixir
  iex> ref = %SetpointReference{
  ...>   ref: %ObjectPropertyRef{
  ...>     object_identifier: %ObjectIdentifier{type: :analog_value, instance: 5},
  ...>     property_identifier: :present_value,
  ...>     property_array_index: nil
  ...>   }
  ...> }
  iex> ref.ref.property_identifier
  :present_value
  ```
  """

  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ObjectPropertyRef

  import BACnet.Protocol.Utility, only: [pattern_extract_tags: 4]

  @typedoc """
  Optionally references another property to be used as the setpoint for a control loop.
  """
  @type t :: %__MODULE__{
          ref: ObjectPropertyRef.t() | nil
        }

  @fields [
    :ref
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnet setpoint reference into application tags encoding.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = setpoint, opts \\ []) do
    if setpoint.ref do
      with {:ok, ref} <- ObjectPropertyRef.encode(setpoint.ref, opts) do
        {:ok, [constructed: {0, ref, 0}]}
      end
    else
      {:ok, []}
    end
  end

  @doc """
  Parses a BACnet setpoint reference from application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}} | {:error, term()}
  def parse(tags) when is_list(tags) do
    with {:ok, {:constructed, {0, ref_raw, _len}}, rest} when ref_raw != [] <-
           pattern_extract_tags(tags, {:constructed, {0, _t, _l}}, nil, true),
         {:ok, {ref, _rest}} <- ObjectPropertyRef.parse(List.wrap(ref_raw)) do
      setp = %__MODULE__{
        ref: ref
      }

      {:ok, {setp, rest}}
    else
      {:ok, {:constructed, {0, _raw, _len}}, rest} -> {:ok, {%__MODULE__{ref: nil}, rest}}
      {:ok, nil, rest} -> {:ok, {%__MODULE__{ref: nil}, rest}}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Validates whether the given setpoint reference is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(t)

  def valid?(
        %__MODULE__{
          ref: %ObjectPropertyRef{} = ref
        } = _t
      ) do
    ObjectPropertyRef.valid?(ref)
  end

  def valid?(%__MODULE__{ref: nil} = _t), do: true
  def valid?(%__MODULE__{} = _t), do: false
end
