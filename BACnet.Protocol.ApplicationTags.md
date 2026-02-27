# `BACnet.Protocol.ApplicationTags`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/application_tags.ex#L1)

This module provides application tags encoding and decoding as per ASHRAE 135 chapter 20.2, including constructed tags.

32bit floats (IEEE 754 single precision floating point numbers) will be truncated to the first non-repeating digit
when decoding those. Due to (single) precision issues, some floats will be rounded to the nearest single precision
floating point number representation, such as `0.3` -> `0.3000000004` or `6.9` -> `6.900000095367432`.
By default, if more than 3 consecutive numbers are the same, the float will be truncated to the first non-repeating,
such as `6.914000045` -> `6.914`.
This behaviour can be configured at compile-time using the application environment `:bacstack`.
Set `:app_tags_truncate_float32` to `false` to disable this behaviour entirely. To configure the precision (or minimum
number of consecutive repeating numbers), configure `:app_tags_truncate_float32_precision` (defaults to `4`).
IEEE 754 double precision floating point numbers (64bit floats) are entirely unaffected by this behaviour.

> #### Information {: .info}
>
> The following information is quite low-level and is only intended for reference. Knowledge of the BACnet protocol is
> required to use this module. Dealing with application tags is not required when using abstractions on top of
> of the APDU layer, such as most of the `Services.*` modules.

BACnet tags are encoded in an initial byte and zero or more conditional subsequent bytes. The initial byte is defined as
follows:
```
Bit Number:
    7     6     5     4     3     2     1     0
|-----|------|-----|-----|-----|-----|-----|-----|
|       Tag Number       |Class|Length/Value/Type|
|-----|------|-----|-----|-----|-----|-----|-----|
```
where Tag Number = the tag number within the class

Class = the class of tag (application or context specific)

Length/Value/Type = whether the data following the tag is primitive or constructed and specifies the length
or value of primitive data.

Tag numbers ranging from 0 to 14 are encoded in the initial byte. Tag numbers from 15 to 254 (255 is reserved by ASHRAE) are encoded
by setting the tag number bits to `0b1111` and the tag number extension byte in the subsequent byte to the initial byte denotes the actual tag number.

The Length/Value/Type bits are used to distinguish between primitive and constructed data. The Length/Value/Type bits are defined as follows:
  - if the application tag denotes a boolean, then the boolean value is encoded in the Length/Value/Type bits
  - if the data is primitive and not constructed, the Length/Value/Type bits denote the length, length from 0-4 are encoded in those bits, for
    length from 5 to 253 the bits are set to `0b101` and the subsequent byte denotes the length from 0-253, for
    length from 254 to 65535 the bits are set to `0b101`, the subsequent byte is set to 254 and the following two bytes denotes the length from 0-65535, for
    length from 65536 to 2^32-1 the bits are set to `0b101`, the subsequent byte is set to 255 and the following four bytes denotes the length from 0-2^32-1
  - if the data is constructed, the Length/Value/Type bits are set to `0b110` to declare an opening tag, the tags follow in complete application tags encoding,
    and the closing tag is encoded with the same tag number and class as the opening tag and the Length/Value/Type bits are set to `0b111` to declare a closing tag

Constructed data contains zero or more tagged elements. Each tagged element may be a constructed element iself, this does not result in ambiguous encoding.

The following table shows application tags:

| Tag Number | Datatype           | Respective Elixir decoding (unwrapped)                   |
|------------|--------------------|----------------------------------------------------------|
| 0          | Null               | `nil`                                                    |
| 1          | Boolean            | `boolean()`                                              |
| 2          | Unsigned Integer   | `non_neg_integer()`                                      |
| 3          | Signed Integer     | `integer()`                                              |
| 4          | Real               | `float()`                                                |
| 5          | Double             | `float()`                                                |
| 6          | Octet String       | `binary()`                                               |
| 7          | Character String   | `String.t()`                                             |
| 8          | Bitstring          | `tuple()`, each element is a `boolean()` (left to right) |
| 9          | Enumerated         | `non_neg_integer()`                                      |
| 10         | Date               | `BACnetDate.t()`                                         |
| 11         | Time               | `BACnetTime.t()`                                         |
| 12         | Object Identifier  | `ObjectIdentifier.t()`                                   |
| 13-15      | Reserved by ASHRAE |                                                          |

For common application tags, you will receive decoding results such as:
```elixir
{:enumerated, 3}
{:object_identifier, %ObjectIdentifier{
  instance: 111,
  type: :device
}}
{:unsigned_integer, 50}
```

Context-specific tags contain context-specific data, which are not denoted directly by an application tag.
As such the data cannot be directly decoded to the correct datatype, but the application must direct the datatype to correctly decode the data.
As such the following result is not uncommon:
```elixir
{:tagged, {1, <<2, 15, 226, 104>>, 4}}
```

The `:tagged` atom denotes a context-specific tag encoding and contains the bytes that were given along with the tag encoding (in this case 4 bytes).
However due to the context and the correct datatype being unknown, the bytes couldn't be directly decoded to a particular datatype.

Constructed data may contain primitive or context-specific tags, as such both results are to be expected:
```elixir
{:constructed, {1, {:octet_string, <<11, 22>>}, 0}}
{:constructed, {3, {:tagged, {0, <<2, 12, 49, 0>>, 4}}, 0}}
```

Or even nested constructed data:
```elixir
{:constructed, {12,
     {:constructed, {6,
       [
         tagged: {0, "U", 1},
         constructed: {2, {:real, 1.0}, 0}
       ], 0}}, 0}}
```

The above snippet contains a tagged and constructed element. The tagged contains a binary with length 1 and the constructed contains a real with value 1.0.
In case of the constructed element, the value was decoded, as the datatype is known. In case of the tagged element, the datatype is unknown and as such
knowledge of the BACnet protocol and the context the element is from needs to be known.

If that is known, the function `unfold_to_type/2` can be used to produce a primitive value by specifying the correct datatype as an atom.
```elixir
ApplicationTags.unfold_to_type(:unsigned_integer, {:tagged, {0, "U", 1}})
```

Constructed data can also be a list of values, for example when dealing with Priority Arrays:
```elixir
{:constructed, {3,
  [
      null: nil,
      null: nil,
      null: nil,
      null: nil,
      null: nil,
      null: nil,
      null: nil,
      null: nil,
      null: nil,
      null: nil,
      null: nil,
      null: nil,
      null: nil,
      null: nil,
      null: nil,
      null: nil
  ], 0}}
```

# `elixir_datetime`

```elixir
@type elixir_datetime() :: {:date, Date.t()} | {:time, Time.t()}
```

When encoding date or time values, the Elixir integrated `Date` and `Time` datatypes can be used aswell.

# `encoding`

```elixir
@type encoding() ::
  primitive_encoding()
  | {:constructed,
     {tag_number :: byte(), value :: encoding() | [encoding()], 0}}
  | {:tagged,
     {tag_number :: byte(), value :: binary(), length :: non_neg_integer()}}
```

Represents a BACnet application tags encoding for primitive, tagged and constructed data.

# `encoding_list`

```elixir
@type encoding_list() :: [encoding()]
```

Linked list of BACnet application tag encoding.

# `ieee_float`

```elixir
@type ieee_float() :: float() | :NaN | :inf | :infn
```

Represents sort of IEEE 754 floats, including NaN and infinity using atoms.

# `primitive_encoding`

```elixir
@type primitive_encoding() ::
  {:null, nil}
  | {:boolean, boolean()}
  | {:unsigned_integer, non_neg_integer()}
  | {:signed_integer, integer()}
  | {:real, ieee_float()}
  | {:double, ieee_float()}
  | {:octet_string, binary()}
  | {:character_string, String.t()}
  | {:bitstring, tuple()}
  | {:enumerated, pos_integer()}
  | {:date, BACnet.Protocol.BACnetDate.t()}
  | {:time, BACnet.Protocol.BACnetTime.t()}
  | {:object_identifier, BACnet.Protocol.ObjectIdentifier.t()}
```

Represents the BACnet application tags encoding for primitive data.

# `primitive_type`

```elixir
@type primitive_type() ::
  :null
  | :boolean
  | :unsigned_integer
  | :signed_integer
  | :real
  | :double
  | :octet_string
  | :character_string
  | :bitstring
  | :enumerated
  | :date
  | :time
  | :object_identifier
```

BACnet application tag primitive types.

This is identical to `t:BACnet.Protocol.Constants.application_tag/0`.

# `signed8`

```elixir
@type signed8() :: -128..127
```

Represents an `integer()` with a limited 8-bit number range.

# `signed16`

```elixir
@type signed16() :: -32768..32767
```

Represents an `integer()` with a limited 16-bit number range.

# `signed32`

```elixir
@type signed32() :: -2_147_483_648..2_147_483_647
```

Represents an `integer()` with a limited 32-bit number range.

# `signed64`

```elixir
@type signed64() :: -9_223_372_036_854_775_808..9_223_372_036_854_775_807
```

Represents an `integer()` with a limited 64-bit number range.

# `unsigned8`

```elixir
@type unsigned8() :: 0..255
```

Represents a `non_neg_integer()` with a limited 8-bit number range.

# `unsigned16`

```elixir
@type unsigned16() :: 0..65535
```

Represents a `non_neg_integer()` with a limited 16-bit number range.

# `unsigned32`

```elixir
@type unsigned32() :: 0..4_294_967_295
```

Represents a `non_neg_integer()` with a limited 32-bit number range.

# `unsigned64`

```elixir
@type unsigned64() :: 0..18_446_744_073_709_551_615
```

Represents a `non_neg_integer()` with a limited 64-bit number range.

# `create_tag_encoding`

```elixir
@spec create_tag_encoding(integer(), primitive_encoding()) ::
  {:ok, encoding()} | {:error, term()}
```

Helper function to create `{:tagged, ...}` tag encodings.

# `create_tag_encoding`

```elixir
@spec create_tag_encoding(integer(), primitive_type(), term()) ::
  {:ok, encoding()} | {:error, term()}
```

Helper function to create `{:tagged, ...}` tag encodings.

# `decode`

```elixir
@spec decode(binary()) :: {:ok, encoding(), rest :: binary()} | {:error, term()}
```

Decode the application tag.

# `decode_tag_number`

```elixir
@spec decode_tag_number(binary()) ::
  {:ok, {:extended | :normal, tag :: byte()}, rest :: binary()}
  | {:error, term()}
```

Decode the tag number from the application tags encoding.

# `decode_value`

```elixir
@spec decode_value(byte(), binary()) :: {:ok, term()} | {:error, term()}
```

Decode the value from the application tags encoding.

# `encode`

```elixir
@spec encode(encoding() | elixir_datetime(), Keyword.t()) ::
  {:ok, binary()} | {:error, term()}
```

Encode the application tag.

Available options:
- `encoding: :utf8 | :iso_8859_1` - Optional. The target encoding for character strings (defaults to `:utf8`).

# `encode_value`

```elixir
@spec encode_value(encoding() | elixir_datetime(), Keyword.t()) ::
  {:ok, value :: binary(),
   {application_tag :: bitstring(), context :: 0 | 1, length :: bitstring()}}
  | {:error, term()}
```

Encode the application tag value, without the tag header in the resulting binary.

Constructed tags are not supported, as the format is complex. Constructed tags must be encoded through `encode/2`.

For available options, see `encode/2`.

# `unfold_to_type`

```elixir
@spec unfold_to_type(primitive_type(), encoding() | binary()) ::
  {:ok, primitive_encoding()} | {:error, term()}
```

Tries to unfold a value into a specific primitive value. The requested primitive type is given through `format`.

Since the BACnet encoding may be a primitive value, a constructed value or a context-specific tagged value,
this function tries to take all three forms into considering and tries to produce a primitive value.

# `valid_int?`

```elixir
@spec valid_int?(integer(), 8 | 16 | 24 | 32 | 40 | 48 | 56 | 64) :: boolean()
```

Checks whether the given integer fits into the given integer size in bits.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
