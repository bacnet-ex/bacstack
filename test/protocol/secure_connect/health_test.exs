defmodule BACnet.Test.Protocol.SecureConnect.HealthTest do
  use ExUnit.Case, async: true

  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetError
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.SecureConnect.Health

  test "round-trips a validation result with a named property and details" do
    value = health(property: :sc_primary_hub_uri, details: "uri missing")

    assert {:ok, tags} = Health.encode(value)
    assert [0, 1, 2, 3] = indexes(tags)
    assert {:ok, {^value, []}} = Health.parse(tags)
    assert {:ok, {^value, ^tags}} = Health.parse(tags ++ tags)
  end

  test "omits an absent property without renumbering the details" do
    absent = health(property: nil, details: nil)
    details_only = health(property: nil, details: "")

    assert {:ok, [timestamp, result]} = Health.encode(absent)
    assert {:constructed, {0, _timestamp, _timestamp_length}} = timestamp
    assert {:constructed, {1, _result, _result_length}} = result
    assert {:ok, {^absent, []}} = Health.parse([timestamp, result])

    assert {:ok, detail_tags} = Health.encode(details_only)
    assert [0, 1, 3] = indexes(detail_tags)
    assert {:ok, {^details_only, [:next]}} = Health.parse(detail_tags ++ [:next])
  end

  test "preserves an unknown property number and resolves a known one" do
    unknown = health(property: 9876, details: nil)
    assert {:ok, unknown_tags} = Health.encode(unknown)
    assert {:ok, {^unknown, []}} = Health.parse(unknown_tags)

    numeric = health(property: 4_194_325, details: "check")
    named = health(property: :sc_primary_hub_uri, details: "check")

    assert {:ok, numeric_tags} = Health.encode(numeric)
    assert {:ok, named_tags} = Health.encode(named)
    assert numeric_tags == named_tags
    assert {:ok, {^named, []}} = Health.parse(numeric_tags)
  end

  test "rejects incomplete observations and invalid fields" do
    value = health(property: nil, details: nil)
    assert {:ok, [timestamp, result]} = Health.encode(value)

    assert {:error, :invalid_value} = Health.encode(%{value | timestamp: nil})
    assert {:error, :invalid_value} = Health.encode(%{value | result: :ok})
    assert {:error, :invalid_value} = Health.encode(%{value | property: "object_name"})
    assert {:error, :invalid_utf8_string} = Health.encode(%{value | details: <<255>>})

    assert {:error, :invalid_tags} = Health.parse([])
    assert {:error, :invalid_tags} = Health.parse([timestamp])
    assert {:error, :invalid_tags} = Health.parse([timestamp, {:constructed, {1, [], 0}}])
    assert {:error, :invalid_tags} = Health.parse([{:enumerated, 1}, result])

    assert {:error, _reason} = Health.parse([timestamp, result, {:tagged, {2, <<>>, 0}}])

    assert {:error, _reason} =
             Health.parse([timestamp, result, {:tagged, {2, :not_binary, 1}}])
  end

  defp health(overrides) do
    defaults = [
      timestamp: timestamp(),
      result: %BACnetError{class: :services, code: :success},
      property: :sc_primary_hub_uri,
      details: nil
    ]

    struct!(Health, Keyword.merge(defaults, overrides))
  end

  defp timestamp() do
    %BACnetDateTime{
      date: %BACnetDate{year: 2024, month: 6, day: 15, weekday: 6},
      time: %BACnetTime{hour: 12, minute: 0, second: 1, hundredth: 5}
    }
  end

  defp indexes(tags) do
    Enum.map(tags, fn {_kind, {index, _body, _length}} -> index end)
  end
end
