defmodule BACnet.InternalTest do
  alias BACnet.Internal

  use ExUnit.Case, async: true

  @moduletag :internal

  doctest Internal

  test_data = [
    {"bitstring F", {false}, 0},
    {"bitstring T", {true}, 1},
    {"bitstring FTT", {false, true, true}, 6},
    {"bitstring TTF", {true, true, false}, 3},
    {"bitstring FFFT", {false, false, false, true}, 8},
    {"bitstring FTFT", {false, true, false, true}, 10},
    {"bitstring FFFFFFFF", {false, false, false, false, false, false, false, false}, 0},
    {"bitstring FTFFTFFT", {false, true, false, false, true, false, false, true}, 146}
  ]

  for {description, encode_data, decode_data} <- test_data do
    test "tuple to int #{description}" do
      assert unquote(decode_data) == Internal.tuple_to_int(unquote(Macro.escape(encode_data)))
    end
  end
end
