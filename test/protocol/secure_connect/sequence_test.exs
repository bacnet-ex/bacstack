defmodule BACnet.Test.Protocol.SecureConnect.SequenceTest do
  use ExUnit.Case, async: true

  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetError
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.HostNPort
  alias BACnet.Protocol.SecureConnect.Sequence

  defmodule Record do
    @moduledoc false

    defstruct [
      :address,
      :details,
      :error,
      :name,
      :property,
      :raw,
      :seen_at,
      :state,
      :timestamp
    ]
  end

  test "encodes constructed fields and returns the tags of the next record" do
    fields = [
      timestamp: BACnetDateTime,
      error: BACnetError,
      address: HostNPort,
      state: :enumerated
    ]

    value = record(timestamp: timestamp(), error: error(), address: address(), state: 1)

    assert {:ok, tags} = Sequence.encode(value, fields)
    assert [0, 1, 2, 3] = indexes(tags)
    assert {:constructed, {0, _timestamp, 0}} = Enum.at(tags, 0)
    assert {:constructed, {1, _error, 0}} = Enum.at(tags, 1)
    assert {:constructed, {2, _address, 0}} = Enum.at(tags, 2)
    assert {:ok, {^value, []}} = Sequence.parse(Record, tags, fields)
    assert {:ok, {^value, ^tags}} = Sequence.parse(Record, tags ++ tags, fields)
    assert {:ok, []} = Sequence.encode(record(), [])
    assert {:ok, {%Record{}, [:kept]}} = Sequence.parse(Record, [:kept], [])
  end

  test "omits absent optional fields and still consumes a present constructed field" do
    fields = [
      name: {:optional, :character_string},
      state: :enumerated,
      raw: {:optional, :octet_string},
      seen_at: {:optional, BACnetDateTime},
      details: {:optional, :character_string}
    ]

    present = record(name: "hub", state: 4, raw: nil, seen_at: timestamp(), details: nil)
    absent = record(name: nil, state: 4, raw: <<1, 2>>, seen_at: nil, details: "late")

    assert {:ok, present_tags} = Sequence.encode(present, fields)
    assert [0, 1, 3] = indexes(present_tags)
    assert {:ok, {^present, []}} = Sequence.parse(Record, present_tags, fields)

    assert {:ok, absent_tags} = Sequence.encode(absent, fields)

    assert [
             {:tagged, {1, _state, _state_length}},
             {:tagged, {2, _raw, _raw_length}},
             {:tagged, {4, _details, _details_length}}
           ] = absent_tags

    assert {:ok, {^absent, []}} = Sequence.parse(Record, absent_tags, fields)
  end

  test "encodes property identifiers and resolves known and unknown numbers" do
    fields = [property: :property_identifier]
    named = record(property: :sc_primary_hub_uri)
    unknown = record(property: 9876)
    numeric = record(property: 4_194_325)

    assert {:ok, named_tags} = Sequence.encode(named, fields)
    assert {:ok, numeric_tags} = Sequence.encode(numeric, fields)
    assert named_tags == numeric_tags
    assert {:ok, {parsed, []}} = Sequence.parse(Record, numeric_tags, fields)
    assert parsed.property == :sc_primary_hub_uri

    assert {:ok, unknown_tags} = Sequence.encode(unknown, fields)
    assert {:ok, {^unknown, []}} = Sequence.parse(Record, unknown_tags, fields)

    optional = [
      property: {:optional, :property_identifier},
      details: {:optional, :character_string}
    ]

    skipped = record(property: nil, details: "only")
    assert {:ok, [detail]} = Sequence.encode(skipped, optional)
    assert {:tagged, {1, _detail, _length}} = detail
    assert {:ok, {^skipped, []}} = Sequence.parse(Record, [detail], optional)
  end

  test "returns the encoding error for an invalid field" do
    assert {:error, :invalid_value} =
             Sequence.encode(record(timestamp: nil), timestamp: BACnetDateTime)

    assert {:error, :invalid_value} =
             Sequence.encode(record(timestamp: error()), timestamp: BACnetDateTime)

    assert {:error, :invalid_host} =
             Sequence.encode(record(address: %HostNPort{host: :bad, port: 1}), address: HostNPort)

    assert {:error, :invalid_value} = Sequence.encode(record(state: -1), state: :enumerated)
    assert {:error, :invalid_value} = Sequence.encode(record(raw: :nope), raw: :octet_string)

    assert {:error, :invalid_utf8_string} =
             Sequence.encode(record(state: 1, name: <<255>>),
               state: :enumerated,
               name: :character_string
             )

    assert {:error, :invalid_value} =
             Sequence.encode(record(property: "object_name"), property: :property_identifier)
  end

  test "rejects incomplete, mistyped, and unreadable tags" do
    assert {:error, :invalid_tags} = Sequence.parse(Record, [], state: :enumerated)

    assert {:error, :invalid_tags} =
             Sequence.parse(Record, [{:enumerated, 1}], state: :enumerated)

    assert {:error, :invalid_tags} =
             Sequence.parse(Record, [{:tagged, {1, <<0>>, 1}}], state: :enumerated)

    assert {:error, :invalid_tags} =
             Sequence.parse(Record, [{:tagged, {1, <<0>>, 1}}], timestamp: BACnetDateTime)

    assert {:error, :unknown_tag_encoding} =
             Sequence.parse(Record, [{:tagged, {0, :nope, 1}}], state: :enumerated)

    assert {:error, :invalid_tags} = Sequence.parse(Record, [], property: :property_identifier)

    assert {:error, :unknown_tag_encoding} =
             Sequence.parse(Record, [{:tagged, {0, :nope, 1}}], property: :property_identifier)

    fields = [name: {:optional, :character_string}, state: :enumerated]
    assert {:ok, tags} = Sequence.encode(record(name: nil, state: 4), fields)
    assert {:ok, {%Record{name: nil, state: 4}, []}} = Sequence.parse(Record, tags, fields)

    assert {:error, _reason} =
             Sequence.parse(Record, [{:tagged, {0, :nope, 1}}],
               name: {:optional, :character_string}
             )
  end

  test "rejects a constructed value that leaves inner tags or cannot be parsed" do
    assert {:ok, [{:constructed, {0, inner, 0}}]} =
             Sequence.encode(record(error: error()), error: BACnetError)

    leftover = {:constructed, {0, List.wrap(inner) ++ [{:enumerated, 9}], 0}}
    assert {:error, :invalid_tags} = Sequence.parse(Record, [leftover], error: BACnetError)

    assert {:error, :invalid_tags} =
             Sequence.parse(Record, [{:constructed, {0, [], 0}}], address: HostNPort)

    assert {:error, :invalid_tags} =
             Sequence.parse(Record, [{:constructed, {0, {:enumerated, 1}, 0}}],
               timestamp: BACnetDateTime
             )

    assert {:error, :invalid_tags} =
             Sequence.parse(Record, [{:constructed, {0, [{:enumerated, 1}], 0}}],
               timestamp: BACnetDateTime
             )
  end

  # Dependents expand this macro while the library compiles, before coverage
  # starts. Compiling one here executes that body during this test.
  test "compiles encode and parse into a sequence module" do
    module = Module.concat(__MODULE__, "Probe#{System.unique_integer([:positive])}")

    [{^module, _bytecode}] =
      Code.compile_string("""
      defmodule #{inspect(module)} do
        @type t :: %__MODULE__{state: non_neg_integer(), note: String.t() | nil}
        @enforce_keys [:state, :note]
        defstruct state: nil, note: nil

        use BACnet.Protocol.SecureConnect.Sequence,
          fields: [
            state: :enumerated,
            note: {:optional, :character_string}
          ]
      end
      """)

    present = struct!(module, state: 2, note: "up")
    absent = struct!(module, state: 2, note: nil)

    assert {:ok, present_tags} = module.encode(present)
    assert {:ok, {^present, []}} = module.parse(present_tags)

    assert {:ok, absent_tags} = module.encode(absent)
    assert [{:tagged, {0, _state, _length}}] = absent_tags
    assert {:ok, {^absent, []}} = module.parse(absent_tags)
    assert {:error, :invalid_value} = module.encode(struct!(module, state: -1, note: nil))
    assert {:error, :invalid_tags} = module.parse([])
  end

  defp record(attrs \\ []), do: struct!(Record, attrs)

  defp timestamp() do
    %BACnetDateTime{
      date: %BACnetDate{year: 2024, month: 1, day: 3, weekday: 3},
      time: %BACnetTime{hour: 8, minute: 30, second: 0, hundredth: 0}
    }
  end

  defp error(), do: %BACnetError{class: :communication, code: :websocket_error}

  defp address(), do: %HostNPort{host: {:ip_address, {127, 0, 0, 1}}, port: 443}

  defp indexes(tags) do
    Enum.map(tags, fn {_kind, {index, _body, _length}} -> index end)
  end
end
