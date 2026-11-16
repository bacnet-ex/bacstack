defmodule BACnet.Test.Protocol.SecureConnect.BvlcTest do
  alias BACnet.Protocol.SecureConnect.BVLC

  use BACnet.Test.Stack.Case, async: true

  import Bitwise

  @functions [
    :result,
    :npdu,
    :address_resolution,
    :address_resolution_ack,
    :advertisement,
    :advertisement_solicitation,
    :connect_request,
    :connect_accept,
    :disconnect_request,
    :disconnect_ack,
    :heartbeat_request,
    :heartbeat_ack,
    :proprietary
  ]

  @link_functions [
    :connect_request,
    :connect_accept,
    :disconnect_request,
    :disconnect_ack,
    :heartbeat_request,
    :heartbeat_ack
  ]

  @responses [:result, :address_resolution_ack, :connect_accept, :disconnect_ack, :heartbeat_ack]

  test "encodes the corrected BVLC-Result example and preserves unknown options" do
    example =
      Base.decode16!("0008B5EC927BF71A96A20101BF00070111556E6DC3B6676C696368657220436F646521")

    assert {:ok, %BVLC{function: :result, id: 0xB5EC, data_options: []} = result} =
             BVLC.decode(example)

    assert BVLC.encode(result) == example

    frame = %BVLC{
      function: :npdu,
      id: 42,
      source: nil,
      destination: BVLC.broadcast(),
      destination_options: [],
      data_options: [{1, true, nil}, {30, false, :binary.copy(<<42>>, 4188)}],
      payload: :binary.copy(<<1>>, BVLC.max_npdu())
    }

    assert {:ok, ^frame} = BVLC.decode(BVLC.encode(frame))
    assert nil == BVLC.nak(frame, 146)
    assert {:error, 147, _header} = BVLC.decode(<<1, 1, 0, 0, 0x22, 0, 9, 0>>)
    assert {:error, 143, %BVLC{function: 13}} = BVLC.decode(<<13, 0, 0, 0>>)
    assert {:error, 147, nil} = BVLC.decode(:binary.copy(<<0>>, BVLC.max_bvlc() + 1))
  end

  test "reports the broadcast VMAC and the codec size limits" do
    assert BVLC.broadcast() == <<255, 255, 255, 255, 255, 255>>
    assert BVLC.max_bvlc() == 65_535
    assert BVLC.max_npdu() == 1497
  end

  test "accepts only a six-octet unicast VMAC" do
    assert BVLC.valid_vmac?(vmac())
    refute BVLC.valid_vmac?(<<0::size(48)>>)
    refute BVLC.valid_vmac?(BVLC.broadcast())
    refute BVLC.valid_vmac?(<<1, 2, 3, 4, 5>>)
    refute BVLC.valid_vmac?(<<1, 2, 3, 4, 5, 6, 7>>)
    refute BVLC.valid_vmac?(<<>>)
    refute BVLC.valid_vmac?(nil)
    refute BVLC.valid_vmac?(6)
  end

  test "builds a random VMAC whose first octet ends in two" do
    <<_high::size(4), low::size(4), _rest::size(40)>> = address = BVLC.random_vmac()

    assert low == 2
    assert BVLC.valid_vmac?(address)
  end

  test "maps function names and accepts an already numeric code" do
    for {name, code} <- Enum.with_index(@functions) do
      assert BVLC.code(name) == code
      assert BVLC.link_function?(name) == name in @link_functions
    end

    assert BVLC.code(255) == 255
    refute BVLC.link_function?(6)

    assert {:error, 143, %BVLC{function: 40, id: 7}} =
             BVLC.decode(BVLC.encode(message(40, <<1>>)))
  end

  test "builds and reads a connection identity" do
    payload = BVLC.identity(vmac(), uuid())

    assert BVLC.peer(payload) == %{
             vmac: vmac(),
             uuid: uuid(),
             max_bvlc: BVLC.max_bvlc(),
             max_npdu: BVLC.max_npdu()
           }

    assert {:ok, %BVLC{function: :connect_request}} =
             encoded_connect(:connect_request, vmac(), uuid(), 30, 2)

    assert {:ok, %BVLC{function: :connect_accept, payload: ^payload}} =
             BVLC.decode(BVLC.encode(message(:connect_accept, payload)))
  end

  test "addresses a response to the originating VMAC" do
    address = vmac()
    request = message(:address_resolution, <<>>, source: address, id: 0x1234)

    response = BVLC.response(request, :address_resolution_ack)

    assert %BVLC{
             function: :address_resolution_ack,
             id: 0x1234,
             source: nil,
             destination: ^address,
             destination_options: [],
             data_options: [],
             payload: <<>>
           } = response

    assert {:ok, ^response} = BVLC.decode(BVLC.encode(response))

    ack = BVLC.response(message(:heartbeat_request, <<>>), :heartbeat_ack)
    assert ack.destination == nil
    assert {:ok, ^ack} = BVLC.decode(BVLC.encode(ack))

    answered = BVLC.response(request, :address_resolution_ack, "node")
    assert answered.payload == "node"
    assert {:ok, ^answered} = BVLC.decode(BVLC.encode(answered))

    unnamed = BVLC.response(message(:heartbeat_request, <<>>), :proprietary, <<9, 9, 9>>)
    assert unnamed.destination == nil
    assert {:ok, ^unnamed} = BVLC.decode(BVLC.encode(unnamed))
  end

  test "builds a BVLC-Result NAK for a request and skips broadcasts and responses" do
    address = vmac()
    request = message(:address_resolution, <<>>, source: address, id: 0x1234)
    nak = BVLC.nak(request, 146, 3)

    assert %BVLC{
             function: :result,
             id: 0x1234,
             source: nil,
             destination: ^address,
             destination_options: [],
             data_options: [],
             payload: <<2, 1, 3, 0, 7, 0, 146>>
           } = nak

    assert {:ok, ^nak} = BVLC.decode(BVLC.encode(nak))
    assert <<2, 1, 0, 0, 7, 0, 146>> = BVLC.nak(request, 146).payload

    for function <- @responses do
      assert BVLC.nak(message(function, <<0>>), 1) == nil
    end

    assert BVLC.nak(message(:npdu, <<1>>, destination: BVLC.broadcast()), 9) == nil
  end

  test "round-trips every BVLC function" do
    connect = BVLC.identity(vmac(), uuid())
    destination = <<6, 5, 4, 3, 2, 1>>

    messages = [
      message(:result, <<BVLC.code(:npdu), 0>>),
      message(:result, <<BVLC.code(:connect_request), 1, 4, 0, 7, 0, 146, "down">>),
      message(:npdu, <<1, 2, 3>>, source: vmac(), destination: destination),
      message(:address_resolution, <<>>),
      message(:address_resolution_ack, "hub.example"),
      message(:advertisement, <<2, 1, 30::size(16), 2::size(16)>>),
      message(:advertisement_solicitation, <<>>),
      message(:connect_request, connect),
      message(:connect_accept, connect),
      message(:disconnect_request, <<>>),
      message(:disconnect_ack, <<>>),
      message(:heartbeat_request, <<>>),
      message(:heartbeat_ack, <<>>),
      message(:proprietary, <<9, 8, 7>>, destination: BVLC.broadcast()),
      message(:npdu, <<8>>, destination: BVLC.broadcast())
    ]

    for original <- messages do
      assert {:ok, ^original} = BVLC.decode(BVLC.encode(original))
    end
  end

  test "encodes addresses and option lists in wire order" do
    source = vmac()
    destination = <<6, 5, 4, 3, 2, 1>>
    data = <<9, 8, 7>>
    code = BVLC.code(:npdu)

    addressed = message(:npdu, <<8>>, source: source, destination: destination)

    assert <<^code, 12, 0, 7, ^source::binary-6, ^destination::binary-6, 8>> =
             BVLC.encode(addressed)

    destination_only =
      message(:npdu, <<1>>, destination_options: [{3, false, data}, {4, true, nil}])

    assert <<^code, 2, 0, 7, first, 0, 3, ^data::binary-size(3), second, 1>> =
             BVLC.encode(destination_only)

    assert first == (128 ||| 32 ||| 3)
    assert second == (64 ||| 4)
    assert {:ok, ^destination_only} = BVLC.decode(BVLC.encode(destination_only))

    data_only = message(:npdu, <<1>>, data_options: [{5, true, nil}, {6, false, nil}])
    assert <<^code, 1, 0, 7, more, last, 1>> = BVLC.encode(data_only)
    assert more == (128 ||| 64 ||| 5)
    assert last == 6

    both =
      message(:npdu, <<1, 2>>,
        source: source,
        destination_options: [{6, false, <<4>>}],
        data_options: [{7, true, nil}]
      )

    assert {:ok, ^both} = BVLC.decode(BVLC.encode(both))
  end

  test "accepts a message at the maximum BVLC size" do
    payload = :binary.copy(<<1>>, BVLC.max_bvlc() - 4)
    binary = <<BVLC.code(:npdu), 0, 0, 1, payload::binary>>

    assert byte_size(binary) == BVLC.max_bvlc()
    assert {:ok, %BVLC{function: :npdu, id: 1, payload: ^payload}} = BVLC.decode(binary)
  end

  test "rejects truncated headers and addresses" do
    code = BVLC.code(:npdu)

    assert {:error, 147, nil} = BVLC.decode(<<>>)
    assert {:error, 147, nil} = BVLC.decode(<<code, 0, 0>>)
    assert {:error, 147, nil} = BVLC.decode(<<code, 8, 0, 1, 1, 2, 3, 4, 5>>)
    assert {:error, 147, nil} = BVLC.decode(<<code, 4, 0, 1, 1, 2, 3>>)
    assert {:error, 147, nil} = BVLC.decode(<<code, 12, 0, 1, vmac()::binary>>)
  end

  test "rejects reserved flags and broken option lists" do
    destination = <<9, 8, 7, 6, 5, 4>>
    code = BVLC.code(:npdu)

    assert {:error, 80, %BVLC{function: :npdu, id: 4, destination: ^destination, payload: <<>>}} =
             BVLC.decode(<<code, 4 ||| 16, 0, 4, destination::binary>>)

    assert {:error, 80, %BVLC{function: :heartbeat_request, source: nil, destination: nil}} =
             BVLC.decode(<<BVLC.code(:heartbeat_request), 0xF0, 0, 0>>)

    assert {:error, 145, %BVLC{function: :npdu, destination_options: [], payload: <<>>}} =
             BVLC.decode(<<code, 2, 0, 1, 0>>)

    assert {:error, 145, %BVLC{data_options: []}} = BVLC.decode(<<code, 1, 0, 1, 128 ||| 1, 0>>)

    assert {:error, 145, _header} = BVLC.decode(<<code, 3, 0, 1, 1, 0>>)

    assert {:error, 147, %BVLC{function: :heartbeat_request, payload: <<>>}} =
             BVLC.decode(<<BVLC.code(:heartbeat_request), 2, 0, 1, 32 ||| 1, 0, 4>>)

    assert {:error, 147, _header} = BVLC.decode(<<code, 3, 0, 1, 1, 32 ||| 1, 0, 4>>)
  end

  test "rejects invalid addresses, routed link messages, and illegal broadcasts" do
    assert {:error, 80, %BVLC{source: <<0::size(48)>>, payload: <<>>}} =
             BVLC.decode(BVLC.encode(message(:npdu, <<1>>, source: <<0::size(48)>>)))

    assert {:error, 80, %BVLC{source: broadcast}} =
             BVLC.decode(BVLC.encode(message(:npdu, <<1>>, source: BVLC.broadcast())))

    assert broadcast == BVLC.broadcast()

    assert {:error, 80, %BVLC{destination: <<0::size(48)>>}} =
             BVLC.decode(BVLC.encode(message(:npdu, <<1>>, destination: <<0::size(48)>>)))

    assert {:error, 80, %BVLC{function: :connect_request, source: source}} =
             BVLC.decode(
               BVLC.encode(
                 message(:connect_request, BVLC.identity(vmac(), uuid()), source: vmac())
               )
             )

    assert source == vmac()

    assert {:error, 80, %BVLC{function: :heartbeat_request, destination: destination}} =
             BVLC.decode(BVLC.encode(message(:heartbeat_request, <<>>, destination: vmac())))

    assert destination == vmac()

    for function <- [
          :result,
          :address_resolution,
          :address_resolution_ack,
          :advertisement,
          :advertisement_solicitation
        ] do
      assert {:error, 7, %BVLC{function: ^function, destination: broadcast}} =
               BVLC.decode(BVLC.encode(message(function, <<>>, destination: BVLC.broadcast())))

      assert broadcast == BVLC.broadcast()
    end
  end

  test "rejects data options on messages other than an NPDU" do
    assert {:error, 80, %BVLC{function: :proprietary, data_options: []}} =
             BVLC.decode(
               BVLC.encode(message(:proprietary, <<1, 2, 3>>, data_options: [{1, false, nil}]))
             )

    assert {:error, 80, %BVLC{function: :result}} =
             BVLC.decode(
               BVLC.encode(message(:result, <<1, 0>>, data_options: [{2, true, <<0>>}]))
             )
  end

  test "rejects empty payloads that the function requires" do
    for function <- [
          :npdu,
          :result,
          :connect_request,
          :connect_accept,
          :advertisement,
          :proprietary
        ] do
      assert {:error, 149, %BVLC{function: ^function, payload: <<>>}} =
               BVLC.decode(BVLC.encode(message(function, <<>>)))
    end
  end

  test "validates connection payloads" do
    assert {:error, 80, %BVLC{function: :connect_request}} =
             encoded_connect(:connect_request, <<0::size(48)>>, uuid(), 30, 2)

    assert {:error, 80, %BVLC{function: :connect_accept}} =
             encoded_connect(:connect_accept, BVLC.broadcast(), uuid(), 30, 2)

    assert {:error, 80, _header} =
             encoded_connect(:connect_request, vmac(), <<0::size(128)>>, 30, 2)

    assert {:error, 80, _header} = encoded_connect(:connect_accept, vmac(), uuid(), 29, 2)
    assert {:error, 80, _header} = encoded_connect(:connect_request, vmac(), uuid(), 30, 1)

    assert {:error, 147, %BVLC{function: :connect_accept}} =
             BVLC.decode(BVLC.encode(message(:connect_accept, <<1, 2, 3, 4>>)))
  end

  test "validates results, resolution replies, advertisements, and proprietary payloads" do
    assert {:ok, %BVLC{payload: <<1, 0>>}} = BVLC.decode(BVLC.encode(message(:result, <<1, 0>>)))

    detailed = <<2, 1, 9, 0, 7, 0, 146, "down">>
    assert {:ok, %BVLC{payload: ^detailed}} = BVLC.decode(BVLC.encode(message(:result, detailed)))

    empty_detail = <<2, 1, 9, 0, 7, 0, 1>>

    assert {:ok, %BVLC{payload: ^empty_detail}} =
             BVLC.decode(BVLC.encode(message(:result, empty_detail)))

    assert {:error, 80, %BVLC{function: :result}} =
             BVLC.decode(BVLC.encode(message(:result, <<2, 1, 9, 0, 7, 0, 1, 255>>)))

    for payload <- [<<1>>, <<1, 2>>, <<1, 0, 0>>, <<1, 1, 0>>] do
      assert {:error, 147, %BVLC{function: :result}} =
               BVLC.decode(BVLC.encode(message(:result, payload)))
    end

    assert {:ok, _ack} = BVLC.decode(BVLC.encode(message(:address_resolution_ack, "hub.local")))
    assert {:ok, _ack} = BVLC.decode(BVLC.encode(message(:address_resolution_ack, <<>>)))

    assert {:error, 80, %BVLC{function: :address_resolution_ack}} =
             BVLC.decode(BVLC.encode(message(:address_resolution_ack, <<255, 255>>)))

    for hub <- 0..2, direct <- 0..1 do
      payload = <<hub, direct, 30::size(16), 2::size(16)>>

      assert {:ok, %BVLC{function: :advertisement, payload: ^payload}} =
               BVLC.decode(BVLC.encode(message(:advertisement, payload)))
    end

    for payload <- [<<3, 0, 0, 30, 0, 2>>, <<0, 2, 0, 30, 0, 2>>, <<0, 0, 0>>] do
      assert {:error, 80, %BVLC{function: :advertisement}} =
               BVLC.decode(BVLC.encode(message(:advertisement, payload)))
    end

    assert {:error, 147, %BVLC{function: :proprietary}} =
             BVLC.decode(BVLC.encode(message(:proprietary, <<1, 2>>)))

    proprietary = message(:proprietary, <<1, 2, 3>>)
    assert {:ok, ^proprietary} = BVLC.decode(BVLC.encode(proprietary))
  end

  test "rejects unexpected payloads on messages that carry none" do
    for function <- [
          :disconnect_request,
          :disconnect_ack,
          :heartbeat_request,
          :heartbeat_ack,
          :address_resolution,
          :advertisement_solicitation
        ] do
      assert {:ok, %BVLC{function: ^function, payload: <<>>}} =
               BVLC.decode(BVLC.encode(message(function, <<>>)))

      assert {:error, 150, %BVLC{function: ^function}} =
               BVLC.decode(BVLC.encode(message(function, <<0>>)))
    end
  end

  test "reports the first destination option that must be understood" do
    assert BVLC.unsupported_option(message(:heartbeat_request, <<>>)) == nil

    assert BVLC.unsupported_option(
             message(:npdu, <<1>>, destination_options: [{1, false, <<1>>}])
           ) == nil

    assert BVLC.unsupported_option(message(:npdu, <<1>>, destination_options: [{8, true, nil}])) ==
             (8 ||| 64)

    continued =
      message(:npdu, <<1>>,
        destination_options: [{1, false, nil}, {4, true, <<9>>}, {5, true, nil}]
      )

    assert BVLC.unsupported_option(continued) == (4 ||| 64 ||| 32 ||| 128)

    assert {:ok, decoded} = BVLC.decode(BVLC.encode(continued))
    assert BVLC.unsupported_option(decoded) == BVLC.unsupported_option(continued)

    first_wins = message(:npdu, <<1>>, destination_options: [{3, true, nil}, {9, true, <<1>>}])
    assert BVLC.unsupported_option(first_wins) == (3 ||| 64 ||| 128)
  end

  defp message(function, payload, fields \\ []) do
    defaults = [
      function: function,
      id: 7,
      source: nil,
      destination: nil,
      destination_options: [],
      data_options: [],
      payload: payload
    ]

    struct!(BVLC, Keyword.merge(defaults, fields))
  end

  defp encoded_connect(function, address, device, bvlc_limit, npdu_limit) do
    payload = <<address::binary-6, device::binary-16, bvlc_limit::size(16), npdu_limit::size(16)>>
    BVLC.decode(BVLC.encode(message(function, payload)))
  end

  defp vmac(), do: <<1, 2, 3, 4, 5, 6>>
  defp uuid(), do: <<9::size(128)>>
end
