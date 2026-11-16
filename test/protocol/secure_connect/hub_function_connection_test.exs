defmodule BACnet.Test.Protocol.SecureConnect.HubFunctionConnectionTest do
  use ExUnit.Case, async: true

  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetError
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.HostNPort
  alias BACnet.Protocol.SecureConnect.HubFunctionConnection

  test "round-trips an accepted peer session" do
    value = session(error: error(), details: "peer disconnected")

    assert {:ok, tags} = HubFunctionConnection.encode(value)
    assert [0, 1, 2, 3, 4, 5, 6, 7] = indexes(tags)
    assert {:ok, {^value, []}} = HubFunctionConnection.parse(tags)
    assert {:ok, {^value, ^tags}} = HubFunctionConnection.parse(tags ++ tags)
  end

  test "omits an absent error without renumbering the details" do
    quiet = session(state: 0, error: nil, details: nil)
    explained = session(state: 2, error: nil, details: "")

    assert {:ok, tags} = HubFunctionConnection.encode(quiet)
    assert [0, 1, 2, 3, 4, 5] = indexes(tags)
    assert {:ok, {^quiet, []}} = HubFunctionConnection.parse(tags)

    assert {:ok, explained_tags} = HubFunctionConnection.encode(explained)
    assert [0, 1, 2, 3, 4, 5, 7] = indexes(explained_tags)

    assert {:ok, {^explained, [:next]}} =
             HubFunctionConnection.parse(explained_tags ++ [:next])
  end

  test "requires the peer address and identity" do
    value = session()

    assert {:error, :invalid_value} = HubFunctionConnection.encode(%{value | address: nil})
    assert {:error, :invalid_value} = HubFunctionConnection.encode(%{value | vmac: nil})
    assert {:error, :invalid_value} = HubFunctionConnection.encode(%{value | uuid: nil})
    assert {:error, :invalid_value} = HubFunctionConnection.encode(%{value | state: -1})
    assert {:error, :invalid_value} = HubFunctionConnection.encode(%{value | connected_at: nil})

    assert {:error, :invalid_value} =
             HubFunctionConnection.encode(%{value | disconnected_at: error()})

    assert {:error, :invalid_utf8_string} =
             HubFunctionConnection.encode(%{value | details: <<255>>})
  end

  test "rejects tags that do not form one complete session" do
    assert {:ok, tags} = HubFunctionConnection.encode(session(error: nil, details: nil))
    [state, connected, disconnected, address, vmac_tag, uuid_tag] = tags

    assert {:error, :invalid_tags} = HubFunctionConnection.parse([])
    assert {:error, :invalid_tags} = HubFunctionConnection.parse([state, connected, disconnected])

    assert {:error, :invalid_tags} =
             HubFunctionConnection.parse([
               state,
               connected,
               disconnected,
               {:constructed, {3, [], 0}},
               vmac_tag,
               uuid_tag
             ])

    assert {:error, :unknown_tag_encoding} =
             HubFunctionConnection.parse([
               state,
               connected,
               disconnected,
               address,
               {:tagged, {4, :bad, 1}},
               uuid_tag
             ])

    assert {:error, _reason} =
             HubFunctionConnection.parse(tags ++ [{:tagged, {7, :bad, 1}}])

    assert {:tagged, {4, _vmac, _vmac_length}} = vmac_tag
  end

  defp session(overrides \\ []) do
    defaults = [
      state: 1,
      connected_at: timestamp(),
      disconnected_at: timestamp(),
      address: %HostNPort{host: {:name, "hub.example"}, port: 443},
      vmac: <<9, 8, 7, 6, 5, 4>>,
      uuid: <<16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1>>,
      error: nil,
      details: nil
    ]

    struct!(HubFunctionConnection, Keyword.merge(defaults, overrides))
  end

  defp error(), do: %BACnetError{class: :communication, code: :websocket_error}

  defp timestamp() do
    %BACnetDateTime{
      date: %BACnetDate{year: 2025, month: 11, day: 2, weekday: 7},
      time: %BACnetTime{hour: 23, minute: 59, second: 58, hundredth: 7}
    }
  end

  defp indexes(tags) do
    Enum.map(tags, fn {_kind, {index, _body, _length}} -> index end)
  end
end
