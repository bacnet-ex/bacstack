defmodule BACnet.Protocol.DateRangeTest do
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.DateRange

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest DateRange

  defmacrop inline_call(exec) do
    {value, _bind} = Code.eval_quoted(exec, [], __CALLER__)

    quote generated: true do
      unquote(Macro.escape(value))
    end
  end

  test "get date range (elixir)" do
    assert {:ok, inline_call(Date.range(~D[2023-05-05], ~D[2023-05-20]))} =
             DateRange.get_date_range(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 5,
                 weekday: 5
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 20,
                 weekday: 6
               }
             })

    assert {:ok, inline_call(Date.range(~D[2023-05-05], ~D[2023-05-20]))} =
             DateRange.get_date_range(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 5,
                 weekday: :unspecified
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 20,
                 weekday: :unspecified
               }
             })
  end

  test "get date range (elixir) fails due to unspecific date" do
    assert {:error, :invalid_date_range} =
             DateRange.get_date_range(%DateRange{
               start_date: %BACnetDate{
                 year: :unspecified,
                 month: 5,
                 day: 5,
                 weekday: 1
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 20,
                 weekday: 6
               }
             })

    assert {:error, :invalid_date_range} =
             DateRange.get_date_range(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: :unspecified,
                 day: 5,
                 weekday: 1
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 20,
                 weekday: 6
               }
             })

    assert {:error, :invalid_date_range} =
             DateRange.get_date_range(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: :unspecified,
                 weekday: 1
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 20,
                 weekday: 6
               }
             })

    assert {:error, :invalid_date_range} =
             DateRange.get_date_range(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 5,
                 weekday: 1
               },
               end_date: %BACnetDate{
                 year: :unspecified,
                 month: 5,
                 day: 20,
                 weekday: 6
               }
             })

    assert {:error, :invalid_date_range} =
             DateRange.get_date_range(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 5,
                 weekday: 1
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: :unspecified,
                 day: 20,
                 weekday: 6
               }
             })

    assert {:error, :invalid_date_range} =
             DateRange.get_date_range(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 5,
                 weekday: 1
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: :unspecified,
                 weekday: 6
               }
             })
  end

  test "get date range (elixir) fails due to odd date" do
    assert {:error, :invalid_date_range} =
             DateRange.get_date_range(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: :odd,
                 day: 5,
                 weekday: 1
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 20,
                 weekday: 6
               }
             })

    assert {:error, :invalid_date_range} =
             DateRange.get_date_range(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: :odd,
                 weekday: 1
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 20,
                 weekday: 6
               }
             })

    assert {:error, :invalid_date_range} =
             DateRange.get_date_range(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 5,
                 weekday: 1
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: :odd,
                 day: 20,
                 weekday: 6
               }
             })

    assert {:error, :invalid_date_range} =
             DateRange.get_date_range(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 5,
                 weekday: 1
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: :odd,
                 weekday: 6
               }
             })
  end

  test "get date range (elixir) fails due to even date" do
    assert {:error, :invalid_date_range} =
             DateRange.get_date_range(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: :even,
                 day: 5,
                 weekday: 1
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 20,
                 weekday: 6
               }
             })

    assert {:error, :invalid_date_range} =
             DateRange.get_date_range(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: :even,
                 weekday: 1
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 20,
                 weekday: 6
               }
             })

    assert {:error, :invalid_date_range} =
             DateRange.get_date_range(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 5,
                 weekday: 1
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: :even,
                 day: 20,
                 weekday: 6
               }
             })

    assert {:error, :invalid_date_range} =
             DateRange.get_date_range(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 5,
                 weekday: 1
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: :even,
                 weekday: 6
               }
             })
  end

  test "get date range (elixir) works with \"last day\" date" do
    assert {:ok, inline_call(Date.range(~D[2023-05-31], ~D[2023-06-20]))} =
             DateRange.get_date_range(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: :last,
                 weekday: 1
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 6,
                 day: 20,
                 weekday: 6
               }
             })

    assert {:ok, inline_call(Date.range(~D[2023-05-05], ~D[2023-05-31]))} =
             DateRange.get_date_range(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 5,
                 weekday: 1
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: :last,
                 weekday: 6
               }
             })
  end

  test "decode date range" do
    assert {:ok,
            {%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 5,
                 weekday: 5
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 20,
                 weekday: 6
               }
             },
             []}} =
             DateRange.parse(
               date: %BACnetDate{year: 2023, month: 5, day: 5, weekday: 5},
               date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 20,
                 weekday: 6
               }
             )
  end

  test "decode invalid date range" do
    assert {:error, :invalid_tags} =
             DateRange.parse(date: %BACnetDate{year: 2023, month: 5, day: 5, weekday: 5})
  end

  test "encode date range" do
    assert {:ok,
            [
              date: %BACnetDate{year: 2023, month: 5, day: 5, weekday: 5},
              date: %BACnetDate{
                year: 2023,
                month: 5,
                day: 20,
                weekday: 6
              }
            ]} =
             DateRange.encode(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 5,
                 weekday: 5
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 20,
                 weekday: 6
               }
             })
  end

  test "valid date range" do
    assert true ==
             DateRange.valid?(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 5,
                 weekday: 5
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 20,
                 weekday: 6
               }
             })

    assert true ==
             DateRange.valid?(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 4,
                 day: :last,
                 weekday: 5
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 30,
                 weekday: 6
               }
             })

    assert true ==
             DateRange.valid?(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 5,
                 weekday: 5
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: :last,
                 weekday: 6
               }
             })

    assert true ==
             DateRange.valid?(%DateRange{
               start_date: %BACnetDate{
                 year: :unspecified,
                 month: :unspecified,
                 day: :unspecified,
                 weekday: :unspecified
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 20,
                 weekday: 6
               }
             })

    assert true ==
             DateRange.valid?(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 20,
                 weekday: 6
               },
               end_date: %BACnetDate{
                 year: :unspecified,
                 month: :unspecified,
                 day: :unspecified,
                 weekday: :unspecified
               }
             })
  end

  test "invalid date range" do
    assert false ==
             DateRange.valid?(%DateRange{
               start_date: :hello,
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 20,
                 weekday: 6
               }
             })

    assert false ==
             DateRange.valid?(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 20,
                 weekday: 6
               },
               end_date: :hello
             })

    assert false ==
             DateRange.valid?(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: :even,
                 day: 20,
                 weekday: 6
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 20,
                 weekday: 6
               }
             })

    assert false ==
             DateRange.valid?(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: :odd,
                 day: 20,
                 weekday: 6
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 20,
                 weekday: 6
               }
             })

    assert false ==
             DateRange.valid?(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 20,
                 weekday: 6
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: :even,
                 day: 20,
                 weekday: 6
               }
             })

    assert false ==
             DateRange.valid?(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 20,
                 weekday: 6
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: :odd,
                 day: 20,
                 weekday: 6
               }
             })

    assert false ==
             DateRange.valid?(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: :even,
                 weekday: 5
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 30,
                 weekday: 6
               }
             })

    assert false ==
             DateRange.valid?(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: :odd,
                 weekday: 5
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 30,
                 weekday: 6
               }
             })

    assert false ==
             DateRange.valid?(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 4,
                 day: 1,
                 weekday: 5
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: :even,
                 weekday: 6
               }
             })

    assert false ==
             DateRange.valid?(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 4,
                 day: 1,
                 weekday: 5
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: :odd,
                 weekday: 6
               }
             })

    assert false ==
             DateRange.valid?(%DateRange{
               start_date: %BACnetDate{
                 year: :unspecified,
                 month: 5,
                 day: 1,
                 weekday: 5
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 30,
                 weekday: 6
               }
             })

    assert false ==
             DateRange.valid?(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: :unspecified,
                 day: 1,
                 weekday: 5
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 30,
                 weekday: 6
               }
             })

    assert false ==
             DateRange.valid?(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: :unspecified,
                 weekday: 5
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 30,
                 weekday: 6
               }
             })

    assert false ==
             DateRange.valid?(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 1,
                 day: 1,
                 weekday: :unspecified
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 30,
                 weekday: 6
               }
             })

    assert false ==
             DateRange.valid?(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 4,
                 day: 1,
                 weekday: 5
               },
               end_date: %BACnetDate{
                 year: :unspecified,
                 month: 5,
                 day: 30,
                 weekday: 6
               }
             })

    assert false ==
             DateRange.valid?(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 4,
                 day: 1,
                 weekday: 5
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: :unspecified,
                 weekday: 6
               }
             })

    assert false ==
             DateRange.valid?(%DateRange{
               start_date: %BACnetDate{
                 year: 2023,
                 month: 4,
                 day: 1,
                 weekday: 5
               },
               end_date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 30,
                 weekday: :unspecified
               }
             })
  end
end
