defmodule BACnet.Test.Protocol.ObjectTypes.EventLogTest do
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.ObjectTypes.EventLog

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_event_log

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "verify create/4 adds Log_Buffer for remote objects" do
    assert {:ok, %EventLog{log_buffer: []}} =
             EventLog.create(
               1,
               "TEST",
               %{
                 buffer_size: 100,
                 enable: false,
                 event_state: :normal,
                 record_count: 0,
                 total_record_count: 0,
                 stop_when_full: false,
                 start_time: ObjectsMacro.get_default_bacnet_datetime(),
                 stop_time: ObjectsMacro.get_default_bacnet_datetime(),
                 status_flags:
                   BACnet.Protocol.StatusFlags.from_bitstring({false, false, false, false})
               },
               remote_object: 1
             )
  end
end
