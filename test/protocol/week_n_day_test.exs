defmodule BACnet.Protocol.WeekNDayTest do
  alias BACnet.Protocol.WeekNDay

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest WeekNDay

  test "decode week n day" do
    assert {:ok,
            {%WeekNDay{
               month: 1,
               week_of_month: 4,
               weekday: 3
             }, []}} = WeekNDay.parse(octet_string: <<1, 4, 3>>)
  end

  test "decode week n day with odd month and unspecified week of month" do
    assert {:ok,
            {%WeekNDay{
               month: :odd,
               week_of_month: :unspecified,
               weekday: 1
             }, []}} = WeekNDay.parse(octet_string: <<13, 255, 1>>)
  end

  test "decode week n day with even month and unspecified weekday" do
    assert {:ok,
            {%WeekNDay{
               month: :even,
               week_of_month: 2,
               weekday: :unspecified
             }, []}} = WeekNDay.parse(octet_string: <<14, 2, 255>>)
  end

  test "decode week n day with unspecified month" do
    assert {:ok,
            {%WeekNDay{
               month: :unspecified,
               week_of_month: 6,
               weekday: 7
             }, []}} = WeekNDay.parse(octet_string: <<255, 6, 7>>)
  end

  test "decode week n day with month out of range" do
    assert {:error, :invalid_tags} = WeekNDay.parse(octet_string: <<15, 6, 7>>)
  end

  test "decode week n day with week of month out of range" do
    assert {:error, :invalid_tags} = WeekNDay.parse(octet_string: <<1, 7, 7>>)
  end

  test "decode week n day with weekday out of range" do
    assert {:error, :invalid_tags} = WeekNDay.parse(octet_string: <<1, 6, 8>>)
  end

  test "encode week n day" do
    assert {:ok, [octet_string: <<1, 4, 3>>]} =
             WeekNDay.encode(%WeekNDay{
               month: 1,
               week_of_month: 4,
               weekday: 3
             })
  end

  test "encode week n day with odd month and unspecified week of month" do
    assert {:ok, [octet_string: <<13, 255, 1>>]} =
             WeekNDay.encode(%WeekNDay{
               month: :odd,
               week_of_month: :unspecified,
               weekday: 1
             })
  end

  test "encode week n day with even month and unspecified weekday" do
    assert {:ok, [octet_string: <<14, 2, 255>>]} =
             WeekNDay.encode(%WeekNDay{
               month: :even,
               week_of_month: 2,
               weekday: :unspecified
             })
  end

  test "encode week n day with unspecified month" do
    assert {:ok, [octet_string: <<255, 6, 7>>]} =
             WeekNDay.encode(%WeekNDay{
               month: :unspecified,
               week_of_month: 6,
               weekday: 7
             })
  end

  test "valid week n day" do
    for month <- 1..12, wom <- 1..6, weekday <- 1..7 do
      assert true ==
               WeekNDay.valid?(%WeekNDay{
                 month: month,
                 week_of_month: wom,
                 weekday: weekday
               })
    end

    assert true ==
             WeekNDay.valid?(%WeekNDay{
               month: :odd,
               week_of_month: 6,
               weekday: 7
             })

    assert true ==
             WeekNDay.valid?(%WeekNDay{
               month: :even,
               week_of_month: 6,
               weekday: 7
             })

    assert true ==
             WeekNDay.valid?(%WeekNDay{
               month: :unspecified,
               week_of_month: 6,
               weekday: 7
             })

    assert true ==
             WeekNDay.valid?(%WeekNDay{
               month: 12,
               week_of_month: :unspecified,
               weekday: 7
             })

    assert true ==
             WeekNDay.valid?(%WeekNDay{
               month: 12,
               week_of_month: 6,
               weekday: :unspecified
             })

    assert true ==
             WeekNDay.valid?(%WeekNDay{
               month: :unspecified,
               week_of_month: :unspecified,
               weekday: :unspecified
             })
  end

  test "invalid week n day" do
    assert false ==
             WeekNDay.valid?(%WeekNDay{
               month: 13,
               week_of_month: 6,
               weekday: 7
             })

    assert false ==
             WeekNDay.valid?(%WeekNDay{
               month: 14,
               week_of_month: 6,
               weekday: 7
             })

    assert false ==
             WeekNDay.valid?(%WeekNDay{
               month: :hello_there,
               week_of_month: 6,
               weekday: 7
             })

    assert false ==
             WeekNDay.valid?(%WeekNDay{
               month: 12,
               week_of_month: 7,
               weekday: 7
             })

    assert false ==
             WeekNDay.valid?(%WeekNDay{
               month: 12,
               week_of_month: -1,
               weekday: 7
             })

    assert false ==
             WeekNDay.valid?(%WeekNDay{
               month: 12,
               week_of_month: 0,
               weekday: 7
             })

    assert false ==
             WeekNDay.valid?(%WeekNDay{
               month: 12,
               week_of_month: :hello_there,
               weekday: 7
             })

    assert false ==
             WeekNDay.valid?(%WeekNDay{
               month: 12,
               week_of_month: 6,
               weekday: 8
             })

    assert false ==
             WeekNDay.valid?(%WeekNDay{
               month: 12,
               week_of_month: 6,
               weekday: -1
             })

    assert false ==
             WeekNDay.valid?(%WeekNDay{
               month: 12,
               week_of_month: 6,
               weekday: 0
             })

    assert false ==
             WeekNDay.valid?(%WeekNDay{
               month: 12,
               week_of_month: 6,
               weekday: :hello_there
             })
  end
end
