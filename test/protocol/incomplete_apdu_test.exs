defmodule BACnet.Protocol.IncompleteAPDUTest do
  alias BACnet.Protocol.IncompleteAPDU

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest IncompleteAPDU

  test "set window size" do
    incomplete = %IncompleteAPDU{
      header: <<>>,
      server: true,
      invoke_id: 1,
      sequence_number: 0,
      window_size: 15,
      more_follows: false,
      data: <<0, 1, 2, 3>>
    }

    assert %IncompleteAPDU{
             header: <<>>,
             server: true,
             invoke_id: 1,
             sequence_number: 0,
             window_size: 4,
             more_follows: false,
             data: <<0, 1, 2, 3>>
           } = IncompleteAPDU.set_window_size(incomplete, 4)

    assert_raise FunctionClauseError, fn ->
      IncompleteAPDU.set_window_size(incomplete, 0)
    end

    assert_raise FunctionClauseError, fn ->
      IncompleteAPDU.set_window_size(incomplete, -1)
    end
  end
end
