defmodule BACnet.Protocol.EventParameters.GenericTest do
  alias BACnet.Protocol.EventParameters
  alias BACnet.Protocol.EventParameters.Extended
  alias BACnet.Protocol.EventParameters.None

  use ExUnit.Case, async: true

  @moduletag :event_algorithms
  @moduletag :protocol_data_structures

  doctest Extended
  doctest None

  test "create struct of event parameters Extended" do
    Extended.__struct__()
  end

  test "validate event parameters struct Extended" do
    assert true ==
             EventParameters.valid?(%Extended{
               vendor_id: 0,
               extended_event_type: 1,
               parameters: []
             })

    assert false ==
             EventParameters.valid?(%Extended{
               vendor_id: -1,
               extended_event_type: 1,
               parameters: []
             })
  end

  test "create struct of event parameters None" do
    None.__struct__()
  end

  test "validate event parameters struct None" do
    assert true == EventParameters.valid?(%None{})
  end
end
