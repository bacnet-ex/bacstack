defmodule BACnet.Test.Stack.Transport.ScTransport.AuditTest do
  alias BACnet.Protocol.APDU
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.SecureConnect.BVLC
  alias BACnet.Protocol.Services.WriteProperty
  alias BACnet.Stack.EncoderProtocol
  alias BACnet.Stack.Transport.ScTransport.Audit
  alias BACnet.Stack.Transport.ScTransport.Audit.Event

  use BACnet.Test.Stack.Case, async: true

  @moduletag skip: not BACstack.MixProject.sc_enabled?()

  setup context do
    owner = self()

    sink = fn event ->
      send(owner, {:event, event})

      if event.capture_id == context[:failing_capture],
        do: throw(:sink_failed),
        else: :ok
    end

    {:ok, config} = Audit.configure(mode: Map.get(context, :audit_mode, :writes), sink: sink)
    worker = start_supervised!({Audit, {owner, config, false}})
    %{worker: worker}
  end

  test "validates audit configuration" do
    assert {:ok, nil} = Audit.configure(nil)
    assert {:error, :invalid_audit_options} = Audit.configure(:writes)
    assert {:error, :invalid_audit_options} = Audit.configure([:writes])
    assert {:error, :invalid_audit_options} = Audit.configure(mode: :writes, sink: self())
    sink = fn _event -> :ok end
    assert {:error, :invalid_audit_options} = Audit.configure(mode: :other, sink: sink)

    assert {:error, :invalid_audit_options} =
             Audit.configure(mode: :writes, sink: sink, queue_limit: 0)
  end

  @tag audit_mode: :traffic, failing_capture: {<<0::128>>, 1}
  test "preserves raw network and BVLC traffic, including an invalid NPCI", %{worker: worker} do
    send(worker, :unexpected_message)
    capture(worker, 1, 0, {1, 2}, <<0x01>>, npci: <<1, 0x80>>)

    assert_receive {:event,
                    %{
                      kind: :frame,
                      npci: %{is_network_message: true},
                      details: %BVLC{payload: <<1, 0x80, 0x01>>}
                    }}

    assert_receive {:sc_audit_complete, ^worker, :capture, 1, 0}
    capture(worker, 2, 1, {1, 2}, <<0x10, 8>>, npci: <<2, 0>>)
    capture(worker, 3, 2, {1, 2}, <<>>, function: :address_resolution, npci: <<>>)

    assert_receive {:event,
                    %{kind: :frame, npci: nil, details: %BVLC{payload: <<2, 0, 0x10, 8>>}}}

    assert_receive {:event,
                    %{kind: :frame, npci: nil, details: %BVLC{function: :address_resolution}}}

    refute_received {:event, %{kind: :write_request}}
  end

  test "records broadcast writes without correlation and diagnoses an unroutable first segment",
       %{worker: worker} do
    capture(worker, 1, 0, {1, nil}, write(3, 20.0))
    capture(worker, 2, 1, {1, nil}, <<12, 5, 4, 0, 2, 15, 0>>)
    capture(worker, 3, 2, {1, nil}, <<8, 5, 4, 1, 2, 15, 0>>)

    assert_receive {:event, %{kind: :write_request, egress: nil, details: %{invoke_id: 3}}}

    assert_receive {:event,
                    %{
                      kind: :write_diagnostic,
                      details: %{invoke_id: 4, reason: :unroutable_segmented_write}
                    }}

    capture(worker, 4, 3, {2, nil}, %APDU.SimpleACK{invoke_id: 3, service: :write_property})
    GenServer.cast(worker, {:tick, 60_001})
    assert_receive {:sc_audit_complete, ^worker, :tick, 0, 0}
    refute_received {:event, _event}
  end

  test "a final segmented read acknowledgment releases the invoke ID for the next write",
       %{worker: worker} do
    capture(worker, 1, 0, {1, 2}, <<12, 5, 3, 0, 2, 12, 0>>)
    # A ComplexACK for another service leaves the outstanding read in place.
    capture(worker, 2, 1, {2, 1}, <<0x38, 3, 1, 2, 14>>)
    capture(worker, 3, 2, {2, 1}, <<0x38, 3, 1, 2, 12>>)
    capture(worker, 4, 3, {1, 2}, write(3, 20.0))
    assert_receive {:event, %{kind: :write_request, details: %{write_id: write_id}}}

    capture(worker, 5, 4, {2, 1}, <<0x20, 3>>)
    capture(worker, 6, 5, {2, 1}, %APDU.SimpleACK{invoke_id: 3, service: :write_property})

    assert_receive {:event,
                    %{
                      kind: :write_result,
                      details: %{write_id: ^write_id, outcome: :acknowledged}
                    }}
  end

  test "expires a write without inventing an outcome and reports an undecodable write", %{
    worker: worker
  } do
    capture(worker, 1, 0, {1, 2}, write(3, 20.0))

    assert_receive {:event,
                    %{__struct__: Event, kind: :write_request, details: %{write_id: write_id}}}

    GenServer.cast(worker, {:tick, 59_000})
    assert_receive {:sc_audit_complete, ^worker, :tick, 0, 0}
    refute_received {:event, %{__struct__: Event, kind: :write_result}}

    GenServer.cast(worker, {:tick, 60_000})

    assert_receive {:event,
                    %{
                      __struct__: Event,
                      kind: :write_result,
                      details: %{
                        write_id: ^write_id,
                        outcome: :reply_not_observed
                      }
                    }}

    capture(worker, 2, 60_001, {1, 2}, <<0, 5, 4, 15>>)

    assert_receive {:event,
                    %{
                      __struct__: Event,
                      kind: :write_diagnostic,
                      details: %{
                        invoke_id: 4,
                        service: :write_property,
                        reason: :invalid_write
                      }
                    }}
  end

  test "expires transactions at their deadline between periodic sweeps", %{worker: worker} do
    GenServer.cast(worker, {:tick, 0})
    capture(worker, 1, 1, {1, 2}, write(3, 20.0))
    capture(worker, 2, 2, {1, 2}, write(4, 21.0))
    assert_receive {:event, %{kind: :write_request, details: %{write_id: first}}}
    assert_receive {:event, %{kind: :write_request, details: %{write_id: second}}}

    GenServer.cast(worker, {:tick, 60_000})
    capture(worker, 3, 60_001, {1, 2}, write(3, 20.0))
    capture(worker, 4, 60_002, {2, 1}, %APDU.SimpleACK{invoke_id: 4, service: :write_property})

    assert_receive {:event,
                    %{
                      kind: :write_result,
                      details: %{write_id: ^first, outcome: :reply_not_observed}
                    }}

    assert_receive {:event, %{kind: :write_request, details: %{write_id: next, retry: false}}}
    refute next == first

    assert_receive {:event,
                    %{
                      kind: :write_result,
                      details: %{write_id: ^second, outcome: :reply_not_observed}
                    }}
  end

  test "expires incomplete segmented writes and silently releases expired reads", %{
    worker: worker
  } do
    capture(worker, 1, 0, {1, 2}, <<12, 5, 3, 0, 2, 15, 0>>)
    capture(worker, 2, 0, {1, 2}, <<0, 5, 4, 12>>)
    capture(worker, 3, 1, {1, 2}, <<12, 5, 5, 0, 2, 15, 0>>)

    GenServer.cast(worker, {:tick, 60_000})

    assert_receive {:event,
                    %{kind: :write_diagnostic, details: %{invoke_id: 3, reason: :segment_timeout}}}

    capture(worker, 4, 60_001, {1, 2}, write(4, 20.0))
    assert_receive {:event, %{kind: :write_request, details: %{write_id: write_id}}}
    capture(worker, 5, 60_002, {2, 1}, %APDU.SimpleACK{invoke_id: 4, service: :write_property})

    assert_receive {:event,
                    %{
                      kind: :write_result,
                      details: %{write_id: ^write_id, outcome: :acknowledged}
                    }}
  end

  test "keeps recording writes when the pending transaction table fills", %{worker: worker} do
    capture(worker, 1, 0, {1, 2}, write(3, 20.0))
    assert_receive {:event, %{kind: :write_request, details: %{invoke_id: 3}}}

    for source <- 2..4096 do
      capture(worker, source, 1, {source, 1}, <<0, 5, 3, 12>>)
    end

    capture(worker, 4097, 2, {4097, 1}, write(4, 21.0))
    assert_receive {:event, %{kind: :write_request, details: %{invoke_id: 4}}}
    assert_receive {:sc_audit_complete, ^worker, :capture, 0, 2}

    capture(worker, 4098, 3, {2, 1}, %APDU.SimpleACK{invoke_id: 3, service: :write_property})
    GenServer.cast(worker, {:tick, 4})
    assert_receive {:sc_audit_complete, ^worker, :tick, 0, 0}
    refute_received {:event, %{kind: :write_result}}
  end

  test "matches reject and server abort only to the correct sessions and invoke ID", %{
    worker: worker
  } do
    capture(worker, 1, 0, {1, 2}, write(3, 20.0))
    capture(worker, 2, 1, {3, 2}, write(3, 21.0))
    assert_receive {:event, %{__struct__: Event, details: %{write_id: first}}}
    assert_receive {:event, %{__struct__: Event, details: %{write_id: second}}}
    refute first == second

    client_abort = %APDU.Abort{invoke_id: 3, sent_by_server: false, reason: :other}
    reject = %APDU.Reject{invoke_id: 3, reason: :unrecognized_service}
    server_abort = %{client_abort | sent_by_server: true}

    capture(worker, 3, 2, {2, 1}, client_abort)

    capture(worker, 4, 3, {2, 1}, %APDU.SimpleACK{invoke_id: 3, service: :write_property_multiple})

    capture(worker, 5, 4, {2, 3}, reject)
    capture(worker, 6, 5, {2, 1}, server_abort)

    assert_receive {:event,
                    %{
                      __struct__: Event,
                      kind: :write_result,
                      details: %{
                        write_id: ^second,
                        outcome: :rejected,
                        reply: ^reject
                      }
                    }}

    assert_receive {:event,
                    %{
                      __struct__: Event,
                      kind: :write_result,
                      details: %{
                        write_id: ^first,
                        outcome: :aborted,
                        reply: ^server_abort
                      }
                    }}

    refute_receive {:event, %{__struct__: Event, kind: :write_result}}
  end

  test "records a server abort of a partially observed segmented write", %{worker: worker} do
    segment = <<12, 5, 3, 0, 2, 15, 0, 0>>
    capture(worker, 1, 0, {1, 2}, segment)
    abort = %APDU.Abort{invoke_id: 3, sent_by_server: true, reason: :segmentation_not_supported}
    capture(worker, 2, 1, {2, 1}, abort)

    assert_receive {:event,
                    %{
                      __struct__: Event,
                      kind: :write_diagnostic,
                      details: %{write_id: write_id, reason: :reply_before_reassembly}
                    }}

    assert_receive {:event,
                    %{
                      __struct__: Event,
                      kind: :write_result,
                      details: %{write_id: ^write_id, outcome: :aborted, reply: ^abort}
                    }}
  end

  test "invalidates matching after an incomplete segment sequence", %{worker: worker} do
    capture(worker, 1, 0, {1, 2}, write(3, 20.0))
    assert_receive {:event, %{kind: :write_request, details: %{invoke_id: 3}}}

    capture(worker, 2, 1, {1, 2}, <<12, 5, 3, 0, 2, 15, 0>>)
    capture(worker, 3, 2, {1, 2}, <<8, 5, 3, 2, 2, 15, 0>>)
    capture(worker, 4, 3, {1, 2}, <<8, 5, 4, 1, 2, 15, 0>>)

    for invoke <- [3, 4] do
      assert_receive {:event,
                      %{
                        kind: :write_diagnostic,
                        details: %{invoke_id: ^invoke, reason: :incomplete_segment_sequence}
                      }}
    end

    assert_receive {:sc_audit_complete, ^worker, :capture, 0, 1}
    capture(worker, 5, 4, {1, 2}, write(3, 21.0))
    assert_receive {:event, %{kind: :write_request, details: %{invoke_id: 3}}}
    assert_receive {:sc_audit_complete, ^worker, :capture, 0, 1}

    capture(worker, 6, 5, {2, 1}, %APDU.SimpleACK{invoke_id: 3, service: :write_property})
    GenServer.cast(worker, {:tick, 6})
    assert_receive {:sc_audit_complete, ^worker, :tick, 0, 0}
    refute_received {:event, %{kind: :write_result}}
  end

  test "leaves early replies unassigned across overlapping writes and capture gaps",
       %{worker: worker} do
    capture(worker, 1, 0, {1, 2}, write(3, 20.0))
    assert_receive {:event, %{kind: :write_request}}

    segment = <<12, 5, 3, 0, 2, 15, 0>>
    abort = %APDU.Abort{invoke_id: 3, sent_by_server: true, reason: :segmentation_not_supported}
    capture(worker, 2, 1, {1, 2}, segment)
    capture(worker, 3, 2, {2, 1}, %APDU.SimpleACK{invoke_id: 3, service: :write_property})
    capture(worker, 4, 3, {2, 1}, abort)

    assert_receive {:event,
                    %{kind: :write_diagnostic, details: %{reason: :reply_before_reassembly}}}

    assert_receive {:sc_audit_complete, ^worker, :capture, 0, 2}

    GenServer.cast(worker, :gap)
    capture(worker, 6, 4, {1, 2}, segment)
    capture(worker, 7, 5, {2, 1}, abort)

    assert_receive {:event,
                    %{kind: :write_diagnostic, details: %{reason: :reply_before_reassembly}}}

    assert_receive {:sc_audit_complete, ^worker, :capture, 0, 1}
    refute_received {:event, %{kind: :write_result}}
  end

  test "leaves overlapping requests and replies after a capture gap unassigned", %{worker: worker} do
    capture(worker, 1, 0, {1, 2}, write(3, 20.0))
    capture(worker, 2, 1, {1, 2}, write(3, 21.0))
    capture(worker, 3, 2, {1, 2}, write(4, 22.0))

    for _attempt <- 1..3 do
      assert_receive {:event, %{__struct__: Event, kind: :write_request}}
    end

    ack = %APDU.SimpleACK{invoke_id: 3, service: :write_property}
    capture(worker, 4, 3, {2, 1}, ack)
    GenServer.cast(worker, :gap)
    capture(worker, 6, 4, {1, 2}, write(4, 23.0))
    capture(worker, 7, 5, {2, 1}, %{ack | invoke_id: 4})

    assert_receive {:sc_audit_complete, ^worker, :capture, 0, 2}
    assert_receive {:sc_audit_complete, ^worker, :gap, 0, 1}
    assert_receive {:sc_audit_complete, ^worker, :capture, 0, 1}
    assert_receive {:event, %{__struct__: Event, kind: :write_request}}
    refute_receive {:event, %{__struct__: Event, kind: :write_result}}

    capture(worker, 8, 60_004, {1, 2}, write(4, 24.0))

    assert_receive {:event,
                    %{__struct__: Event, kind: :write_request, details: %{write_id: recovered}}}

    capture(worker, 9, 60_005, {2, 1}, %{ack | invoke_id: 4})

    assert_receive {:event,
                    %{__struct__: Event, kind: :write_result, details: %{write_id: ^recovered}}}
  end

  defp write(invoke, value) do
    {:ok, apdu} =
      WriteProperty.to_apdu(
        %WriteProperty{
          object_identifier: %ObjectIdentifier{type: :analog_output, instance: 1},
          property_identifier: :present_value,
          property_array_index: nil,
          property_value: Encoding.create!({:real, value}),
          priority: 8
        },
        invoke_id: invoke
      )

    apdu
  end

  defp capture(worker, sequence, time, {source, destination}, apdu, opts \\ []) do
    bytes = if is_binary(apdu), do: apdu, else: EncoderProtocol.encode(apdu)

    frame = %BVLC{
      function: Keyword.get(opts, :function, :npdu),
      id: sequence,
      source: nil,
      destination: if(destination, do: <<destination::48>>, else: BVLC.broadcast()),
      destination_options: [],
      data_options: [],
      payload: IO.iodata_to_binary([Keyword.get(opts, :npci, <<1, 0>>), bytes])
    }

    GenServer.cast(
      worker,
      {:capture,
       %{
         capture_id: {<<0::128>>, sequence},
         timestamp: DateTime.utc_now(),
         monotonic_time: time,
         hub: %{uuid: <<0::128>>, vmac: <<0::48>>},
         ingress: peer(source),
         egress: if(destination, do: peer(destination)),
         ingress_session: source,
         egress_session: destination,
         destination_vmac: frame.destination,
         routing: {:queued, 1},
         frame: frame
       }}
    )
  end

  defp peer(id),
    do: %{
      uuid: <<id::128>>,
      vmac: <<id::48>>,
      remote: {{127, 0, 0, 1}, id},
      certificate_sha256: nil
    }
end
