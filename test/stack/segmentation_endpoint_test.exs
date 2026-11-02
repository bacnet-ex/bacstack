defmodule BACnet.Stack.SegmentationEndpointTest do
  alias BACnet.Protocol.APDU
  alias BACnet.Protocol.IncompleteAPDU
  alias BACnet.Protocol.NPCI
  alias BACnet.Protocol.NpciTarget
  alias BACnet.Stack.SegmentationEndpoint
  alias BACnet.Test.Stack.ApduFactory
  alias BACnet.Test.Stack.FakeTransport

  use ExUnit.Case, async: true

  @moduletag :stack

  test "received APDUs identify the local role rather than copying the sender's role" do
    assert :responder = SegmentationEndpoint.incoming_role(struct(IncompleteAPDU, server: true))
    assert :requester = SegmentationEndpoint.incoming_role(struct(IncompleteAPDU, server: false))

    for server <- [true, false] do
      expected = if server, do: :requester, else: :responder

      assert SegmentationEndpoint.incoming_role(%{ApduFactory.abort(7) | sent_by_server: server}) ==
               expected

      assert SegmentationEndpoint.incoming_role(
               ApduFactory.segment_ack(7, sent_by_server: server)
             ) == expected
    end

    for apdu <- [
          ApduFactory.simple_ack(7),
          ApduFactory.reject(7),
          %APDU.Error{
            invoke_id: 7,
            service: :read_property,
            class: :device,
            code: :operational_problem,
            payload: []
          }
        ] do
      assert :requester = SegmentationEndpoint.incoming_role(apdu)
    end
  end

  test "compatibility lookup resolves only one endpoint and local role" do
    endpoint = SegmentationEndpoint.new(FakeTransport, self(), :peer)
    routed = %{endpoint | npci: %NpciTarget{net: 10, address: 7}}
    requester = {endpoint, :requester, 7}
    responder = {endpoint, :responder, 7}
    sequences = %{requester => :first, responder => :second, :unrelated => :ignore}

    assert SegmentationEndpoint.sequence_key(sequences, endpoint, 7, :requester) == requester
    assert SegmentationEndpoint.sequence_key(sequences, :peer, 7, :requester) == requester
    assert SegmentationEndpoint.sequence_key(sequences, :peer, 7, :responder) == responder
    assert SegmentationEndpoint.sequence_key(sequences, endpoint, 7) == nil
    assert SegmentationEndpoint.sequence_key(sequences, :peer, 7) == nil
    assert SegmentationEndpoint.sequence_key(sequences, :other, 7) == nil
    assert SegmentationEndpoint.sequence_key(sequences, :peer, 8) == nil

    single = Map.delete(sequences, responder)
    assert SegmentationEndpoint.sequence_key(single, endpoint, 7) == requester
    assert SegmentationEndpoint.sequence_key(single, :peer, 7) == requester
    assert SegmentationEndpoint.sequence_key(single, :peer, 7, :responder) == nil

    ambiguous = Map.put(single, {routed, :requester, 7}, :third)
    assert SegmentationEndpoint.sequence_key(ambiguous, :peer, 7, :requester) == nil
    assert SegmentationEndpoint.sequence_key(ambiguous, routed, 7) == {routed, :requester, 7}
  end

  test "disabling NPCI overrides a separate routed destination" do
    endpoint =
      SegmentationEndpoint.new(FakeTransport, self(), :peer,
        npci: false,
        destination: %NpciTarget{net: 10, address: 7}
      )

    assert endpoint == SegmentationEndpoint.new(FakeTransport, self(), :peer)
  end

  test "an explicit NPCI without a destination overrides a separate routed destination" do
    endpoint =
      SegmentationEndpoint.new(FakeTransport, self(), :peer,
        npci: NPCI.new([]),
        destination: %NpciTarget{net: 10, address: 7}
      )

    assert endpoint == SegmentationEndpoint.new(FakeTransport, self(), :peer)
  end
end
