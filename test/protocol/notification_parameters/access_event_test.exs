defmodule BACnet.Protocol.NotificationParameters.AccessEventTest do
  alias BACnet.Protocol.NotificationParameters

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  test "decode unsupported" do
    assert {:error, :not_supported_notification_type} =
             NotificationParameters.parse({:constructed, {13, [], 0}})
  end
end
