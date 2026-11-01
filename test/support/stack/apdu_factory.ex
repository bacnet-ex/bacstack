defmodule BACnet.Test.Stack.ApduFactory do
  @moduledoc false

  alias BACnet.Protocol.APDU
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services.ReadProperty

  def who_is() do
    %APDU.UnconfirmedServiceRequest{service: :who_is, parameters: []}
  end

  def read_property(opts \\ []) do
    {:ok, apdu} =
      ReadProperty.to_apdu(
        %ReadProperty{
          object_identifier: %ObjectIdentifier{type: :analog_input, instance: 1},
          property_identifier: :present_value,
          property_array_index: nil
        },
        opts
      )

    apdu
  end

  def simple_ack(invoke_id, service \\ :read_property) do
    %APDU.SimpleACK{invoke_id: invoke_id, service: service}
  end

  def abort(invoke_id, reason \\ :other) do
    %APDU.Abort{
      sent_by_server: true,
      invoke_id: invoke_id,
      reason: reason
    }
  end

  def reject(invoke_id, reason \\ :other) do
    %APDU.Reject{
      invoke_id: invoke_id,
      reason: reason
    }
  end

  def segment_ack(invoke_id, opts \\ []) do
    %APDU.SegmentACK{
      sent_by_server: Keyword.get(opts, :sent_by_server, false),
      negative_ack: Keyword.get(opts, :negative_ack, false),
      invoke_id: invoke_id,
      sequence_number: Keyword.get(opts, :sequence_number, 0),
      actual_window_size: Keyword.get(opts, :actual_window_size, 1)
    }
  end

  def complex_ack(invoke_id, payload \\ []) do
    %APDU.ComplexACK{
      invoke_id: invoke_id,
      sequence_number: nil,
      proposed_window_size: nil,
      service: :read_property,
      payload: payload
    }
  end
end
