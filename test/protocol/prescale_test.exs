defmodule BACnet.Protocol.PrescaleTest do
  alias BACnet.Protocol.Prescale

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest Prescale

  test "decode prescale" do
    assert {:ok,
            {%Prescale{
               multiplier: 0,
               modulo_divide: 250
             }, []}} = Prescale.parse(tagged: {0, <<0>>, 1}, tagged: {1, <<250>>, 1})
  end

  test "decode invalid prescale missing pattern" do
    assert {:error, :invalid_tags} = Prescale.parse(tagged: {0, <<0>>, 1})
  end

  test "decode invalid prescale invalid data" do
    assert {:error, :invalid_data} = Prescale.parse(tagged: {0, <<0>>, 1}, tagged: {1, <<>>, 1})
  end

  test "encode prescale" do
    assert {:ok, [tagged: {0, <<0>>, 1}, tagged: {1, <<250>>, 1}]} =
             Prescale.encode(%Prescale{
               multiplier: 0,
               modulo_divide: 250
             })
  end

  test "encode invalid prescale" do
    assert {:error, :invalid_value} =
             Prescale.encode(%Prescale{
               multiplier: -5,
               modulo_divide: 250
             })
  end

  test "valid prescale" do
    assert true ==
             Prescale.valid?(%Prescale{
               multiplier: 0,
               modulo_divide: 250
             })

    assert true ==
             Prescale.valid?(%Prescale{
               multiplier: 1,
               modulo_divide: 250_000
             })

    assert true ==
             Prescale.valid?(%Prescale{
               multiplier: 250_000,
               modulo_divide: 1
             })
  end

  test "invalid prescale" do
    assert false ==
             Prescale.valid?(%Prescale{
               multiplier: :hello,
               modulo_divide: 1
             })

    assert false ==
             Prescale.valid?(%Prescale{
               multiplier: 1,
               modulo_divide: :hello
             })

    assert false ==
             Prescale.valid?(%Prescale{
               multiplier: -1,
               modulo_divide: 250
             })

    assert false ==
             Prescale.valid?(%Prescale{
               multiplier: 1,
               modulo_divide: -1
             })
  end
end
