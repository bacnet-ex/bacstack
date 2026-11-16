defmodule BACnet.Test.Protocol.SecureConnect.HubConnectionTest do
  use ExUnit.Case, async: true

  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetError
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.SecureConnect.HubConnection

  test "round-trips a connector record that includes the error and details" do
    value = connection(state: 1, error: error(), details: "websocket closed")

    assert {:ok, tags} = HubConnection.encode(value)
    assert [0, 1, 2, 3, 4] = indexes(tags)
    assert {:ok, {^value, []}} = HubConnection.parse(tags)
    assert {:ok, {^value, ^tags}} = HubConnection.parse(tags ++ tags)
  end

  test "omits an error that has not been reported and keeps a later detail tag" do
    quiet = connection(state: 0, error: nil, details: nil)
    explained = connection(state: 3, error: nil, details: "failover armed")

    assert {:ok, tags} = HubConnection.encode(quiet)
    assert [0, 1, 2] = indexes(tags)
    assert {:ok, {^quiet, []}} = HubConnection.parse(tags)

    assert {:ok, explained_tags} = HubConnection.encode(explained)
    assert [0, 1, 2, 4] = indexes(explained_tags)
    assert {:ok, {^explained, [:pending]}} = HubConnection.parse(explained_tags ++ [:pending])
  end

  test "preserves an unspecified disconnection timestamp" do
    value =
      connection(
        state: 0,
        disconnected_at: unspecified(),
        error: error(),
        details: nil
      )

    assert {:ok, tags} = HubConnection.encode(value)
    assert {:ok, {^value, []}} = HubConnection.parse(tags)
  end

  test "rejects incomplete connector records and invalid fields" do
    assert {:ok, [state, connected, disconnected]} =
             HubConnection.encode(connection(state: 2, error: nil, details: nil))

    assert {:error, :invalid_value} = HubConnection.encode(%{connection() | state: -1})
    assert {:error, :invalid_value} = HubConnection.encode(%{connection() | connected_at: nil})

    assert {:error, :invalid_value} =
             HubConnection.encode(%{connection() | disconnected_at: error()})

    assert {:error, :invalid_utf8_string} =
             HubConnection.encode(%{connection() | details: <<255>>})

    assert {:error, :invalid_tags} = HubConnection.parse([])
    assert {:error, :invalid_tags} = HubConnection.parse([state, connected])

    assert {:error, :invalid_tags} =
             HubConnection.parse([state, connected, {:constructed, {2, [], 0}}])

    assert {:error, :invalid_tags} =
             HubConnection.parse([{:constructed, {0, [], 0}}, connected, disconnected])

    assert {:error, _reason} =
             HubConnection.parse([state, connected, disconnected, {:tagged, {4, :bad, 1}}])
  end

  defp connection(overrides \\ []) do
    defaults = [
      state: 1,
      connected_at: timestamp(),
      disconnected_at: timestamp(),
      error: error(),
      details: nil
    ]

    struct!(HubConnection, Keyword.merge(defaults, overrides))
  end

  defp error(), do: %BACnetError{class: :communication, code: :websocket_error}

  defp timestamp() do
    %BACnetDateTime{
      date: %BACnetDate{year: 2024, month: 3, day: 4, weekday: 1},
      time: %BACnetTime{hour: 1, minute: 2, second: 3, hundredth: 4}
    }
  end

  defp unspecified() do
    %BACnetDateTime{
      date: %BACnetDate{
        year: :unspecified,
        month: :unspecified,
        day: :unspecified,
        weekday: :unspecified
      },
      time: %BACnetTime{
        hour: :unspecified,
        minute: :unspecified,
        second: :unspecified,
        hundredth: :unspecified
      }
    }
  end

  defp indexes(tags) do
    Enum.map(tags, fn {_kind, {index, _body, _length}} -> index end)
  end
end
