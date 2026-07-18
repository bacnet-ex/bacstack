defmodule BACnet.Protocol.ObjectIdentifier do
  @moduledoc """
  A BACnet Object Identifier (application tag 12) is the universal handle by which
  every object in every BACnet device is named and addressed. It is a 32-bit packed
  value defined as:

  ```
  Bit 31 ...................... 22 21 ............................. 0
  +-------------------------------+----------------------------------+
  |      10-bit Object Type       |      22-bit Instance Number      |
  +-------------------------------+----------------------------------+
  ```

  The 10-bit type field identifies the object class (`:analog_input`, `:device`,
  `:schedule`, vendor-proprietary types, …). The 22-bit instance number must be
  unique for that type inside the device (0 … 4_194_302). The combination
  (type, instance) is the primary key for every object in the protocol.

  Object identifiers appear in almost every service, in subscription lists, in
  trend-log records, in alarm & event notifications, and as the value of the
  mandatory `Object_Identifier` property on every object.

  ### BACnet Specification References

  - **Encoding** (Clause 20.2.14): Primitive, four contents octets. The 10-bit
    type occupies the high bits; the 22-bit instance the low bits. The encoding
    is big-endian within the 32-bit word.
  - **ASN.1** (Clause 21):
    `BACnetObjectIdentifier ::= [APPLICATION 12] BIT STRING { ... }` (the
    production also references the `BACnetObjectType` enumeration).
  - **Constraints**: Instance numbers 0 and 4_194_302 are reserved in some
    contexts; the library accepts the full 0 … `max_instance_and_property_id`
    range.
  - **Uniqueness**: The (type, instance) pair **shall** be unique within a device
    (Clause 12 introduction and many object-type clauses).

  This module provides the canonical `from_number/1` / `to_number/1` round-trips
  plus the usual `encode`/`parse`/`valid?` helpers used by `BACnet.Protocol.ApplicationTags`.

  ### Examples

  #### Creating and using an Object Identifier

  ```elixir
  iex> device = %ObjectIdentifier{type: :device, instance: 1234}
  iex> ObjectIdentifier.to_number(device)
  33555666
  iex> ObjectIdentifier.from_number(33555666)
  {:ok, %ObjectIdentifier{type: :device, instance: 1234}}
  ```

  #### Validation

  ```elixir
  iex> ObjectIdentifier.valid?(%ObjectIdentifier{type: :device, instance: 4_194_304})
  false
  ```

  #### Edge cases

  Instance numbers are limited to 22 bits:

  ```elixir
  iex> max = %ObjectIdentifier{type: :device, instance: 0x3FFFFF}
  iex> ObjectIdentifier.valid?(max)
  true
  iex> too_big = %ObjectIdentifier{type: :device, instance: 0x400000}
  iex> ObjectIdentifier.valid?(too_big)
  false
  ```

  Unknown object types (as integers) are allowed for forward compatibility but are not very useful:

  ```elixir
  iex> unknown = %ObjectIdentifier{type: 999, instance: 1}
  iex> ObjectIdentifier.valid?(unknown)
  true
  ```

  ### See Also
  - `BACnet.Protocol.ApplicationTags`
  - `BACnet.Protocol.Constants` (object_type enumeration)
  - `BACnet.Protocol.DeviceObjectRef`
  - `BACnet.Protocol.ObjectPropertyRef`
  - `BACnet.Protocol.DeviceObjectPropertyRef`
  """

  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants

  require Constants

  @typedoc """
  Uniquely identifies a BACnet object within a device.

  - `type`     - a `Constants.object_type()` atom (or vendor extension integer)
  - `instance` - 0 … 4_194_301 (22 bits)

  The 32-bit wire representation is produced by `to_number/1` and parsed by
  `from_number/1` (see Clause 20.2.14 for the exact bit packing).
  """
  @type t :: %__MODULE__{
          type: Constants.object_type() | non_neg_integer(),
          instance: non_neg_integer()
        }

  @fields [
    :type,
    :instance
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes an object identifier into application tags encoding.
  """
  @spec encode(t(), Keyword.t()) :: {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = id, _opts \\ []) do
    {:ok, [{:object_identifier, id}]}
  end

  @doc """
  Parses the number and retrieves the object identifier from an object identifier number.

  The object identifier number is a 32bit non-negative integer
  which consists of a 10bit object type number and 22bit instance number.
  """
  @spec from_number(non_neg_integer()) :: {:ok, t()} | {:error, term()}
  def from_number(number) when is_integer(number) and number >= 0 do
    ApplicationTags.decode_value(
      Constants.macro_by_name(:application_tag, :object_identifier),
      <<number::size(32)>>
    )
  end

  @doc """
  Parses an object identifier from application tags encoding.

  There's actually nothing special that needs to be done here, it just unwraps
  and gets the `{:object_identifier, t()}` tuple from the head of the tags list.
  The conversion is already handled by `BACnet.Protocol.ApplicationTags`.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}} | {:error, term()}
  def parse(tags) when is_list(tags) do
    case tags do
      [{:object_identifier, %__MODULE__{} = id} | rest] -> {:ok, {id, rest}}
      _else -> {:error, :invalid_tags}
    end
  end

  @doc """
  Converts the struct into an object identifier number.

  The object identifier number is a 32bit non-negative integer
  which consists of a 10bit object type number and 22bit instance number.
  """
  @spec to_number(t()) :: non_neg_integer()
  def to_number(%__MODULE__{} = t) do
    Bitwise.bor(Bitwise.bsl(Constants.by_name!(:object_type, t.type), 22), t.instance)
  end

  @doc """
  Validates whether the given object identifier is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{} = t) do
    ((is_integer(t.type) and t.type >= 0 and
        t.type <= Constants.macro_by_name(:asn1, :max_object_type)) or
       Constants.has_by_name(:object_type, t.type)) and
      is_integer(t.instance) and t.instance >= 0 and
      t.instance <= Constants.macro_by_name(:asn1, :max_instance_and_property_id)
  end
end
