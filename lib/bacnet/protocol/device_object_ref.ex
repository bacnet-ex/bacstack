defmodule BACnet.Protocol.DeviceObjectRef do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ObjectIdentifier

  import BACnet.Protocol.Utility, only: [pattern_extract_tags: 4]

  @type t :: %__MODULE__{
          device_identifier: ObjectIdentifier.t() | nil,
          object_identifier: ObjectIdentifier.t()
        }

  @fields [
    :device_identifier,
    :object_identifier
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnet device object reference into application tags encoding.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = ref, opts \\ []) do
    with {:ok, devident, _header} <-
           (if ref.device_identifier do
              ApplicationTags.encode_value({:object_identifier, ref.device_identifier}, opts)
            else
              {:ok, nil, nil}
            end),
         {:ok, objident, _header} <-
           ApplicationTags.encode_value({:object_identifier, ref.object_identifier}, opts) do
      base = [
        tagged: {0, devident, byte_size(devident || <<>>)},
        tagged: {1, objident, byte_size(objident)}
      ]

      {:ok, Enum.filter(base, fn {_type, {_t, con, _l}} -> con end)}
    else
      {:error, _err} = err -> err
    end
  end

  @doc """
  Parses a BACnet device object reference into a struct.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}} | {:error, term()}
  def parse(tags) when is_list(tags) do
    with {:ok, device_identifier, ref} <-
           pattern_extract_tags(tags, {:tagged, {0, _t, _l}}, :object_identifier, true),
         {:ok, object_identifier, rest} <-
           pattern_extract_tags(ref, {:tagged, {1, _t, _l}}, :object_identifier, false) do
      objref = %__MODULE__{
        device_identifier: device_identifier,
        object_identifier: object_identifier
      }

      {:ok, {objref, rest}}
    else
      {:error, :missing_pattern} -> {:error, :invalid_tags}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Validates whether the given device object reference is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          object_identifier: %ObjectIdentifier{} = obj_ref,
          device_identifier: dev_ref
        } = _t
      ) do
    ObjectIdentifier.valid?(obj_ref) and
      (is_nil(dev_ref) or
         (is_struct(dev_ref, ObjectIdentifier) and ObjectIdentifier.valid?(dev_ref) and
            dev_ref.type == :device))
  end

  def valid?(%__MODULE__{} = _t), do: false
end
