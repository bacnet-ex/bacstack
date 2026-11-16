defmodule BACnet.Test.Protocol.SecureConnect.StatusSequencesTest do
  use ExUnit.Case, async: true

  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetError
  alias BACnet.Protocol.HostNPort
  alias BACnet.Protocol.SecureConnect.FailedConnectionRequest
  alias BACnet.Protocol.SecureConnect.Health
  alias BACnet.Protocol.SecureConnect.HubConnection
  alias BACnet.Protocol.SecureConnect.HubFunctionConnection

  test "status sequences consume their own tags and retain the next record" do
    timestamp = BACnetDateTime.utc_now()
    error = %BACnetError{class: :communication, code: :websocket_error}
    address = %HostNPort{host: {:ip_address, {127, 0, 0, 1}}, port: 443}

    for {module, fields} <- [
          {FailedConnectionRequest,
           [
             timestamp: timestamp,
             error: error,
             address: address,
             vmac: <<1::size(48)>>,
             uuid: <<2::size(128)>>,
             details: nil
           ]},
          {Health,
           [timestamp: timestamp, result: error, property: :sc_primary_hub_uri, details: "test"]},
          {HubConnection,
           [
             state: 1,
             connected_at: timestamp,
             disconnected_at: timestamp,
             error: error,
             details: nil
           ]},
          {HubFunctionConnection,
           [
             state: 1,
             connected_at: timestamp,
             disconnected_at: timestamp,
             address: address,
             vmac: <<1::size(48)>>,
             uuid: <<2::size(128)>>,
             error: nil,
             details: nil
           ]}
        ] do
      value = struct!(module, fields)
      assert {:ok, tags} = module.encode(value)
      assert {:ok, {^value, ^tags}} = module.parse(tags ++ tags)
      assert {:error, :invalid_tags} = module.parse([])
    end
  end

  test "health handles absent optional tags, numeric properties, and invalid constructed values" do
    value = %Health{
      timestamp: BACnetDateTime.utc_now(),
      result: %BACnetError{class: :services, code: :success},
      property: nil,
      details: nil
    }

    assert {:ok, [timestamp, error]} = Health.encode(value)
    assert {:ok, {^value, []}} = Health.parse([timestamp, error])
    assert {:ok, tags} = Health.encode(%{value | property: 9876})
    assert {:ok, {%Health{property: 9876}, []}} = Health.parse(tags)
    assert {:error, :invalid_value} = Health.encode(%{value | timestamp: nil})
    assert {:error, :invalid_tags} = Health.parse([timestamp, {:constructed, {1, [], 0}}])
    assert {:error, _reason} = Health.parse([timestamp, error, {:tagged, {2, <<>>, 0}}])
  end
end
