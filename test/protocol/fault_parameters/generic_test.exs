defmodule BACnet.Protocol.FaultParameters.GenericTest do
  alias BACnet.Protocol.FaultParameters
  alias BACnet.Protocol.FaultParameters.FaultExtended
  alias BACnet.Protocol.FaultParameters.None

  use ExUnit.Case, async: true

  @moduletag :fault_algorithms
  @moduletag :protocol_data_structures

  doctest FaultExtended
  doctest None

  test "assert tag number of fault parameters Extended is correct" do
    assert 2 = FaultExtended.get_tag_number()
  end

  test "create struct of fault parameters Extended" do
    FaultExtended.__struct__()
  end

  test "validate fault parameters struct Extended" do
    assert true ==
             FaultParameters.valid?(%FaultExtended{
               vendor_id: 0,
               extended_fault_type: 1,
               parameters: []
             })

    assert false ==
             FaultParameters.valid?(%FaultExtended{
               vendor_id: -1,
               extended_fault_type: 1,
               parameters: []
             })
  end

  test "assert tag number of fault parameters None is correct" do
    assert 0 = None.get_tag_number()
  end

  test "create struct of fault parameters None" do
    None.__struct__()
  end

  test "validate fault parameters struct None" do
    assert true == FaultParameters.valid?(%None{})
  end
end
