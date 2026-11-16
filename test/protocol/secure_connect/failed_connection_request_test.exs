defmodule BACnet.Test.Protocol.SecureConnect.FailedConnectionRequestTest do
  use ExUnit.Case, async: true

  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetError
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.HostNPort
  alias BACnet.Protocol.SecureConnect.FailedConnectionRequest

  test "round-trips a failure that includes the peer identity and details" do
    value = request(vmac: vmac(), uuid: uuid(), details: "certificate rejected")

    assert {:ok, tags} = FailedConnectionRequest.encode(value)
    assert [0, 1, 2, 3, 4, 5] = indexes(tags)
    assert {:ok, {^value, []}} = FailedConnectionRequest.parse(tags)
    assert {:ok, {^value, ^tags}} = FailedConnectionRequest.parse(tags ++ tags)
  end

  test "omits optional identity and detail fields independently" do
    vmac_only = request(vmac: vmac(), uuid: nil, details: nil)
    uuid_only = request(vmac: nil, uuid: uuid(), details: "reset")
    neither = request(vmac: nil, uuid: nil, details: nil)
    named = request(address: %HostNPort{host: :none, port: 0}, vmac: nil, uuid: nil, details: "")

    assert {:ok, vmac_tags} = FailedConnectionRequest.encode(vmac_only)
    assert [_timestamp, _address, vmac_tag, error_tag] = vmac_tags
    assert {:tagged, {2, _vmac, _vmac_length}} = vmac_tag
    assert {:constructed, {4, _error, _error_length}} = error_tag
    assert {:ok, {^vmac_only, []}} = FailedConnectionRequest.parse(vmac_tags)

    assert {:ok, uuid_tags} = FailedConnectionRequest.encode(uuid_only)
    assert [0, 1, 3, 4, 5] = indexes(uuid_tags)
    assert {:ok, {^uuid_only, []}} = FailedConnectionRequest.parse(uuid_tags)

    assert {:ok, bare_tags} = FailedConnectionRequest.encode(neither)
    assert [0, 1, 4] = indexes(bare_tags)

    assert {:ok, {^neither, [:leftover]}} =
             FailedConnectionRequest.parse(bare_tags ++ [:leftover])

    assert {:ok, named_tags} = FailedConnectionRequest.encode(named)
    assert [0, 1, 4, 5] = indexes(named_tags)
    assert {:ok, {^named, []}} = FailedConnectionRequest.parse(named_tags)
  end

  test "rejects values and tags that are not a complete failure record" do
    {:ok, [timestamp, address, error]} =
      FailedConnectionRequest.encode(request(vmac: nil, uuid: nil, details: nil))

    assert {:error, :invalid_value} =
             FailedConnectionRequest.encode(%{request() | timestamp: nil})

    assert {:error, :invalid_value} = FailedConnectionRequest.encode(%{request() | address: nil})
    assert {:error, :invalid_value} = FailedConnectionRequest.encode(%{request() | error: nil})

    assert {:error, :invalid_value} =
             FailedConnectionRequest.encode(%{request() | vmac: :missing})

    assert {:error, :invalid_utf8_string} =
             FailedConnectionRequest.encode(%{request() | details: <<255>>})

    assert {:error, :invalid_tags} = FailedConnectionRequest.parse([])
    assert {:error, :invalid_tags} = FailedConnectionRequest.parse([timestamp])
    assert {:error, :invalid_tags} = FailedConnectionRequest.parse([timestamp, address])

    assert {:error, :invalid_tags} =
             FailedConnectionRequest.parse([timestamp, address, {:constructed, {4, [], 0}}])

    assert {:error, :invalid_tags} =
             FailedConnectionRequest.parse([timestamp, address, {:tagged, {5, <<0, "x">>, 2}}])

    assert {:error, _reason} =
             FailedConnectionRequest.parse([timestamp, address, error, {:tagged, {5, :bad, 1}}])
  end

  defp request(overrides \\ []) do
    defaults = [
      timestamp: timestamp(),
      address: %HostNPort{host: {:ip_address, {192, 168, 1, 20}}, port: 47_808},
      vmac: vmac(),
      uuid: uuid(),
      error: %BACnetError{class: :communication, code: :websocket_error},
      details: nil
    ]

    struct!(FailedConnectionRequest, Keyword.merge(defaults, overrides))
  end

  defp timestamp() do
    %BACnetDateTime{
      date: %BACnetDate{year: 2024, month: 1, day: 3, weekday: 3},
      time: %BACnetTime{hour: 8, minute: 30, second: 0, hundredth: 0}
    }
  end

  defp indexes(tags) do
    Enum.map(tags, fn {_kind, {index, _body, _length}} -> index end)
  end

  defp vmac(), do: <<1, 2, 3, 4, 5, 6>>
  defp uuid(), do: <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>
end
