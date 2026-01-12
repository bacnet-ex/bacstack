defmodule BACnet.Protocol.ApplicationTags do
  @moduledoc """
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
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.Constants

  import BACnet.Internal, only: [print_compile_warning: 1]
  require Constants

  defguardp is_extended_tag_number(tag_number) when Bitwise.band(tag_number, 0xF0) == 0xF0

  defguardp is_extended_tag_value(tag_value) when Bitwise.band(tag_value, 0x07) == 0x05

  defguardp is_context_specific(tag_number) when Bitwise.band(tag_number, 0x08) == 0x08

  defguardp is_opening_tag(tag_number) when Bitwise.band(tag_number, 0x07) == 0x06

  # defguardp is_closing_tag(tag_number) when Bitwise.band(tag_number, 0x07) == 0x07

  defguardp is_valid_undef(term) when term == :unspecified or term == 255
  defguardp is_valid_undef2(term) when term == 255

  defguardp is_valid_date(year, month, day, weekday)
            when (is_valid_undef(year) or year in 0..254 or year in 1900..2154) and
                   (is_valid_undef(month) or month in [:even, :odd] or month in 1..14) and
                   (is_valid_undef(day) or day in [:even, :odd, :last] or day in 1..34) and
                   (is_valid_undef(weekday) or weekday in 1..7)

  defguardp is_valid_date2(year, month, day, weekday)
            when (is_valid_undef2(year) or year in 0..254 or year in 1900..2154) and
                   (is_valid_undef2(month) or month in [:even, :odd] or month in 1..14) and
                   (is_valid_undef2(day) or day in [:even, :odd, :last] or day in 1..34) and
                   (is_valid_undef2(weekday) or weekday in 1..7)

  defguardp is_valid_time(hour, min, sec, hundredth)
            when (is_valid_undef(hour) or hour in 0..23) and
                   (is_valid_undef(min) or min in 0..59) and
                   (is_valid_undef(sec) or sec in 0..59) and
                   (is_valid_undef(hundredth) or hundredth in 0..255)

  defguardp is_valid_time2(hour, min, sec, hundredth)
            when (is_valid_undef2(hour) or hour in 0..23) and
                   (is_valid_undef2(min) or min in 0..59) and
                   (is_valid_undef2(sec) or sec in 0..59) and
                   (is_valid_undef2(hundredth) or hundredth in 0..255)

  # Truncate float 32 if more than 3 consecutive digits are the same (i.e. 0.300000000004 -> 0.3)
  # The float will be truncated to the last non-repeating digit (i.e. 6.914000045 -> 6.914)
  # Three consecutive same digits are kept (i.e. 6.91400045 -> 6.91400045)
  @spec truncate_float32(float()) :: float()
  if Application.compile_env(:bacstack, :app_tags_truncate_float32, true) do
    @precision Application.compile_env(:bacstack, :app_tags_truncate_float32_precision, 4) - 1
    @precision_reduced @precision - 1

    defp truncate_float32(float) do
      {_dot, _last, num, offset} =
        float
        |> Float.to_charlist()
        |> Enum.reduce_while({false, nil, 0, 0}, fn
          ?., {false, last_num, _occ, _offset} ->
            {:cont, {true, last_num, 0, 0}}

          _num, {false, last_num, _occ, _offset} ->
            {:cont, {false, last_num, 0, 0}}

          num, {true, last_num, @precision_reduced, offset} when num == last_num ->
            {:halt, {true, last_num, @precision, offset + 1}}

          num, {true, last_num, occurrence, offset} when num == last_num ->
            {:cont, {true, last_num, occurrence + 1, offset + 1}}

          num, {true, _last_num, _occurrence, offset} ->
            {:cont, {true, num, 0, offset + 1}}
        end)

      if num > 0 do
        precision = offset - num - 1
        if precision > 15, do: float, else: Float.round(float, precision)
      else
        float
      end
    end
  else
    @compile {:inline, truncate_float32: 1}
    defp truncate_float32(float), do: float
  end

  @valid_primitive_types [
    :null,
    :boolean,
    :unsigned_integer,
    :signed_integer,
    :real,
    :double,
    :octet_string,
    :character_string,
    :bitstring,
    :enumerated,
    :date,
    :time,
    :object_identifier
  ]

  @typedoc """
  BACnet application tag primitive types.

  This is identical to `t:BACnet.Protocol.Constants.application_tag/0`.
  """
  @type primitive_type ::
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

  @typedoc """
  Represents the BACnet application tags encoding for primitive data.
  """
  @type primitive_encoding ::
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
          | {:date, Protocol.BACnetDate.t()}
          | {:time, Protocol.BACnetTime.t()}
          | {:object_identifier, Protocol.ObjectIdentifier.t()}

  @typedoc """
  Represents a BACnet application tags encoding for primitive, tagged and constructed data.
  """
  @type encoding ::
          primitive_encoding()
          | {:constructed, {tag_number :: byte(), value :: encoding() | [encoding()], 0}}
          | {:tagged, {tag_number :: byte(), value :: binary(), length :: non_neg_integer()}}

  @typedoc """
  Linked list of BACnet application tag encoding.
  """
  @type encoding_list :: [encoding()]

  @typedoc """
  When encoding date or time values, the Elixir integrated `Date` and `Time` datatypes can be used aswell.
  """
  @type elixir_datetime :: {:date, Date.t()} | {:time, Time.t()}

  @typedoc """
  Represents sort of IEEE 754 floats, including NaN and infinity using atoms.
  """
  @type ieee_float :: float() | :NaN | :inf | :infn

  @typedoc """
  Represents an `integer()` with a limited 8-bit number range.
  """
  @type signed8 :: -128..127

  @typedoc """
  Represents a `non_neg_integer()` with a limited 8-bit number range.
  """
  @type unsigned8 :: 0..255

  @typedoc """
  Represents an `integer()` with a limited 16-bit number range.
  """
  @type signed16 :: -32_768..32_767

  @typedoc """
  Represents a `non_neg_integer()` with a limited 16-bit number range.
  """
  @type unsigned16 :: 0..65_535

  @typedoc """
  Represents an `integer()` with a limited 32-bit number range.
  """
  @type signed32 :: -2_147_483_648..2_147_483_647

  @typedoc """
  Represents a `non_neg_integer()` with a limited 32-bit number range.
  """
  @type unsigned32 :: 0..4_294_967_295

  @typedoc """
  Represents an `integer()` with a limited 64-bit number range.
  """
  @type signed64 :: -9_223_372_036_854_775_808..9_223_372_036_854_775_807

  @typedoc """
  Represents a `non_neg_integer()` with a limited 64-bit number range.
  """
  @type unsigned64 :: 0..18_446_744_073_709_551_615

  @doc """
  Decode the application tag.
  """
  @spec decode(binary()) ::
          {:ok, encoding(), rest :: binary()}
          | {:error, term()}
  def decode(data)

  def decode(<<initial_octet::size(8), _rest::binary>> = data)
      when byte_size(data) > 1 and is_opening_tag(initial_octet) do
    # Constructed encoding
    with {:ok, {_tag_type, tag_number}, datastream} <- decode_tag_number_internal(data),
         :continue <-
           (case datastream do
              # Handle constructed encoding with zero elements (extended tag number)
              <<255::size(8), byte::size(8), rest::binary>>
              when initial_octet == 254 and byte == tag_number ->
                {:ok, {:constructed, {tag_number, [], 0}}, rest}

              # Handle constructed encoding with zero elements
              <<byte::size(8), rest::binary>> when byte - 1 == initial_octet ->
                {:ok, {:constructed, {tag_number, [], 0}}, rest}

              _else ->
                :continue
            end) do
      case decode(datastream) do
        # Extended tag number
        {:ok, encoding, <<255::size(8), byte::size(8), rest::binary>>}
        when initial_octet == 254 and byte == tag_number ->
          {:ok, {:constructed, {tag_number, encoding, 0}}, rest}

        {:ok, encoding, <<byte::size(8), rest::binary>>} when byte - 1 == initial_octet ->
          {:ok, {:constructed, {tag_number, encoding, 0}}, rest}

        {:ok, encoding, rest} ->
          res =
            Enum.reduce_while(
              1..byte_size(rest)//1,
              {:ok, {rest, [encoding]}},
              fn _index, {:ok, {rest, acc}} ->
                case decode(rest) do
                  # Extended tag number
                  {:ok, encoding, <<255::size(8), byte::size(8), rest::binary>>}
                  when initial_octet == 254 and byte == tag_number ->
                    {:halt, {:ok, {rest, [encoding | acc]}}}

                  {:ok, encoding, <<byte::size(8), rest::binary>>}
                  when byte - 1 == initial_octet ->
                    {:halt, {:ok, {rest, [encoding | acc]}}}

                  {:ok, encoding, rest} ->
                    {:cont, {:ok, {rest, [encoding | acc]}}}

                  term ->
                    {:halt, term}
                end
              end
            )

          case res do
            {:ok, {rest, result}} ->
              {:ok, {:constructed, {tag_number, Enum.reverse(result), 0}}, rest}

            term ->
              term
          end

        term ->
          term
      end
    end
  end

  def decode(<<initial_octet::size(8), _rest::binary>> = data) do
    # Primitive or tagged encoding
    with {:ok, {_tag_type, tag_number}, rest} <- decode_tag_number_internal(data),
         {:ok, length, rest} when is_integer(length) <-
           decode_tag_value_length(rest, initial_octet) do
      decode_tag_value_internal(rest, initial_octet, tag_number, length)
    else
      {:error, _err} = err -> err
    end
  end

  def decode(data) when is_binary(data) do
    {:error, :empty_data}
  end

  @doc """
  Decode the tag number from the application tags encoding.
  """
  @spec decode_tag_number(binary()) ::
          {:ok, {:extended | :normal, tag :: byte()}, rest :: binary()} | {:error, term()}
  def decode_tag_number(data) when is_binary(data) do
    decode_tag_number_internal(data)
  end

  @doc """
  Decode the value from the application tags encoding.
  """
  @spec decode_value(byte(), binary()) :: {:ok, term()} | {:error, term()}
  def decode_value(tag_number, data) do
    size = byte_size(data)

    # Trick: Prepend the size, so we can binary match the size
    decode_value_internal(tag_number, <<size::integer-size(32), data::binary>>)
  end

  @doc """
  Encode the application tag.

  Available options:
  - `encoding: :utf8 | :iso_8859_1` - Optional. The target encoding for character strings (defaults to `:utf8`).
  """
  @spec encode(encoding() | elixir_datetime(), Keyword.t()) ::
          {:ok, binary()} | {:error, term()}
  def encode(tag, opts \\ [])

  def encode({:constructed, {tag_number, value, 0}}, opts) do
    {tagnum, tagnum_extension} =
      cond do
        tag_number < 15 -> {tag_number, <<>>}
        tag_number <= 255 -> {15, <<tag_number::size(8)>>}
        true -> raise ArgumentError, "Invalid tag number, got: #{inspect(tag_number)}"
      end

    encoder =
      if is_list(value) do
        Enum.reduce_while(value, {:ok, <<>>}, fn value, {:ok, acc} ->
          case encode(value, opts) do
            {:ok, bytes} -> {:cont, {:ok, <<acc::binary, bytes::binary>>}}
            term -> {:halt, term}
          end
        end)
      else
        encode(value, opts)
      end

    case encoder do
      {:ok, bytes} ->
        {:ok,
         <<tagnum::size(4), 1::size(1), 6::size(3), tagnum_extension::binary, bytes::binary,
           tagnum::size(4), 1::size(1), 7::size(3), tagnum_extension::binary>>}

      term ->
        term
    end
  end

  def encode({:constructed, _term}, _opts) do
    {:error, :invalid_constructed_term}
  end

  def encode(value, opts) do
    case encode_value(value, opts) do
      {:ok, bytes, {tag_number, context, length}} ->
        {:ok, <<tag_number::bitstring, context::size(1), length::bitstring, bytes::bitstring>>}

      term ->
        term
    end
  end

  @doc """
  Encode the application tag value, without the tag header in the resulting binary.

  Constructed tags are not supported, as the format is complex. Constructed tags must be encoded through `encode/2`.

  For available options, see `encode/2`.
  """
  @spec encode_value(encoding() | elixir_datetime(), Keyword.t()) ::
          {:ok, value :: binary(),
           {application_tag :: bitstring(), context :: 0 | 1, length :: bitstring()}}
          | {:error, term()}
  def encode_value(tag, opts \\ [])

  def encode_value({:null, _value}, _opts) do
    {:ok, <<>>,
     {<<Constants.macro_by_name(:application_tag, :null)::size(4)>>, 0, <<0::size(3)>>}}
  end

  def encode_value({:boolean, value}, _opts) when is_boolean(value) do
    {:ok, <<intify(value)::size(3)>>,
     {
       <<Constants.macro_by_name(:application_tag, :boolean)::size(4)>>,
       0,
       <<>>
     }}
  end

  # Allow booleans for unsigned integer as context-tagged booleans are encoded this way (Clause 20.2.3)
  def encode_value({:unsigned_integer, value}, _opts) when is_boolean(value) do
    {:ok, <<intify(value)::size(1)-unit(8)>>,
     {
       <<Constants.macro_by_name(:application_tag, :unsigned_integer)::size(4)>>,
       0,
       <<1::size(3)>>
     }}
  end

  def encode_value({:unsigned_integer, value}, _opts) when is_integer(value) and value >= 0 do
    int_length = div(byte_size(Integer.to_string(value, 2)) + 7, 8)
    {len_value_type, length} = length_to_lenvaluetype(int_length)

    {:ok, <<value::size(int_length)-unit(8)>>,
     {
       <<Constants.macro_by_name(:application_tag, :unsigned_integer)::size(4)>>,
       0,
       <<len_value_type::size(3), length::binary>>
     }}
  end

  def encode_value({:signed_integer, value}, _opts) when is_integer(value) do
    int_length = div(byte_size(Integer.to_string(value, 2)) + 7, 8)
    {len_value_type, length} = length_to_lenvaluetype(int_length)

    {:ok, <<value::signed-size(int_length)-unit(8)>>,
     {
       <<Constants.macro_by_name(:application_tag, :signed_integer)::size(4)>>,
       0,
       <<len_value_type::size(3), length::binary>>
     }}
  end

  def encode_value({:real, value}, _opts) when is_float(value) do
    {:ok, <<value::float-size(32)>>,
     {
       <<Constants.macro_by_name(:application_tag, :real)::size(4)>>,
       0,
       <<4::size(3)>>
     }}
  end

  def encode_value({:real, value}, _opts) when value in [:NaN, :inf, :infn] do
    bin =
      case value do
        :NaN -> <<0::size(1), 255::size(8), 1::size(23)>>
        :inf -> <<0::size(1), 255::size(8), 0::size(23)>>
        :infn -> <<1::size(1), 255::size(8), 0::size(23)>>
      end

    {:ok, bin,
     {
       <<Constants.macro_by_name(:application_tag, :real)::size(4)>>,
       0,
       <<4::size(3)>>
     }}
  end

  def encode_value({:double, value}, _opts) when is_float(value) do
    {:ok, <<value::float-size(64)>>,
     {
       <<Constants.macro_by_name(:application_tag, :double)::size(4)>>,
       0,
       <<5::size(3), 8::size(8)>>
     }}
  end

  def encode_value({:double, value}, _opts) when value in [:NaN, :inf, :infn] do
    bin =
      case value do
        :NaN -> <<0::size(1), 2047::size(11), 1::size(52)>>
        :inf -> <<0::size(1), 2047::size(11), 0::size(52)>>
        :infn -> <<1::size(1), 2047::size(11), 0::size(52)>>
      end

    {:ok, bin,
     {
       <<Constants.macro_by_name(:application_tag, :double)::size(4)>>,
       0,
       <<5::size(3), 8::size(8)>>
     }}
  end

  def encode_value({:octet_string, value}, _opts) when is_binary(value) do
    {len_value_type, length} = length_to_lenvaluetype(byte_size(value))

    {:ok, value,
     {
       <<Constants.macro_by_name(:application_tag, :octet_string)::size(4)>>,
       0,
       <<len_value_type::size(3), length::binary>>
     }}
  end

  def encode_value({:character_string, value}, opts) when is_binary(value) do
    if String.valid?(value) do
      {encoding, return_charstr} =
        case opts[:encoding] do
          nil ->
            {Constants.macro_by_name(:character_string_encoding, :utf8), {:ok, value}}

          :utf8 ->
            {Constants.macro_by_name(:character_string_encoding, :utf8), {:ok, value}}

          :iso_8859_1 ->
            {Constants.macro_by_name(:character_string_encoding, :iso_8859_1),
             Codepagex.from_string(value, :iso_8859_1)}

          term ->
            raise ArgumentError, "Unsupported encoding, got: #{inspect(term)}"
        end

      case return_charstr do
        {:ok, charstr} ->
          # Add + 1 due to encoding byte
          {len_value_type, length} = length_to_lenvaluetype(byte_size(charstr) + 1)

          {:ok, <<encoding::size(8), charstr::binary>>,
           {
             <<Constants.macro_by_name(:application_tag, :character_string)::size(4)>>,
             0,
             <<len_value_type::size(3), length::binary>>
           }}

        term ->
          term
      end
    else
      {:error, :invalid_utf8_string}
    end
  end

  def encode_value({:bitstring, value}, _opts) when is_tuple(value) do
    list_value = Tuple.to_list(value)

    num_bits = tuple_size(value)
    max_bits = ceil(num_bits / 8) * 8
    unused_bits = max_bits - num_bits

    bits = bits_to_bitstring(list_value)

    # Add + 1 due to unused_bits byte
    {len_value_type, length} = length_to_lenvaluetype(byte_size(bits) + 1)

    {:ok, <<unused_bits::size(8), bits::bitstring, 0::size(unused_bits)>>,
     {
       <<Constants.macro_by_name(:application_tag, :bitstring)::size(4)>>,
       0,
       <<len_value_type::size(3), length::binary>>
     }}
  end

  def encode_value({:enumerated, value}, _opts) when is_integer(value) and value >= 0 do
    int_length = div(byte_size(Integer.to_string(value, 2)) + 7, 8)
    {len_value_type, length} = length_to_lenvaluetype(int_length)

    {:ok, <<value::size(int_length)-unit(8)>>,
     {
       <<Constants.macro_by_name(:application_tag, :enumerated)::size(4)>>,
       0,
       <<len_value_type::size(3), length::binary>>
     }}
  end

  def encode_value({:date, %Protocol.BACnetDate{} = value}, _opts)
      when is_valid_date(value.year, value.month, value.day, value.weekday) do
    bacyear = if value.year == :unspecified, do: 255, else: value.year - 1900

    month =
      case value.month do
        :unspecified -> 255
        :odd -> 13
        :even -> 14
        month -> month
      end

    day =
      case value.day do
        :unspecified -> 255
        :last -> 32
        :odd -> 33
        :even -> 34
        day -> day
      end

    weekday = if value.weekday == :unspecified, do: 255, else: value.weekday

    {:ok, <<bacyear::size(8), month::size(8), day::size(8), weekday::size(8)>>,
     {
       <<Constants.macro_by_name(:application_tag, :date)::size(4)>>,
       0,
       <<4::size(3)>>
     }}
  end

  def encode_value({:date, %Date{year: year, month: month, day: day} = value}, _opts)
      when is_valid_date(year, month, day, 1) do
    bacyear = year - 1900
    weekday = Date.day_of_week(value, :monday)

    {:ok, <<bacyear::size(8), month::size(8), day::size(8), weekday::size(8)>>,
     {
       <<Constants.macro_by_name(:application_tag, :date)::size(4)>>,
       0,
       <<4::size(3)>>
     }}
  end

  def encode_value({:time, %Protocol.BACnetTime{} = value}, _opts)
      when is_valid_time(value.hour, value.minute, value.second, value.hundredth) do
    hour = if value.hour == :unspecified, do: 255, else: value.hour
    minute = if value.minute == :unspecified, do: 255, else: value.minute
    second = if value.second == :unspecified, do: 255, else: value.second
    hundredth = if value.hundredth == :unspecified, do: 255, else: value.hundredth

    {:ok, <<hour::size(8), minute::size(8), second::size(8), hundredth::size(8)>>,
     {<<Constants.macro_by_name(:application_tag, :time)::size(4)>>, 0, <<4::size(3)>>}}
  end

  def encode_value({:time, %Time{hour: hour, minute: minute, second: second} = time}, _opts)
      when is_valid_time(hour, minute, second, 0) do
    hundredth =
      case time.microsecond do
        {_value, 0} -> 0
        {value, 1} -> value * 10
        {value, 2} -> value
        {value, 3} -> Integer.floor_div(value, 10)
        {value, 4} -> Integer.floor_div(value, 100)
        {value, 5} -> Integer.floor_div(value, 1000)
        {value, 6} -> Integer.floor_div(value, 10_000)
      end

    bachundredth = max(0, min(99, hundredth))

    {:ok, <<hour::size(8), minute::size(8), second::size(8), bachundredth::size(8)>>,
     {
       <<Constants.macro_by_name(:application_tag, :time)::size(4)>>,
       0,
       <<4::size(3)>>
     }}
  end

  def encode_value(
        {:object_identifier, %Protocol.ObjectIdentifier{instance: instance} = value},
        _opts
      )
      when is_integer(instance) and instance >= 0 do
    case Constants.by_name(:object_type, value.type) do
      {:ok, type} ->
        {:ok, <<type::size(10), instance::size(22)>>,
         {
           <<Constants.macro_by_name(:application_tag, :object_identifier)::size(4)>>,
           0,
           <<4::size(3)>>
         }}

      :error ->
        {:error, :unknown_object_type}
    end
  end

  def encode_value({:constructed, _term}, _opts) do
    # The constructed data is not supported as the format is complex
    {:error, :constructed_unsupported}
  end

  def encode_value({:tagged, {tag_number, bytes, tag_length}}, _opts) do
    {tagnum, tagnum_extension} =
      cond do
        tag_number < 15 -> {tag_number, <<>>}
        tag_number < 254 -> {15, <<tag_number::size(8)>>}
        true -> raise ArgumentError, "Invalid tag number, got: #{inspect(tag_number)}"
      end

    {len_value_type, length} = length_to_lenvaluetype(tag_length)

    {:ok, bytes,
     {
       <<tagnum::size(4)>>,
       1,
       <<len_value_type::size(3), tagnum_extension::binary, length::binary>>
     }}
  end

  def encode_value(_value, _opts) do
    {:error, :invalid_value}
  end

  @doc """
  Tries to unfold a value into a specific primitive value. The requested primitive type is given through `format`.

  Since the BACnet encoding may be a primitive value, a constructed value or a context-specific tagged value,
  this function tries to take all three forms into considering and tries to produce a primitive value.
  """
  @spec unfold_to_type(primitive_type(), encoding() | binary()) ::
          {:ok, primitive_encoding()} | {:error, term()}
  def unfold_to_type(format, tag_encoding) when format in @valid_primitive_types do
    case tag_encoding do
      # Primitive Value
      {^format, _value} ->
        {:ok, tag_encoding}

      # Constructed primitive value
      {:constructed, {_tag_number, {^format, _value} = value, 0}} ->
        {:ok, value}

      # Constructed nested value, try to unfold
      {:constructed, {_tag_number, {_format, _value} = value, _length}} ->
        unfold_to_type(format, value)

      # Tagged un-constructed context-specific value, try to decode to value
      {:tagged, {_tag_number, binary, length}} when length > 0 ->
        case decode_value(Constants.by_name!(:application_tag, format), binary) do
          {:ok, value} -> {:ok, {format, value}}
          term -> term
        end

      # We got thrown a raw binary, try to decode to value
      binary when is_binary(binary) ->
        case decode_value(Constants.by_name!(:application_tag, format), binary) do
          {:ok, value} -> {:ok, {format, value}}
          term -> term
        end

      # We do not know how to handle the tag encoding
      _term ->
        {:error, :unknown_tag_encoding}
    end
  end

  @doc """
  Helper function to create `{:tagged, ...}` tag encodings.
  """
  @spec create_tag_encoding(integer(), primitive_encoding()) ::
          {:ok, encoding()} | {:error, term()}
  def create_tag_encoding(tag_number, {type, value} = _tag_encoding) do
    create_tag_encoding(tag_number, type, value)
  end

  @doc """
  Helper function to create `{:tagged, ...}` tag encodings.
  """
  @spec create_tag_encoding(integer(), primitive_type(), term()) ::
          {:ok, encoding()} | {:error, term()}
  def create_tag_encoding(tag_number, type, value) do
    # "Context-tagged Boolean primitive data shall contain one contents octet"
    # "ASN.1 = [2] BOOLEAN" (2 = unsigned integer)
    # ASHRAE 135 - Clause 20.2.3
    type =
      if type == :boolean do
        :unsigned_integer
      else
        type
      end

    with {:ok, tvalue, _header} <- encode_value({type, value}),
         do: {:ok, {:tagged, {tag_number, tvalue, byte_size(tvalue)}}}
  end

  @doc """
  Checks whether the given integer fits into the given integer size in bits.
  """
  @spec valid_int?(integer(), 8 | 16 | 24 | 32 | 40 | 48 | 56 | 64) :: boolean()
  def valid_int?(integer, size)

  for size <- 8..64//8 do
    sized_uint = :erlang.binary_to_integer(:binary.copy("1", size), 2)
    sized_int = Integer.floor_div(sized_uint, 2)
    neg_sized_int = trunc(sized_int * -1) - 1

    def valid_int?(integer, unquote(size)) when is_integer(integer) do
      (integer >= 0 and integer <= unquote(sized_uint)) or
        (integer >= unquote(neg_sized_int) and integer <= unquote(sized_int))
    end
  end

  #### Decoding ####

  @spec decode_tag_number_internal(binary()) ::
          {:ok, {:normal | :extended, term()}, rest :: binary()} | {:error, term()}
  defp decode_tag_number_internal(<<tag::size(8), rest::binary>>)
       when not is_extended_tag_number(tag) do
    {:ok, {:normal, Bitwise.bsr(tag, 4)}, rest}
  end

  defp decode_tag_number_internal(<<head::size(8), tag::size(8), rest::binary>>)
       when is_extended_tag_number(head) do
    {:ok, {:extended, tag}, rest}
  end

  defp decode_tag_number_internal(_data) do
    {:error, :insufficient_tag_number_data}
  end

  @spec decode_tag_value_length(binary(), byte()) ::
          {:ok, length :: integer(), rest :: binary()} | {:error, term()}
  defp decode_tag_value_length(<<254, length::size(16), rest::binary>>, initial_octet)
       when is_extended_tag_value(initial_octet) do
    {:ok, length, rest}
  end

  defp decode_tag_value_length(<<255, length::size(32), rest::binary>>, initial_octet)
       when is_extended_tag_value(initial_octet) do
    {:ok, length, rest}
  end

  defp decode_tag_value_length(<<length::size(8), rest::binary>>, initial_octet)
       when is_extended_tag_value(initial_octet) do
    {:ok, length, rest}
  end

  defp decode_tag_value_length(_data, initial_octet)
       when is_extended_tag_value(initial_octet) do
    {:error, :invalid_tag_data_length}
  end

  defp decode_tag_value_length(data, initial_octet) do
    {:ok, Bitwise.band(initial_octet, 0x07), data}
  end

  @spec decode_value_internal(integer(), binary()) :: {:ok, term()} | {:error, term()}
  defp decode_value_internal(
         Constants.macro_by_name(:application_tag, :null),
         data
       )
       when is_binary(data) do
    # The data may have any meaning?
    # i.e. when context-tagged, they may mean object identifier
    # This is handled by decode_tag_value_internal already
    # but will not be handled by decode_value as context is not known

    {:ok, nil}
  end

  defp decode_value_internal(
         Constants.macro_by_name(:application_tag, :boolean),
         <<length::size(32), tvalue::size(length)-unit(8)>>
       )
       when length > 0 do
    {:ok, tvalue == 1}
  end

  defp decode_value_internal(
         Constants.macro_by_name(:application_tag, :unsigned_integer),
         <<length::size(32), tvalue::size(length)-unit(8)>>
       )
       when length > 0 do
    {:ok, tvalue}
  end

  defp decode_value_internal(
         Constants.macro_by_name(:application_tag, :signed_integer),
         <<length::size(32), tvalue::signed-size(length)-unit(8)>>
       )
       when length > 0 do
    {:ok, tvalue}
  end

  defp decode_value_internal(
         Constants.macro_by_name(:application_tag, :real),
         <<4::size(32), sign::size(1), 255::size(8), man::size(23)>>
       ) do
    tvalue =
      case {sign, man} do
        {0, 0} -> :inf
        {1, 0} -> :infn
        {_quiet, _term} -> :NaN
      end

    {:ok, tvalue}
  end

  defp decode_value_internal(
         Constants.macro_by_name(:application_tag, :real),
         <<4::size(32), tvalue::float-size(32)>>
       ) do
    {:ok, truncate_float32(tvalue)}
  end

  defp decode_value_internal(
         Constants.macro_by_name(:application_tag, :double),
         <<8::size(32), sign::size(1), 2047::size(11), man::size(52)>>
       ) do
    tvalue =
      case {sign, man} do
        {0, 0} -> :inf
        {1, 0} -> :infn
        {_quiet, _term} -> :NaN
      end

    {:ok, tvalue}
  end

  defp decode_value_internal(
         Constants.macro_by_name(:application_tag, :double),
         <<8::size(32), tvalue::float-size(64)>>
       ) do
    {:ok, tvalue}
  end

  defp decode_value_internal(
         Constants.macro_by_name(:application_tag, :octet_string),
         <<_length::size(32), data::binary>>
       ) do
    {:ok, data}
  end

  defp decode_value_internal(
         Constants.macro_by_name(:application_tag, :character_string),
         <<_length::size(32), encoding::size(8), text::binary>>
       ) do
    decode_character_string(encoding, text)
  end

  defp decode_value_internal(
         Constants.macro_by_name(:application_tag, :bitstring),
         <<_length::size(32), unused_bits::size(8), data::binary>>
       ) do
    bits =
      data
      |> bitstring_to_bits()
      |> Enum.take(bit_size(data) - unused_bits)
      |> List.to_tuple()

    {:ok, bits}
  end

  defp decode_value_internal(
         Constants.macro_by_name(:application_tag, :enumerated),
         <<length::size(32), tvalue::size(length)-unit(8)>>
       )
       when length > 0 do
    {:ok, tvalue}
  end

  defp decode_value_internal(
         Constants.macro_by_name(:application_tag, :date),
         <<_length::size(32), year::size(8), month::size(8), day::size(8), weekday::size(8)>>
       )
       when is_valid_date2(year, month, day, weekday) do
    {:ok,
     %Protocol.BACnetDate{
       year: if(year == 255, do: :unspecified, else: year + 1900),
       month:
         case month do
           255 -> :unspecified
           13 -> :odd
           14 -> :even
           _any -> month
         end,
       day:
         case day do
           255 -> :unspecified
           32 -> :last
           33 -> :odd
           34 -> :even
           _any -> day
         end,
       weekday: if(weekday == 255, do: :unspecified, else: weekday)
     }}
  end

  defp decode_value_internal(
         Constants.macro_by_name(:application_tag, :time),
         <<_length::size(32), hour::size(8), minute::size(8), second::size(8),
           hundredth::size(8)>>
       )
       when is_valid_time2(hour, minute, second, hundredth) do
    {:ok,
     %Protocol.BACnetTime{
       hour: if(hour == 255, do: :unspecified, else: hour),
       minute: if(minute == 255, do: :unspecified, else: minute),
       second: if(second == 255, do: :unspecified, else: second),
       hundredth: if(hundredth == 255, do: :unspecified, else: hundredth)
     }}
  end

  defp decode_value_internal(
         Constants.macro_by_name(:application_tag, :object_identifier),
         <<_length::size(32), type::size(10), instance::size(22)>>
       ) do
    case Constants.by_value(:object_type, type) do
      {:ok, object_type} ->
        {:ok,
         %Protocol.ObjectIdentifier{
           type: object_type,
           instance: instance
         }}

      :error ->
        {:error, {:unknown_object_type, type}}
    end
  end

  defp decode_value_internal(_tag_number, _data) do
    {:error, :invalid_data}
  end

  @spec decode_tag_value_internal(binary(), byte(), integer(), integer()) ::
          {:ok, {type :: atom(), term()}, rest :: binary()} | {:error, term()}
  defp decode_tag_value_internal(bytes, initial_octet, tag_number, length)

  defp decode_tag_value_internal(bytes, initial_octet, tag_number, length)
       when is_context_specific(initial_octet) do
    data = binary_part(bytes, 0, length)
    rest = binary_part(bytes, length, byte_size(bytes) - length)

    {:ok, {:tagged, {tag_number, data, length}}, rest}
  end

  defp decode_tag_value_internal(
         bytes,
         initial_octet,
         Constants.macro_by_name(:application_tag, :boolean),
         _length
       ) do
    tag_value = Bitwise.band(initial_octet, 0x07) == 1
    {:ok, {Constants.macro_assert_name(:application_tag, :boolean), tag_value}, bytes}
  end

  defp decode_tag_value_internal(bytes, _initial_octet, tag_number, length)
       when byte_size(bytes) >= length do
    data = binary_part(bytes, 0, length)
    rest = binary_part(bytes, length, byte_size(bytes) - length)

    case decode_value(tag_number, data) do
      {:ok, value} -> {:ok, {Constants.by_value!(:application_tag, tag_number), value}, rest}
      {:error, _err} = err -> err
    end
  end

  defp decode_tag_value_internal(_bytes, _initial_octet, _tag_number, _length) do
    {:error, :insufficient_tag_value_data}
  end

  defp bitstring_to_bits(bitstr) when is_bitstring(bitstr) do
    for <<bit::size(1) <- bitstr>> do
      bit == 1
    end
  end

  defp bits_to_bitstring(bits) when is_list(bits) do
    Enum.reduce(bits, <<>>, fn bit, acc ->
      <<acc::bitstring, intify(bit)::size(1)>>
    end)
  end

  @spec intify(boolean()) :: 0..1
  defp intify(true), do: 1
  defp intify(false), do: 0

  defp decode_character_string(Constants.macro_by_name(:character_string_encoding, :utf8), bytes) do
    {:ok, bytes}
  end

  if "VENDORS/MICSFT/PC/CP850" in Codepagex.encoding_list() do
    defp decode_character_string(
           Constants.macro_by_name(:character_string_encoding, :microsoft_dbcs),
           bytes
         ) do
      Codepagex.to_string(bytes, "VENDORS/MICSFT/PC/CP850")
    end
  else
    print_compile_warning(
      "Character encoding CP850 (DBCS) unavailable, defaulting to no conversion"
    )

    defp decode_character_string(
           Constants.macro_by_name(:character_string_encoding, :microsoft_dbcs),
           bytes
         ) do
      {:ok, bytes}
    end
  end

  if "VENDORS/MICSFT/WINDOWS/CP932" in Codepagex.encoding_list() do
    defp decode_character_string(
           Constants.macro_by_name(:character_string_encoding, :jis_x_0208),
           bytes
         ) do
      Codepagex.to_string(bytes, "VENDORS/MICSFT/WINDOWS/CP932")
    end
  else
    print_compile_warning(
      "Character encoding CP932 (JIS-X-0208) unavailable, defaulting to no conversion"
    )

    defp decode_character_string(
           Constants.macro_by_name(:character_string_encoding, :jis_x_0208),
           bytes
         ) do
      {:ok, bytes}
    end
  end

  defp decode_character_string(Constants.macro_by_name(:character_string_encoding, :ucs_4), bytes) do
    case :unicode.characters_to_binary(bytes, {:utf32, :big}) do
      bin when is_binary(bin) -> {:ok, bin}
      {:incomplete, _incompl, _data} -> {:error, "Invalid bytes for encoding"}
      {:error, _err, _data} -> {:error, "Invalid bytes for encoding"}
    end
  end

  defp decode_character_string(Constants.macro_by_name(:character_string_encoding, :ucs_2), bytes) do
    case :unicode.characters_to_binary(bytes, {:utf16, :big}) do
      bin when is_binary(bin) -> {:ok, bin}
      {:incomplete, _incompl, _data} -> {:error, "Invalid bytes for encoding"}
      {:error, _err, _data} -> {:error, "Invalid bytes for encoding"}
    end
  end

  defp decode_character_string(
         Constants.macro_by_name(:character_string_encoding, :iso_8859_1),
         bytes
       ) do
    Codepagex.to_string(bytes, :iso_8859_1)
  end

  defp decode_character_string(_term, _bytes) do
    {:error, :unknown_character_string_encoding}
  end

  @spec length_to_lenvaluetype(integer()) ::
          {len_value_type :: integer(), length_if_five :: binary()}
  defp length_to_lenvaluetype(length) when is_integer(length) and length >= 0 do
    cond do
      length < 5 -> {length, <<>>}
      length < 254 -> {5, <<length::size(8)>>}
      length < 65_536 -> {5, <<254::size(8), length::size(16)>>}
      length < 4_294_967_296 -> {5, <<255::size(8), length::size(32)>>}
      true -> raise ArgumentError, "Data is too long, exceeding 2^32-1 bytes"
    end
  end
end
