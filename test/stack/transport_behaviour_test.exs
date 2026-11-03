defmodule Boom do
  @moduledoc false
  defstruct []
end

defimpl BACnet.Stack.EncoderProtocol, for: Boom do
  def expects_reply(_apdu), do: false
  def request?(_apdu), do: false
  def response?(_apdu), do: true
  def encode(_apdu), do: throw(:boom)
  def supports_segmentation(_apdu), do: false
  def encode_segmented(_apdu, _size), do: []
  def encode_to_segmented(_apdu, _data, _size), do: []
end

defmodule BACnet.Stack.TransportBehaviourTest do
  alias BACnet.Protocol.APDU.SimpleACK
  alias BACnet.Protocol.NPCI
  alias BACnet.Protocol.NpciTarget
  alias BACnet.Stack.EncoderProtocol
  alias BACnet.Stack.TransportBehaviour
  alias BACnet.Test.Stack.ApduFactory
  alias BACnet.Test.Stack.FakeTransport

  use ExUnit.Case, async: true

  @moduletag :stack
  @moduletag :transport_behaviour

  test "child_spec starts the transport through open/2" do
    spec = TransportBehaviour.child_spec(FakeTransport, self(), id: :transport)
    assert spec.id == :transport
    assert spec.start == {FakeTransport, :open, [self(), []]}

    {:ok, sup} = Supervisor.start_link([spec], strategy: :one_for_one)
    assert [{:transport, pid, :worker, [FakeTransport]}] = Supervisor.which_children(sup)
    assert Process.alive?(pid)
    assert :ok = Supervisor.stop(sup)

    spec =
      TransportBehaviour.child_spec(FakeTransport, self(), [port: 1],
        id: :other,
        restart: :temporary
      )

    assert spec.id == :other
    assert spec.restart == :temporary
    assert spec.start == {FakeTransport, :open, [self(), [port: 1]]}
  end

  test "build_bacnet_packet derives the reply bit from the payload" do
    assert_raise ArgumentError, ~r/keyword list/, fn ->
      TransportBehaviour.build_bacnet_packet(<<0x10, 8>>, false, [1])
    end

    assert {:ok, {npci, <<0x10, 8>>}} =
             TransportBehaviour.build_bacnet_packet(<<0x10, 8>>, false, [])

    assert iodata(npci) == iodata(NPCI.encode(NPCI.new(expects_reply: false)))

    assert {:ok, {npci, <<0>>}} = TransportBehaviour.build_bacnet_packet(<<0>>, false, [])
    assert iodata(npci) == iodata(NPCI.encode(NPCI.new(expects_reply: true)))

    assert {:ok, {npci, <<0x34, 1>>}} =
             TransportBehaviour.build_bacnet_packet(<<0x34, 1>>, false, [])

    assert iodata(npci) == iodata(NPCI.encode(NPCI.new(expects_reply: true)))

    assert {:ok, {npci, []}} = TransportBehaviour.build_bacnet_packet([], false, [])
    assert iodata(npci) == iodata(NPCI.encode(NPCI.new(expects_reply: false)))

    assert {:ok, {npci, [0x10]}} = TransportBehaviour.build_bacnet_packet([0x10], false, [])
    assert iodata(npci) == iodata(NPCI.encode(NPCI.new(expects_reply: false)))

    assert {:ok, {npci, [[], <<0>>]}} =
             TransportBehaviour.build_bacnet_packet([[], <<0>>], false, [])

    assert iodata(npci) == iodata(NPCI.encode(NPCI.new(expects_reply: true)))

    assert {:ok, {npci, 0}} = TransportBehaviour.build_bacnet_packet(0, false, [])
    assert iodata(npci) == iodata(NPCI.encode(NPCI.new(expects_reply: true)))

    assert {:ok, {npci, 255}} = TransportBehaviour.build_bacnet_packet(255, false, [])
    assert iodata(npci) == iodata(NPCI.encode(NPCI.new(expects_reply: false)))

    who_is = ApduFactory.who_is()

    assert {:ok, {npci, apdu}} = TransportBehaviour.build_bacnet_packet(who_is, false, [])
    assert iodata(apdu) == iodata(EncoderProtocol.encode(who_is))
    assert iodata(npci) == iodata(NPCI.encode(NPCI.new(expects_reply: false)))

    request = ApduFactory.read_property()

    assert {:ok, {npci, apdu}} =
             TransportBehaviour.build_bacnet_packet(request, false, expects_reply: false)

    assert iodata(apdu) == iodata(EncoderProtocol.encode(request))
    assert iodata(npci) == iodata(NPCI.encode(NPCI.new(expects_reply: false)))
  end

  test "build_bacnet_packet encodes broadcast, source, and destination" do
    assert {:error, :invalid_expects_reply_for_broadcast} =
             TransportBehaviour.build_bacnet_packet(<<0>>, true, [])

    assert {:ok, {npci, <<0x10, 8>>}} =
             TransportBehaviour.build_bacnet_packet(<<0x10, 8>>, true, [])

    assert iodata(npci) ==
             iodata(
               NPCI.encode(
                 NPCI.new(
                   destination: %NpciTarget{net: 65_535, address: nil},
                   expects_reply: false
                 )
               )
             )

    destination = %NpciTarget{net: 4, address: 9}
    source = %NpciTarget{net: 2, address: 5}

    assert {:ok, {npci, <<0x10>>}} =
             TransportBehaviour.build_bacnet_packet(<<0x10>>, false,
               destination: destination,
               source: source
             )

    assert iodata(npci) ==
             iodata(
               NPCI.encode(
                 NPCI.new(destination: destination, source: source, expects_reply: false)
               )
             )

    assert {:ok, {[], <<0x10>>}} =
             TransportBehaviour.build_bacnet_packet(<<0x10>>, false, skip_headers: true)

    assert {:ok, {"", <<0x10>>}} =
             TransportBehaviour.build_bacnet_packet(<<0x10>>, false, npci: false)

    given = NPCI.new(expects_reply: false, hopcount: 2)

    assert {:ok, {npci, <<0>>}} =
             TransportBehaviour.build_bacnet_packet(<<0>>, false, npci: given)

    assert iodata(npci) == iodata(NPCI.encode(given))

    assert_raise ArgumentError, ~r/destination/, fn ->
      TransportBehaviour.build_bacnet_packet(<<0x10>>, false, destination: :peer)
    end

    assert_raise ArgumentError, ~r/source/, fn ->
      TransportBehaviour.build_bacnet_packet(<<0x10>>, false,
        source: %NpciTarget{net: 65_535, address: 1}
      )
    end

    assert_raise ArgumentError, ~r/NPCI/, fn ->
      TransportBehaviour.build_bacnet_packet(<<0x10>>, false, npci: :nope)
    end

    assert_raise ArgumentError, ~r/broadcast can not expect reply/, fn ->
      TransportBehaviour.build_bacnet_packet(<<0x10>>, true,
        npci: NPCI.new(expects_reply: true),
        expects_reply: false
      )
    end
  end

  test "build_bacnet_packet returns encode failures" do
    assert {:error, {%ArgumentError{}, _stack}} =
             TransportBehaviour.build_bacnet_packet(
               %SimpleACK{invoke_id: -1, service: :who_is},
               false,
               []
             )

    assert {:error, :boom} =
             TransportBehaviour.build_bacnet_packet(%Boom{}, false, [])
  end

  defp iodata(data), do: IO.iodata_to_binary(data)
end
