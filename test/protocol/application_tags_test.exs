defmodule BACnet.Test.Protocol.ApplicationTagsTest do
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.ObjectIdentifier

  require Logger

  use ExUnit.Case, async: true

  @moduletag :application_tags

  doctest ApplicationTags

  test_data = [
    {"primitive null", {:null, nil}, <<0x00>>, []},
    {"primitive boolean false", {:boolean, false}, <<0x10>>, []},
    {"primitive boolean true", {:boolean, true}, <<0x11>>, []},
    {"primitive unsigned int 0", {:unsigned_integer, 0}, <<0x21, 0x00>>, []},
    {"primitive unsigned int 255", {:unsigned_integer, 255}, <<0x21, 255>>, []},
    {"primitive unsigned int 1000", {:unsigned_integer, 1000}, <<0x22, 3, 232>>, []},
    {"primitive unsigned int 128593", {:unsigned_integer, 128_593}, <<0x23, 1, 246, 81>>, []},
    {"primitive unsigned int 512256128", {:unsigned_integer, 512_256_128},
     <<0x24, 30, 136, 104, 128>>, []},
    {"primitive unsigned int 5122561286432", {:unsigned_integer, 5_122_561_286_432},
     <<0x25, 6, 4, 168, 176, 114, 33, 32>>, []},
    {"primitive signed int 0", {:signed_integer, 0}, <<0x31, 0x00>>, []},
    {"primitive signed int 127", {:signed_integer, 127}, <<0x31, 127>>, []},
    {"primitive signed int -32", {:signed_integer, -32}, <<0x31, 224>>, []},
    {"primitive signed int -255", {:signed_integer, -255}, <<0x32, 255, 1>>, []},
    {"primitive signed int -32769", {:signed_integer, -32_769}, <<0x33, 0xFF, 0x7F, 0xFF>>, []},
    {"primitive signed int 1000", {:signed_integer, 1000}, <<0x32, 3, 232>>, []},
    {"primitive signed int 32768", {:signed_integer, 32_768}, <<0x33, 0x00, 0x80, 0x00>>, []},
    {"primitive signed int 128593", {:signed_integer, 128_593}, <<0x33, 1, 246, 81>>, []},
    {"primitive signed int 512256128", {:signed_integer, 512_256_128},
     <<0x34, 30, 136, 104, 128>>, []},
    {"primitive signed int 5122561286432", {:signed_integer, 5_122_561_286_432},
     <<0x35, 6, 4, 168, 176, 114, 33, 32>>, []},
    {"primitive signed int -52322561286432", {:signed_integer, -52_322_561_286_432},
     <<0x35, 6, 208, 105, 180, 82, 30, 224>>, []},
    # We can't test against 0.0, because we would get warnings from the Elixir compiler for matching 0.0
    # even though we have the plus sign specified, why are you doing this Elixir?
    # {"primitive real 0.0", {:real, +0.0}, <<0x44, 0, 0, 0, 0>>, []},
    {"primitive real 3.0", {:real, 3.0}, <<0x44, 64, 64, 0, 0>>, []},
    {"primitive real -3.141", {:real, -3.141}, <<0x44, 192, 73, 6, 37>>, []},
    {"primitive real NaN", {:real, :NaN}, <<0x44, 0::size(1), 255::size(8), 1::size(23)>>, []},
    {"primitive real +INF", {:real, :inf}, <<0x44, 0::size(1), 255::size(8), 0::size(23)>>, []},
    {"primitive real -INF", {:real, :infn}, <<0x44, 1::size(1), 255::size(8), 0::size(23)>>, []},
    # We can't test against 0.0, because we would get warnings from the Elixir compiler for matching 0.0
    # even though we have the plus sign specified, why are you forsaking us Elixir?
    # {"primitive double 0.0", {:double, +0.0}, <<0x55, 8, 0, 0, 0, 0, 0, 0, 0, 0>>, []},
    {"primitive double 3.0", {:double, 3.0}, <<0x55, 8, 64, 8, 0, 0, 0, 0, 0, 0>>, []},
    {"primitive double -3.141", {:double, -3.141},
     <<0x55, 8, 192, 9, 32, 196, 155, 165, 227, 84>>, []},
    {"primitive double NaN", {:double, :NaN},
     <<0x55, 8, 0::size(1), 2047::size(11), 1::size(52)>>, []},
    {"primitive double +INF", {:double, :inf},
     <<0x55, 8, 0::size(1), 2047::size(11), 0::size(52)>>, []},
    {"primitive double -INF", {:double, :infn},
     <<0x55, 8, 1::size(1), 2047::size(11), 0::size(52)>>, []},
    {"primitive octet string", {:octet_string, "Hello World"},
     <<0x65, 11, 72, 101, 108, 108, 111, 32, 87, 111, 114, 108, 100>>, []},
    {"primitive character string UTF-8", {:character_string, "Hello World"},
     <<0x75, 12, 0, 72, 101, 108, 108, 111, 32, 87, 111, 114, 108, 100>>, []},
    {"primitive character string DBCS", {:character_string, "Hello Ærld"},
     <<0x75, 13, 1, 0x03, 0x52, "Hello ", 146, "rld">>, [skip_encode: true]},
    {"primitive character string JIS-X-0208", {:character_string, "Hello 0rld"},
     <<0x75, 13, 2, 72, 101, 108, 108, 111, 32, 48, 21, 31, 114, 108, 100>>, [skip_encode: true]},
    {"primitive character string UCS-4 (UTF-32)", {:character_string, "Hello World"},
     <<0x75, 45, 3, 0, 0, 0, 72, 0, 0, 0, 101, 0, 0, 0, 108, 0, 0, 0, 108, 0, 0, 0, 111, 0, 0, 0,
       32, 0, 0, 0, 87, 0, 0, 0, 111, 0, 0, 0, 114, 0, 0, 0, 108, 0, 0, 0, 100>>,
     [skip_encode: true]},
    {"primitive character string UCS-2 (UTF-16)", {:character_string, "Hello World"},
     <<0x75, 23, 4, 0, 72, 0, 101, 0, 108, 0, 108, 0, 111, 0, 32, 0, 87, 0, 111, 0, 114, 0, 108,
       0, 100>>, [skip_encode: true]},
    {"primitive character string ISO-8851-1", {:character_string, "Hello World"},
     <<0x75, 12, 5, 72, 101, 108, 108, 111, 32, 87, 111, 114, 108, 100>>,
     [encoding: :iso_8859_1]},
    {"primitive bitstring F", {:bitstring, {false}}, <<0x82, 7, 0>>, []},
    {"primitive bitstring T", {:bitstring, {true}}, <<0x82, 7, 128>>, []},
    {"primitive bitstring FTT", {:bitstring, {false, true, true}}, <<0x82, 5, 96>>, []},
    {"primitive bitstring TTF", {:bitstring, {true, true, false}}, <<0x82, 5, 192>>, []},
    {"primitive bitstring FFFT", {:bitstring, {false, false, false, true}}, <<0x82, 4, 16>>, []},
    {"primitive bitstring FTFT", {:bitstring, {false, true, false, true}}, <<0x82, 4, 80>>, []},
    {"primitive bitstring FFFFFFFF",
     {:bitstring, {false, false, false, false, false, false, false, false}}, <<0x82, 0, 0>>, []},
    {"primitive bitstring FTFFTFFT",
     {:bitstring, {false, true, false, false, true, false, false, true}}, <<0x82, 0, 73>>, []},
    {"primitive enumerated 0", {:enumerated, 0}, <<0x91, 0>>, []},
    {"primitive enumerated 5", {:enumerated, 5}, <<0x91, 5>>, []},
    {"primitive enumerated 7539907259", {:enumerated, 7_539_907_259},
     <<0x95, 5, 1, 193, 105, 218, 187>>, []},
    {"primitive date unspecified",
     {:date,
      %BACnetDate{
        year: :unspecified,
        month: :unspecified,
        day: :unspecified,
        weekday: :unspecified
      }}, <<0xA4, 255, 255, 255, 255>>, []},
    {"primitive date 2022-12-09", {:date, %BACnetDate{year: 2022, month: 12, day: 9, weekday: 5}},
     <<0xA4, 122, 12, 9, 5>>, []},
    {"primitive date 2022-12-05 without weekday",
     {:date, %BACnetDate{year: 2022, month: 12, day: 5, weekday: :unspecified}},
     <<0xA4, 122, 12, 5, 255>>, []},
    {"primitive date 2022-O-05 with odd month",
     {:date, %BACnetDate{year: 2022, month: :odd, day: 5, weekday: :unspecified}},
     <<0xA4, 122, 13, 5, 255>>, []},
    {"primitive date 2022-E-05 with even month",
     {:date, %BACnetDate{year: 2022, month: :even, day: 5, weekday: :unspecified}},
     <<0xA4, 122, 14, 5, 255>>, []},
    {"primitive date 2022-12-L with last day",
     {:date, %BACnetDate{year: 2022, month: 12, day: :last, weekday: 5}},
     <<0xA4, 122, 12, 32, 5>>, []},
    {"primitive date 2022-12-O with odd day",
     {:date, %BACnetDate{year: 2022, month: 12, day: :odd, weekday: 5}}, <<0xA4, 122, 12, 33, 5>>,
     []},
    {"primitive date 2022-12-E with even day",
     {:date, %BACnetDate{year: 2022, month: 12, day: :even, weekday: 5}},
     <<0xA4, 122, 12, 34, 5>>, []},
    {"primitive time unspecified",
     {:time,
      %BACnetTime{
        hour: :unspecified,
        minute: :unspecified,
        second: :unspecified,
        hundredth: :unspecified
      }}, <<0xB4, 255, 255, 255, 255>>, []},
    {"primitive time 23:59:59.99",
     {:time, %BACnetTime{hour: 23, minute: 59, second: 59, hundredth: 99}},
     <<0xB4, 23, 59, 59, 99>>, []},
    {"primitive time 19:25:36 without hundredth",
     {:time, %BACnetTime{hour: 19, minute: 25, second: 36, hundredth: :unspecified}},
     <<0xB4, 19, 25, 36, 255>>, []},
    {"primitive object identifier",
     {:object_identifier, %ObjectIdentifier{type: :device, instance: 259_509}},
     <<0xC4, 2, 3, 245, 181>>, []},
    {"tagged tag num 0", {:tagged, {0, <<0>>, 1}}, <<0x09, 0>>, []},
    {"tagged tag num 8", {:tagged, {8, <<0>>, 1}}, <<0x89, 0>>, []},
    {"tagged tag num 14", {:tagged, {14, <<0>>, 1}}, <<0xE9, 0>>, []},
    {"tagged tag num 15", {:tagged, {15, <<0>>, 1}}, <<0xF9, 15, 0>>, []},
    {"tagged tag num 32", {:tagged, {32, <<0>>, 1}}, <<0xF9, 32, 0>>, []},
    {"tagged tag num 254", {:tagged, {254, <<0>>, 1}}, <<0xF9, 254, 0>>, []},
    {"constructed data real", {:constructed, {0, {:real, 6.9}, 0}},
     <<14, 68, 64, 220, 204, 205, 15>>, []},
    {"constructed data tag num 33 real", {:constructed, {33, {:real, 6.9}, 0}},
     <<254, 33, 68, 64, 220, 204, 205, 255, 33>>, []},
    {"constructed data empty", {:constructed, {0, [], 0}}, <<14, 15>>, []},
    {"constructed data tag num 14 empty", {:constructed, {14, [], 0}}, <<0xEE, 0xEF>>, []},
    {"constructed data tag num 15 empty", {:constructed, {15, [], 0}}, <<0xFE, 15, 0xFF, 15>>,
     []},
    {"constructed data tag num 32 empty", {:constructed, {32, [], 0}}, <<254, 32, 255, 32>>, []},
    {"constructed data tag num 254 empty", {:constructed, {254, [], 0}}, <<0xFE, 254, 0xFF, 254>>,
     []},
    {"constructed data tag num 254 child", {:constructed, {254, {:null, nil}, 0}},
     <<0xFE, 254, 0, 0xFF, 254>>, []},
    {"constructed data list of null",
     {:constructed,
      {3,
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
       ], 0}}, <<62, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 63>>, []},
    {"constructed data nested encoding",
     {:constructed,
      {12, {:constructed, {6, [tagged: {0, "U", 1}, constructed: {2, {:real, 1.0}, 0}], 0}}, 0}},
     <<206, 110, 9, 85, 46, 68, 63, 128, 0, 0, 47, 111, 207>>, []},
    {"constructed data tag num 32 nested encoding",
     {:constructed,
      {32, {:constructed, {6, [tagged: {0, "U", 1}, constructed: {2, {:real, 1.0}, 0}], 0}}, 0}},
     <<254, 32, 110, 9, 85, 46, 68, 63, 128, 0, 0, 47, 111, 255, 32>>, []},
    {"constructed data tag num 32 nested encoding 2",
     {:constructed,
      {32, {:constructed, {18, [tagged: {0, "U", 1}, constructed: {2, {:real, 1.0}, 0}], 0}}, 0}},
     <<254, 32, 254, 18, 9, 85, 46, 68, 63, 128, 0, 0, 47, 255, 18, 255, 32>>, []}
  ]

  for {description, encode_data, decode_data, encode_opts} <- test_data do
    test "decode #{description}" do
      assert {:ok, unquote(Macro.escape(encode_data)), ""} =
               ApplicationTags.decode(unquote(decode_data))

      assert {:ok, unquote(Macro.escape(encode_data)), <<100, 88>>} =
               ApplicationTags.decode(<<unquote(decode_data)::binary, 100, 88>>)
    end

    unless encode_opts[:skip_encode] do
      test "encode #{description}" do
        assert {:ok, unquote(decode_data)} =
                 ApplicationTags.encode(unquote(Macro.escape(encode_data)), unquote(encode_opts))
      end
    end
  end

  test "time decoding rejects invalid hundredth 100" do
    assert {:error, :invalid_data} = ApplicationTags.decode(<<0xB4, 12, 0, 0, 100>>)
    assert {:error, :invalid_data} = ApplicationTags.decode_value(0xB, <<12, 0, 0, 100>>)
  end

  test "time decoding rejects invalid hundredth 200" do
    assert {:error, :invalid_data} = ApplicationTags.decode(<<0xB4, 12, 0, 0, 200>>)
    assert {:error, :invalid_data} = ApplicationTags.decode_value(0xB, <<12, 0, 0, 200>>)
  end

  test "time decoding rejects invalid hundredth 254" do
    assert {:error, :invalid_data} = ApplicationTags.decode(<<0xB4, 12, 0, 0, 254>>)
    assert {:error, :invalid_data} = ApplicationTags.decode_value(0xB, <<12, 0, 0, 254>>)
  end

  test "time decoding keeps hundredth 99" do
    assert {:ok, {:time, time}, ""} = ApplicationTags.decode(<<0xB4, 12, 0, 0, 99>>)
    assert BACnetTime.valid?(time)
    assert time.hundredth == 99
    assert {:ok, ~T[12:00:00.990000]} = BACnetTime.to_time(time)
    assert {:ok, <<0xB4, 12, 0, 0, 99>>} = ApplicationTags.encode({:time, time})
  end

  test "time decoding keeps unspecified hundredth 255" do
    assert {:ok, {:time, time}, ""} = ApplicationTags.decode(<<0xB4, 12, 0, 0, 255>>)
    assert BACnetTime.valid?(time)
    assert time.hundredth == :unspecified
    assert {:ok, <<0xB4, 12, 0, 0, 255>>} = ApplicationTags.encode({:time, time})
  end

  test "bitstring decoding rejects unused-bit count 8" do
    assert {:error, :invalid_data} = ApplicationTags.decode(<<0x82, 8, 0>>)
    assert {:error, :invalid_data} = ApplicationTags.decode_value(0x8, <<8, 0>>)
  end

  test "bitstring decoding rejects unused-bit count 9" do
    assert {:error, :invalid_data} = ApplicationTags.decode(<<0x82, 9, 0xFF>>)
    assert {:error, :invalid_data} = ApplicationTags.decode_value(0x8, <<9, 0xFF>>)
  end

  test "bitstring decoding rejects unused-bit count 255" do
    assert {:error, :invalid_data} = ApplicationTags.decode(<<0x82, 255, 0>>)
    assert {:error, :invalid_data} = ApplicationTags.decode_value(0x8, <<255, 0>>)
  end

  test "an empty bitstring cannot contain unused bits" do
    assert {:error, :invalid_data} = ApplicationTags.decode(<<0x81, 1>>)
    assert {:error, :invalid_data} = ApplicationTags.decode_value(0x8, <<1>>)
    assert {:ok, {:bitstring, {}}, ""} = ApplicationTags.decode(<<0x81, 0>>)
    assert {:ok, {}} = ApplicationTags.decode_value(0x8, <<0>>)
  end

  test "bitstring decoding accepts legal unused-bit count 0" do
    assert {:ok, {:bitstring, {false, false, false, false, false, false, false, false}}, ""} =
             ApplicationTags.decode(<<0x82, 0, 0>>)

    assert {:ok, {false, false, false, false, false, false, false, false}} =
             ApplicationTags.decode_value(0x8, <<0, 0>>)
  end

  test "bitstring decoding accepts legal unused-bit count 1" do
    assert {:ok, {:bitstring, {false, false, false, false, false, false, false}}, ""} =
             ApplicationTags.decode(<<0x82, 1, 0>>)

    assert {:ok, {false, false, false, false, false, false, false}} =
             ApplicationTags.decode_value(0x8, <<1, 0>>)
  end

  test "bitstring decoding accepts legal unused-bit count 2" do
    assert {:ok, {:bitstring, {false, false, false, false, false, false}}, ""} =
             ApplicationTags.decode(<<0x82, 2, 0>>)

    assert {:ok, {false, false, false, false, false, false}} =
             ApplicationTags.decode_value(0x8, <<2, 0>>)
  end

  test "bitstring decoding accepts legal unused-bit count 3" do
    assert {:ok, {:bitstring, {false, false, false, false, false}}, ""} =
             ApplicationTags.decode(<<0x82, 3, 0>>)

    assert {:ok, {false, false, false, false, false}} =
             ApplicationTags.decode_value(0x8, <<3, 0>>)
  end

  test "bitstring decoding accepts legal unused-bit count 4" do
    assert {:ok, {:bitstring, {false, false, false, false}}, ""} =
             ApplicationTags.decode(<<0x82, 4, 0>>)

    assert {:ok, {false, false, false, false}} = ApplicationTags.decode_value(0x8, <<4, 0>>)
  end

  test "bitstring decoding accepts legal unused-bit count 5" do
    assert {:ok, {:bitstring, {false, false, false}}, ""} = ApplicationTags.decode(<<0x82, 5, 0>>)
    assert {:ok, {false, false, false}} = ApplicationTags.decode_value(0x8, <<5, 0>>)
  end

  test "bitstring decoding accepts legal unused-bit count 6" do
    assert {:ok, {:bitstring, {false, false}}, ""} = ApplicationTags.decode(<<0x82, 6, 0>>)
    assert {:ok, {false, false}} = ApplicationTags.decode_value(0x8, <<6, 0>>)
  end

  test "bitstring decoding accepts legal unused-bit count 7" do
    assert {:ok, {:bitstring, {false}}, ""} = ApplicationTags.decode(<<0x82, 7, 0>>)
    assert {:ok, {false}} = ApplicationTags.decode_value(0x8, <<7, 0>>)
  end

  test "bitstring decoding requires an unused-bit-count byte" do
    assert {:error, :invalid_data} = ApplicationTags.decode(<<0x80>>)
    assert {:error, :invalid_data} = ApplicationTags.decode_value(0x8, <<>>)
  end

  test "bitstring decoding removes only the unused bits in the final byte" do
    bits = {true, false, true, false, true, false, true, false, true}

    assert {:ok, {:bitstring, ^bits}, <<0x11>>} =
             ApplicationTags.decode(<<0x83, 7, 0xAA, 0x80, 0x11>>)

    assert {:ok, ^bits} = ApplicationTags.decode_value(0x8, <<7, 0xAA, 0x80>>)
  end

  test "decode empty data failure" do
    assert {:error, :empty_data} = ApplicationTags.decode(<<>>)
  end

  test "decode real not enough data" do
    assert {:error, :insufficient_tag_value_data} = ApplicationTags.decode(<<0x44, 255>>)
  end

  for {description, payload, expected} <- [
        {"positive two thirds", <<0x3F, 0x2A, 0xAA, 0xAB>>, 0.67},
        {"negative two thirds", <<0xBF, 0x2A, 0xAA, 0xAB>>, -0.67},
        {"positive eight thirds", <<0x40, 0x2A, 0xAA, 0xAB>>, 2.67},
        {"negative eight thirds", <<0xC0, 0x2A, 0xAA, 0xAB>>, -2.67}
      ] do
    test "decode real rounds repeating decimals to fractional precision: #{description}" do
      assert {:ok, unquote(expected)} = ApplicationTags.decode_value(0x4, unquote(payload))

      assert {:ok, {:real, unquote(expected)}, <<>>} =
               ApplicationTags.decode(<<0x44, unquote(payload)::binary>>)
    end
  end

  test "decode double not enough data" do
    assert {:error, :insufficient_tag_value_data} =
             ApplicationTags.decode(<<0x55, 8, 192, 73, 6, 37>>)
  end

  test "decode octet string not enough data" do
    assert {:error, :insufficient_tag_value_data} = ApplicationTags.decode(<<0x65, 11, 72>>)
  end

  test "decode character string UTF-8 with emojis" do
    emoji = "😄"
    len = byte_size(emoji) + 1

    assert {:ok, {:character_string, ^emoji}, ""} =
             ApplicationTags.decode(<<0x75, len, 0, emoji::binary>>)
  end

  test "decode character string unknown encoding" do
    assert {:error, :unknown_character_string_encoding} =
             ApplicationTags.decode(<<0x75, 1, 10, 72>>)
  end

  test "decode character string DBCS example from Clause 20.2.9" do
    # The example's encoded bytes use a lowercase 's' in "string".
    text = "This is a BACnet string!"
    value = <<1, 850::size(16), text::binary>>

    assert {:ok, {:character_string, ^text}, <<0x11>>} =
             ApplicationTags.decode(<<0x75, byte_size(value), value::binary, 0x11>>)

    assert {:ok, ^text} = ApplicationTags.decode_value(7, value)
  end

  test "decode character string DBCS selects the declared codepage" do
    assert {:ok, "Æ"} = ApplicationTags.decode_value(7, <<1, 850::size(16), 0x92>>)

    assert {:ok, "日本語"} =
             ApplicationTags.decode_value(
               7,
               <<1, 932::size(16), 0x93, 0xFA, 0x96, 0x7B, 0x8C, 0xEA>>
             )

    assert {:ok, {:character_string, "日本語"}, <<0x11>>} =
             ApplicationTags.decode(
               <<0x75, 9, 1, 932::size(16), 0x93, 0xFA, 0x96, 0x7B, 0x8C, 0xEA, 0x11>>
             )
  end

  test "decode character string DBCS allows an empty string after the codepage" do
    assert {:ok, {:character_string, ""}, ""} =
             ApplicationTags.decode(<<0x73, 1, 850::size(16)>>)

    assert {:ok, ""} = ApplicationTags.decode_value(7, <<1, 850::size(16)>>)
  end

  test "decode character string DBCS rejects an incomplete codepage" do
    for bytes <- [<<1>>, <<1, 0x03>>] do
      assert {:error, :invalid_data} = ApplicationTags.decode_value(7, bytes)

      assert {:error, :invalid_data} =
               ApplicationTags.decode(<<0x70 + byte_size(bytes), bytes::binary>>)
    end
  end

  test "decode character string DBCS rejects an unsupported codepage" do
    assert {:error, :unknown_character_string_encoding} =
             ApplicationTags.decode_value(7, <<1, 65_535::size(16), "Hello">>)
  end

  test "decode character string DBCS rejects invalid bytes for the declared codepage" do
    assert {:error, "Invalid bytes for encoding"} =
             ApplicationTags.decode_value(7, <<1, 932::size(16), 0x93>>)
  end

  test "decode character string JIS-X invalid bytes for encoding" do
    assert {:error, "Invalid bytes for encoding"} =
             ApplicationTags.decode(
               <<0x75, 13, 2, 72, 101, 108, 108, 111, 32, 1, 146, 31, 114, 108, 100>>
             )
  end

  test "decode character string UCS-4 (UTF-32) incomplete" do
    assert {:error, "Invalid bytes for encoding"} = ApplicationTags.decode(<<0x75, 2, 3, 0>>)
  end

  test "decode character string UCS-4 (UTF-32) invalid bytes for encoding" do
    assert {:error, "Invalid bytes for encoding"} =
             ApplicationTags.decode(<<0x75, 4, 3, 255, 255, 255>>)
  end

  test "decode character string UCS-2 (UTF-16) incomplete" do
    assert {:error, "Invalid bytes for encoding"} = ApplicationTags.decode(<<0x75, 2, 4, 0>>)
  end

  test "decode character string UCS-2 (UTF-16) invalid bytes for encoding" do
    assert {:error, "Invalid bytes for encoding"} =
             ApplicationTags.decode(<<0x75, 4, 4, 0xD8, 0x00, 0x0B>>)
  end

  test "decode character string not enough data" do
    assert {:error, :insufficient_tag_value_data} = ApplicationTags.decode(<<0x75, 11, 0, 72>>)
  end

  test "decode constructed invalid data" do
    assert {:error, :insufficient_tag_value_data} = ApplicationTags.decode(<<14, 68>>)
  end

  test "decode constructed invalid more data" do
    assert {:error, :insufficient_tag_value_data} =
             ApplicationTags.decode(<<14, 68, 0, 0, 0, 0, 68>>)
  end

  test "constructed value rejects a missing close after no children" do
    assert {:error, _reason} = ApplicationTags.decode(<<0x0E>>)
  end

  test "constructed value rejects a missing close after one child" do
    assert {:error, _reason} = ApplicationTags.decode(<<0x0E, 0>>)
  end

  test "constructed value rejects a missing close after two children" do
    assert {:error, _reason} = ApplicationTags.decode(<<0x0E, 0, 0>>)
  end

  test "constructed value rejects a missing close after an extended opening tag" do
    assert {:error, _reason} = ApplicationTags.decode(<<0xFE, 32, 0>>)
  end

  test "constructed value rejects nested missing outer close" do
    assert {:error, _reason} = ApplicationTags.decode(<<0x0E, 0x1E, 0, 0x1F>>)
  end

  test "constructed value rejects wrong closing tag" do
    assert {:error, _reason} = ApplicationTags.decode(<<0x0E, 0, 0x1F>>)
  end

  test "a wrong normal closing tag is rejected even when enough data follows" do
    data = <<0, 0, 0, 0, 0, 0, 0>>
    assert {:error, _reason} = ApplicationTags.decode(<<0x0E, 0x1F, data::binary, 0x0F>>)
    assert {:error, _reason} = ApplicationTags.decode(<<0x0E, 0, 0x1F, data::binary, 0x0F>>)
  end

  test "a wrong extended closing tag is rejected even when enough data follows" do
    data = <<0, 0, 0, 0, 0, 0, 0>>

    assert {:error, _reason} =
             ApplicationTags.decode(<<0xFE, 32, 0xFF, 33, data::binary, 0xFF, 32>>)

    assert {:error, _reason} =
             ApplicationTags.decode(<<0xFE, 32, 0, 0xFF, 33, data::binary, 0xFF, 32>>)
  end

  test "decode rejects a closing tag without an opening tag" do
    assert {:error, _reason} = ApplicationTags.decode(<<0x0F, 0, 0, 0, 0, 0, 0, 0>>)
    assert {:error, _reason} = ApplicationTags.decode(<<0xFF, 32, 0, 0, 0, 0, 0, 0, 0>>)
  end

  test "constructed value rejects truncated extended close" do
    assert {:error, _reason} = ApplicationTags.decode(<<0xFE, 32, 0, 0xFF>>)
  end

  test "constructed value rejects an empty value with a truncated extended close" do
    assert {:error, _reason} = ApplicationTags.decode(<<0xFE, 32, 0xFF>>)
  end

  test "constructed value rejects an empty value with the wrong extended closing tag" do
    assert {:error, _reason} = ApplicationTags.decode(<<0xFE, 32, 0xFF, 33>>)
  end

  test "constructed value rejects one child with the wrong extended closing tag" do
    assert {:error, _reason} = ApplicationTags.decode(<<0xFE, 32, 0, 0xFF, 33>>)
  end

  test "constructed value rejects two children with the wrong extended closing tag" do
    assert {:error, _reason} = ApplicationTags.decode(<<0xFE, 32, 0, 0, 0xFF, 33>>)
  end

  test "constructed value rejects closing nested tags in the wrong order" do
    assert {:error, _reason} = ApplicationTags.decode(<<0x0E, 0x1E, 0, 0x0F, 0x1F>>)
  end

  test "an empty constructed value preserves following bytes" do
    assert {:ok, {:constructed, {0, [], 0}}, <<0x11>>} =
             ApplicationTags.decode(<<0x0E, 0x0F, 0x11>>)

    assert {:ok, {:constructed, {32, [], 0}}, <<0x11>>} =
             ApplicationTags.decode(<<0xFE, 32, 0xFF, 32, 0x11>>)
  end

  test "a single constructed child preserves following bytes" do
    assert {:ok, {:constructed, {0, {:null, nil}, 0}}, <<0x11>>} =
             ApplicationTags.decode(<<0x0E, 0, 0x0F, 0x11>>)

    assert {:ok, {:constructed, {32, {:null, nil}, 0}}, <<0x11>>} =
             ApplicationTags.decode(<<0xFE, 32, 0, 0xFF, 32, 0x11>>)
  end

  test "multiple constructed children preserve following bytes" do
    assert {:ok, {:constructed, {0, [null: nil, null: nil], 0}}, <<0x11>>} =
             ApplicationTags.decode(<<0x0E, 0, 0, 0x0F, 0x11>>)

    assert {:ok, {:constructed, {32, [null: nil, null: nil], 0}}, <<0x11>>} =
             ApplicationTags.decode(<<0xFE, 32, 0, 0, 0xFF, 32, 0x11>>)
  end

  test "properly closed nested constructed values preserve following bytes" do
    assert {:ok, {:constructed, {0, {:constructed, {1, {:null, nil}, 0}}, 0}}, <<0x11>>} =
             ApplicationTags.decode(<<0x0E, 0x1E, 0, 0x1F, 0x0F, 0x11>>)
  end

  test "a closing-tag byte inside a primitive payload does not close a constructed value" do
    assert {:error, _reason} = ApplicationTags.decode(<<0x0E, 0x61, 0x0F>>)

    assert {:ok, {:constructed, {0, {:octet_string, <<0x0F>>}, 0}}, <<0x11>>} =
             ApplicationTags.decode(<<0x0E, 0x61, 0x0F, 0x0F, 0x11>>)
  end

  test "decode unsigned integer with 16bit length" do
    assert {:ok, {:unsigned_integer, 5}, <<>>} = ApplicationTags.decode(<<0x25, 254, 0, 1, 5>>)
  end

  test "decode unsigned integer with 32bit length" do
    assert {:ok, {:unsigned_integer, 5}, <<>>} =
             ApplicationTags.decode(<<0x25, 255, 0, 0, 0, 1, 5>>)
  end

  test "decode with invalid extended length" do
    assert {:error, :invalid_tag_data_length} = ApplicationTags.decode(<<0x25>>)
  end

  test "decode context specific with truncated length" do
    assert {:error, :invalid_tag_data_length} =
             ApplicationTags.decode(<<0xFD, 0, 128, 0, 5, 25, 102>>)
  end

  test "decode tag number normal boolean" do
    assert {:ok, {:normal, 1}, <<>>} = ApplicationTags.decode_tag_number(<<0x11>>)
  end

  test "decode tag number normal unsigned integer" do
    assert {:ok, {:normal, 2}, <<5>>} = ApplicationTags.decode_tag_number(<<0x21, 5>>)
  end

  test "decode tag number extended" do
    assert {:ok, {:extended, 33}, <<68, 64, 220, 204, 205, 255>>} =
             ApplicationTags.decode_tag_number(<<254, 33, 68, 64, 220, 204, 205, 255>>)
  end

  test "decode tag number empty" do
    assert {:error, :insufficient_tag_number_data} = ApplicationTags.decode_tag_number(<<>>)
  end

  test "decode value primitive boolean false" do
    assert {:ok, false} = ApplicationTags.decode_value(1, <<0>>)
  end

  test "decode value primitive boolean true" do
    assert {:ok, true} = ApplicationTags.decode_value(1, <<1>>)
  end

  test "decode value primitive object identifier unknown object type" do
    assert {:ok, %ObjectIdentifier{type: 1023, instance: 4_191_669}} =
             ApplicationTags.decode_value(0xC, <<255, 255, 245, 181>>)
  end

  test "encode character string UTF-8 explicit encoding" do
    assert {:ok, <<0x75, 6, 0, 72, 101, 108, 108, 111>>} =
             ApplicationTags.encode({:character_string, "Hello"}, encoding: :utf8)
  end

  test "encode character string unknown encoding" do
    assert_raise ArgumentError, fn ->
      ApplicationTags.encode({:character_string, "Hello"}, encoding: :dbcs)
    end
  end

  test "encode character string invalid UTF-8 bytes" do
    assert {:error, :invalid_utf8_string} = ApplicationTags.encode({:character_string, <<255>>})
  end

  test "encode character string invalid ISO-88591-1 bytes" do
    assert {:error, "Invalid bytes for encoding"} =
             ApplicationTags.encode({:character_string, "❤"}, encoding: :iso_8859_1)
  end

  test "encode elixir date 2022-12-09" do
    assert {:ok, <<0xA4, 122, 12, 9, 5>>} =
             ApplicationTags.encode({:date, Date.new!(2022, 12, 9)})
  end

  test "encode elixir time 19:35:49" do
    assert {:ok, <<0xB4, 19, 35, 49, 0>>} = ApplicationTags.encode({:time, Time.new!(19, 35, 49)})
  end

  test "encode elixir time 19:35:49.5" do
    assert {:ok, <<0xB4, 19, 35, 49, 50>>} =
             ApplicationTags.encode({:time, Time.new!(19, 35, 49, {500_000, 1})})
  end

  test "encode elixir time 19:35:49.05" do
    assert {:ok, <<0xB4, 19, 35, 49, 5>>} =
             ApplicationTags.encode({:time, Time.new!(19, 35, 49, {50_000, 2})})
  end

  test "encode elixir time 19:35:49.500" do
    assert {:ok, <<0xB4, 19, 35, 49, 50>>} =
             ApplicationTags.encode({:time, Time.new!(19, 35, 49, {500_000, 3})})
  end

  test "encode elixir time 19:35:49.500_0" do
    assert {:ok, <<0xB4, 19, 35, 49, 50>>} =
             ApplicationTags.encode({:time, Time.new!(19, 35, 49, {500_000, 4})})
  end

  test "encode elixir time 19:35:49.500_00" do
    assert {:ok, <<0xB4, 19, 35, 49, 50>>} =
             ApplicationTags.encode({:time, Time.new!(19, 35, 49, {500_000, 5})})
  end

  test "encode elixir time 19:35:49.500_000" do
    assert {:ok, <<0xB4, 19, 35, 49, 50>>} =
             ApplicationTags.encode({:time, Time.new!(19, 35, 49, {500_000, 6})})
  end

  test "native time encoding treats fractional precision as display metadata" do
    for time <- [
          ~T[19:35:49.5],
          ~T[19:35:49.50],
          ~T[19:35:49.500],
          ~T[19:35:49.5000],
          ~T[19:35:49.50000],
          ~T[19:35:49.500000]
        ] do
      assert {:ok, <<0xB4, 19, 35, 49, 50>>} = ApplicationTags.encode({:time, time})
      assert {:ok, <<19, 35, 49, 50>>, _header} = ApplicationTags.encode_value({:time, time})
    end

    assert {:ok, <<0xB4, 19, 35, 49, 1>>} = ApplicationTags.encode({:time, ~T[19:35:49.019999]})
    assert {:ok, <<0xB4, 19, 35, 49, 99>>} = ApplicationTags.encode({:time, ~T[19:35:49.999999]})
  end

  test "time encoding rejects invalid hundredth 100" do
    time = %BACnetTime{hour: 12, minute: 0, second: 0, hundredth: 100}
    refute BACnetTime.valid?(time)
    assert {:error, :invalid_value} = ApplicationTags.encode({:time, time})
    assert {:error, :invalid_value} = ApplicationTags.encode_value({:time, time})
  end

  test "time encoding rejects invalid hundredth 200" do
    time = %BACnetTime{hour: 12, minute: 0, second: 0, hundredth: 200}
    refute BACnetTime.valid?(time)
    assert {:error, :invalid_value} = ApplicationTags.encode({:time, time})
    assert {:error, :invalid_value} = ApplicationTags.encode_value({:time, time})
  end

  test "time encoding rejects invalid hundredth 254" do
    time = %BACnetTime{hour: 12, minute: 0, second: 0, hundredth: 254}
    refute BACnetTime.valid?(time)
    assert {:error, :invalid_value} = ApplicationTags.encode({:time, time})
    assert {:error, :invalid_value} = ApplicationTags.encode_value({:time, time})
  end

  test "encode object identifier invalid too large type" do
    assert {:error, :unknown_object_type} =
             ApplicationTags.encode(
               {:object_identifier, %ObjectIdentifier{type: 1024, instance: 0}}
             )
  end

  test "encode object identifier invalid negative instance" do
    assert {:error, :invalid_value} =
             ApplicationTags.encode(
               {:object_identifier, %ObjectIdentifier{type: :device, instance: -1}}
             )
  end

  test "encode object identifier invalid too large instance" do
    for instance <- [4_194_304, 4_194_304_999] do
      value = {:object_identifier, %ObjectIdentifier{type: :device, instance: instance}}
      assert {:error, :invalid_value} = ApplicationTags.encode(value)
      assert {:error, :invalid_value} = ApplicationTags.encode_value(value)
    end
  end

  test "object identifier encoding preserves both boundaries of the 22-bit instance field" do
    for type <- [:device, 1023], instance <- [0, 4_194_303] do
      identifier = %ObjectIdentifier{type: type, instance: instance}
      assert ObjectIdentifier.valid?(identifier)

      assert {:ok, bytes, _header} =
               ApplicationTags.encode_value({:object_identifier, identifier})

      assert byte_size(bytes) == 4
      assert {:ok, ^identifier} = ApplicationTags.decode_value(12, bytes)

      assert {:ok, <<0xC4, ^bytes::binary>>} =
               ApplicationTags.encode({:object_identifier, identifier})
    end
  end

  test "encode object identifier integer object type" do
    assert {:ok, <<196, 1, 64, 0, 1>>} =
             ApplicationTags.encode({:object_identifier, %ObjectIdentifier{type: 5, instance: 1}})
  end

  test "encode object identifier invalid object type" do
    assert {:error, :unknown_object_type} =
             ApplicationTags.encode(
               {:object_identifier, %ObjectIdentifier{type: -5, instance: 1}}
             )
  end

  test "encode tagged invalid tag num" do
    assert_raise ArgumentError, fn ->
      ApplicationTags.encode({:tagged, {256, <<0>>, 1}})
    end
  end

  test "encode constructed invalid tag num" do
    assert_raise ArgumentError, fn ->
      ApplicationTags.encode({:constructed, {256, {:null, nil}, 0}})
    end
  end

  test "encode rejects reserved and out-of-range context tag numbers" do
    for tag_number <- [-1, 255, 256] do
      assert_raise ArgumentError, fn ->
        ApplicationTags.encode({:tagged, {tag_number, <<0>>, 1}})
      end

      assert_raise ArgumentError, fn ->
        ApplicationTags.encode_value({:tagged, {tag_number, <<0>>, 1}})
      end

      assert_raise ArgumentError, fn ->
        ApplicationTags.encode({:constructed, {tag_number, [], 0}})
      end
    end
  end

  test "encode constructed data invalid nested" do
    assert {:error, :invalid_value} =
             ApplicationTags.encode({:constructed, {0, [null: nil, boolean: 0], 0}})
  end

  test "encode invalid constructed binary" do
    assert {:error, :invalid_constructed_term} =
             ApplicationTags.encode({:constructed, {0, <<0>>, 1}})
  end

  test "encode invalid constructed" do
    assert {:error, :invalid_constructed_term} = ApplicationTags.encode({:constructed, 0})
  end

  test "encode 2-byte length data" do
    assert {:ok, <<101, 254, 4, 0, 99, _rest::binary>>} =
             ApplicationTags.encode({:octet_string, :binary.copy(<<99>>, 1024)})
  end

  test "encode 4-byte length data" do
    assert {:ok, <<101, 255, 0, 1, 245, 92, 99, _rest::binary>>} =
             ApplicationTags.encode({:octet_string, :binary.copy(<<99>>, 128_348)})
  end

  # Due to code path purging in v1.15, ensure application is loaded
  if function_exported?(Mix, :ensure_application!, 1) do
    Mix.ensure_application!(:os_mon)
  end

  # Only start mem supervisor so we can get the memory data
  Application.put_env(:os_mon, :start_cpu_sup, false)
  Application.put_env(:os_mon, :start_disksup, false)
  Application.put_env(:os_mon, :start_os_sup, false)

  # Get amount of available system memory (for that we need :os_mon)
  if match?({:ok, _apps}, Application.ensure_all_started(:os_mon)) do
    sys_mem_data = :memsup.get_system_memory_data()

    # Temporarily disable logs
    old_level = Logger.level()
    Logger.configure(level: :none)

    # Stop the application, we don't need it anymore
    Application.stop(:os_mon)

    # Enable logs again
    Logger.configure(level: old_level)

    # Make sure the machine has at least 5 GB of system memory,
    # The binary consumes about 4GB of memory + the rest of the ERTS,
    # so this test only gets executed if the host machine has enough memory to handle the heat
    if Keyword.get(sys_mem_data, :total_memory, 0) > 1024 ** 3 * 5 do
      test "encode too long length data" do
        assert_raise ArgumentError, fn ->
          # Build the binary as lists over all schedulers instead of completely in one,
          # this improves performance depending on the amount of schedulers,
          # but a lot better than single core dependent
          # The performance of building iodata with a refc binary is a lot better,
          # than building a binary on each scheduler
          # While the binary will be LONGER than what we want, this is no problem,
          # as we can just trim it to what we need

          length = 4_294_967_296
          partial_binary = :binary.copy(<<97>>, 1_024)
          schedulers_count = System.schedulers_online()

          binary =
            length
            |> then(fn num ->
              per_scheduler = Integer.floor_div(num, schedulers_count)
              last_raise = num - per_scheduler * schedulers_count

              per_scheduler
              |> List.duplicate(schedulers_count)
              |> then(fn [hd | tl] ->
                [hd + last_raise | tl]
              end)
            end)
            |> Task.async_stream(
              &List.duplicate(partial_binary, trunc(ceil(&1 / 1_024))),
              max_concurrency: schedulers_count,
              ordered: false,
              timeout: :infinity
            )
            |> Enum.map(fn {:ok, val} -> val end)
            |> IO.iodata_to_binary()
            |> then(&:binary.part(&1, 0, length))

          ApplicationTags.encode({:octet_string, binary})
        end
      end
    else
      Logger.warning(
        "Skip ApplicationTags test \"encode too long length data\" " <>
          "due to system memory <5GB"
      )
    end
  else
    Logger.warning(
      "Skip ApplicationTags test \"encode too long length data\" " <>
        "due to :os_mon not available"
    )
  end

  test "encode_value constructed is not supported" do
    assert {:error, :constructed_unsupported} =
             ApplicationTags.encode_value({:constructed, {0, 0, 0}})
  end

  test "unfold primitive" do
    assert {:ok, {:real, +0.0}} = ApplicationTags.unfold_to_type(:real, {:real, 0.0})
  end

  test "unfold constructed" do
    assert {:ok, {:real, +0.0}} =
             ApplicationTags.unfold_to_type(:real, {:constructed, {0, {:real, +0.0}, 0}})
  end

  test "unfold constructed nested" do
    assert {:ok, {:real, +0.0}} =
             ApplicationTags.unfold_to_type(
               :real,
               {:constructed, {0, {:constructed, {16, {:real, +0.0}, 0}}, 0}}
             )
  end

  test "unfold tagged" do
    assert {:ok, {:real, +0.0}} =
             ApplicationTags.unfold_to_type(:real, {:tagged, {0, <<0, 0, 0, 0>>, 4}})
  end

  test "unfold tagged invalid" do
    assert {:error, :invalid_data} =
             ApplicationTags.unfold_to_type(:real, {:tagged, {0, <<0, 0, 0>>, 3}})
  end

  test "unfold tagged time rejects an invalid hundredth" do
    assert {:error, :invalid_data} =
             ApplicationTags.unfold_to_type(:time, {:tagged, {0, <<12, 0, 0, 200>>, 4}})
  end

  test "unfold tagged bitstring rejects an invalid unused-bit count" do
    assert {:error, :invalid_data} =
             ApplicationTags.unfold_to_type(:bitstring, {:tagged, {0, <<9, 0xFF>>, 2}})
  end

  test "unfold binary data to real" do
    assert {:ok, {:real, +0.0}} = ApplicationTags.unfold_to_type(:real, <<0, 0, 0, 0>>)
  end

  test "unfold binary invalid data" do
    assert {:error, :invalid_data} = ApplicationTags.unfold_to_type(:real, <<255>>)
  end

  test "unfold invalid data" do
    assert {:error, :unknown_tag_encoding} = ApplicationTags.unfold_to_type(:real, false)
  end

  test "create tag encoding/2 with boolean" do
    assert {:ok, {:tagged, {0, <<0>>, 1}}} =
             ApplicationTags.create_tag_encoding(0, {:boolean, false})
  end

  test "create tag encoding/2 with signed integer" do
    assert {:ok, {:tagged, {0, <<129>>, 1}}} =
             ApplicationTags.create_tag_encoding(0, {:signed_integer, -127})
  end

  test "create tag encoding/3 with boolean" do
    assert {:ok, {:tagged, {0, <<0>>, 1}}} =
             ApplicationTags.create_tag_encoding(0, :boolean, false)
  end

  test "create tag encoding/3 with signed integer" do
    assert {:ok, {:tagged, {0, <<129>>, 1}}} =
             ApplicationTags.create_tag_encoding(0, :signed_integer, -127)
  end

  test "valid int with 8bits" do
    assert true == ApplicationTags.valid_int?(0, 8)
    assert true == ApplicationTags.valid_int?(8, 8)
    assert true == ApplicationTags.valid_int?(-8, 8)
    assert true == ApplicationTags.valid_int?(255, 8)
    assert true == ApplicationTags.valid_int?(-128, 8)
    assert true == ApplicationTags.valid_int?(127, 8)
  end

  test "valid int with 8bits fails" do
    assert false == ApplicationTags.valid_int?(-129, 8)
    assert false == ApplicationTags.valid_int?(-256, 8)
    assert false == ApplicationTags.valid_int?(256, 8)
    assert false == ApplicationTags.valid_int?(-1024, 8)
    assert false == ApplicationTags.valid_int?(1024, 8)
  end

  test "valid int with 16bits" do
    assert true == ApplicationTags.valid_int?(0, 16)
    assert true == ApplicationTags.valid_int?(8, 16)
    assert true == ApplicationTags.valid_int?(-8, 16)
    assert true == ApplicationTags.valid_int?(32_767, 16)
    assert true == ApplicationTags.valid_int?(-32_768, 16)
    assert true == ApplicationTags.valid_int?(65_535, 16)
  end

  test "valid int with 16bits fails" do
    assert false == ApplicationTags.valid_int?(-32_800, 16)
    assert false == ApplicationTags.valid_int?(-65_535, 16)
    assert false == ApplicationTags.valid_int?(65_536, 16)
    assert false == ApplicationTags.valid_int?(-100_000, 16)
    assert false == ApplicationTags.valid_int?(100_000, 16)
  end

  test "valid int with 32bits" do
    assert true == ApplicationTags.valid_int?(0, 32)
    assert true == ApplicationTags.valid_int?(8, 32)
    assert true == ApplicationTags.valid_int?(-8, 32)
    assert true == ApplicationTags.valid_int?(2 ** 31 - 1, 32)
    assert true == ApplicationTags.valid_int?(-(2 ** 31), 32)
    assert true == ApplicationTags.valid_int?(2 ** 32 - 1, 32)
  end

  test "valid int with 32bits fails" do
    assert false == ApplicationTags.valid_int?(-(2 ** 32), 32)
    assert false == ApplicationTags.valid_int?(-(2 ** 31) - 1, 32)
    assert false == ApplicationTags.valid_int?(2 ** 32, 32)
    assert false == ApplicationTags.valid_int?(-(2 ** 33), 32)
    assert false == ApplicationTags.valid_int?(2 ** 33, 32)
  end

  test "valid int with 48bits" do
    assert true == ApplicationTags.valid_int?(0, 48)
    assert true == ApplicationTags.valid_int?(8, 48)
    assert true == ApplicationTags.valid_int?(-8, 48)
    assert true == ApplicationTags.valid_int?(2 ** 47 - 1, 48)
    assert true == ApplicationTags.valid_int?(-(2 ** 47), 48)
    assert true == ApplicationTags.valid_int?(2 ** 48 - 1, 48)
  end

  test "valid int with 48bits fails" do
    assert false == ApplicationTags.valid_int?(-(2 ** 48), 48)
    assert false == ApplicationTags.valid_int?(-(2 ** 47) - 1, 48)
    assert false == ApplicationTags.valid_int?(2 ** 48, 48)
    assert false == ApplicationTags.valid_int?(-(2 ** 49), 48)
    assert false == ApplicationTags.valid_int?(2 ** 49, 48)
  end

  test "valid int with 56bits" do
    assert true == ApplicationTags.valid_int?(0, 56)
    assert true == ApplicationTags.valid_int?(8, 56)
    assert true == ApplicationTags.valid_int?(-8, 56)
    assert true == ApplicationTags.valid_int?(2 ** 55 - 1, 56)
    assert true == ApplicationTags.valid_int?(-(2 ** 55), 56)
    assert true == ApplicationTags.valid_int?(2 ** 56 - 1, 56)
  end

  test "valid int with 56bits fails" do
    assert false == ApplicationTags.valid_int?(-(2 ** 56), 56)
    assert false == ApplicationTags.valid_int?(-(2 ** 55) - 1, 56)
    assert false == ApplicationTags.valid_int?(2 ** 56, 56)
    assert false == ApplicationTags.valid_int?(-(2 ** 57), 56)
    assert false == ApplicationTags.valid_int?(2 ** 57, 56)
  end

  test "valid int with 64bits" do
    assert true == ApplicationTags.valid_int?(0, 64)
    assert true == ApplicationTags.valid_int?(8, 64)
    assert true == ApplicationTags.valid_int?(-8, 64)
    assert true == ApplicationTags.valid_int?(2 ** 63 - 1, 64)
    assert true == ApplicationTags.valid_int?(-(2 ** 63), 64)
    assert true == ApplicationTags.valid_int?(2 ** 64 - 1, 64)
  end

  test "valid int with 64bits fails" do
    assert false == ApplicationTags.valid_int?(-(2 ** 64), 64)
    assert false == ApplicationTags.valid_int?(-(2 ** 63) - 1, 64)
    assert false == ApplicationTags.valid_int?(2 ** 64, 64)
    assert false == ApplicationTags.valid_int?(-(2 ** 65), 64)
    assert false == ApplicationTags.valid_int?(2 ** 65, 64)
  end
end
