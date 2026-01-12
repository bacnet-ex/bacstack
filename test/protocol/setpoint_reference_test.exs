defmodule BACnet.Protocol.SetpointReferenceTest do
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectPropertyRef
  alias BACnet.Protocol.SetpointReference

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest SetpointReference

  @decoded_ref %ObjectPropertyRef{
    object_identifier: %ObjectIdentifier{type: :analog_value, instance: 25},
    property_identifier: :present_value,
    property_array_index: nil
  }

  {:ok, encoded_ref} = ObjectPropertyRef.encode(@decoded_ref)
  @encoded_ref encoded_ref

  test "decode setpoint ref" do
    assert {:ok, {%SetpointReference{ref: @decoded_ref}, []}} =
             SetpointReference.parse(constructed: {0, @encoded_ref, 0})
  end

  test "decode setpoint ref empty" do
    assert {:ok, {%SetpointReference{ref: nil}, []}} = SetpointReference.parse([])
  end

  test "decode setpoint ref empty 2" do
    # I have no idea if this kind of app tags is possible, but we cover it anyway
    # (we do not want crashes because we thought we would never get it)
    assert {:ok, {%SetpointReference{ref: nil}, []}} =
             SetpointReference.parse(constructed: {0, [], 0})
  end

  test "decode setpoint ref invalid ref" do
    assert {:error, :invalid_tags} =
             SetpointReference.parse(constructed: {0, [constructed: {5, [], 0}], 0})
  end

  test "encode setpoint ref" do
    assert {:ok, [constructed: {0, @encoded_ref, 0}]} =
             SetpointReference.encode(%SetpointReference{ref: @decoded_ref})
  end

  test "encode setpoint ref empty" do
    assert {:ok, []} = SetpointReference.encode(%SetpointReference{ref: nil})
  end

  test "encode setpoint ref invalid" do
    assert {:error, :invalid_value} =
             SetpointReference.encode(%SetpointReference{
               ref: %{@decoded_ref | property_identifier: -2}
             })
  end

  test "valid setpoint ref" do
    assert true == SetpointReference.valid?(%SetpointReference{ref: nil})
    assert true == SetpointReference.valid?(%SetpointReference{ref: @decoded_ref})
  end

  test "invalid setpoint ref" do
    assert false == SetpointReference.valid?(%SetpointReference{ref: :hello_there})

    assert false ==
             SetpointReference.valid?(%SetpointReference{
               ref: %{@decoded_ref | property_identifier: -2}
             })
  end
end
