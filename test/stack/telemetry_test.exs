defmodule BACnet.Stack.TelemetryTest do
  alias BACnet.Protocol.APDU.Reject, warn: false
  alias BACnet.Protocol.APDU.SegmentACK, warn: false
  alias BACnet.Protocol.APDU.UnconfirmedServiceRequest, warn: false
  alias BACnet.Protocol.BACnetError, warn: false
  alias BACnet.Protocol.DeviceObjectPropertyRef, warn: false
  alias BACnet.Protocol.DeviceObjectRef, warn: false
  alias BACnet.Protocol.IncompleteAPDU, warn: false
  alias BACnet.Protocol.NPCI, warn: false
  alias BACnet.Stack.BBMD, warn: false
  alias BACnet.Stack.Client, warn: false
  alias BACnet.Stack.ForeignDevice, warn: false
  alias BACnet.Stack.Segmentator, warn: false
  alias BACnet.Stack.SegmentsStore, warn: false
  alias BACnet.Stack.Telemetry, warn: false
  alias BACnet.Stack.TrendLogger, warn: false

  use ExUnit.Case, async: true

  @moduletag :telemetry

  # Telemetry tests fail always on Elixir < 1.15, so just skip it
  if Version.compare(System.version(), "1.15.0") != :lt do
    doctest Telemetry

    @path Path.join([
            Path.dirname(__ENV__.file),
            "..",
            "..",
            "lib",
            "bacnet",
            "stack",
            "telemetry.ex"
          ])

    setup do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          # BBMD
          [:bacstack, :bbmd, :exception],
          [:bacstack, :bbmd, :foreign_device, :delete],
          [:bacstack, :bbmd, :foreign_device, :add],
          [:bacstack, :bbmd, :foreign_device, :read_table],
          [:bacstack, :bbmd, :broadcast_distribution, :distribute],
          [:bacstack, :bbmd, :broadcast_distribution, :read_table],
          [:bacstack, :bbmd, :broadcast_distribution, :write_table],

          # Client
          [:bacstack, :client, :exception],
          [:bacstack, :client, :incoming_apdu],
          [:bacstack, :client, :incoming_apdu, :error],
          [:bacstack, :client, :incoming_apdu, :duplicated],
          [:bacstack, :client, :incoming_apdu, :start],
          [:bacstack, :client, :incoming_apdu, :rejected],
          [:bacstack, :client, :incoming_apdu, :segmented, :completed],
          [:bacstack, :client, :incoming_apdu, :segmented, :incomplete],
          [:bacstack, :client, :incoming_apdu, :segmented, :error],
          [:bacstack, :client, :incoming_apdu, :stop],
          [:bacstack, :client, :request, :start],
          [:bacstack, :client, :request, :stop],
          [:bacstack, :client, :send],
          [:bacstack, :client, :send, :error],
          [:bacstack, :client, :transport, :message],

          # Foreign Device
          [:bacstack, :foreign_device, :exception],
          [:bacstack, :foreign_device, :broadcast_distribution, :distribute],
          [:bacstack, :foreign_device, :broadcast_distribution, :read_table],
          [:bacstack, :foreign_device, :broadcast_distribution, :write_table],
          [:bacstack, :foreign_device, :foreign_device, :read_table],
          [:bacstack, :foreign_device, :foreign_device, :add],
          [:bacstack, :foreign_device, :foreign_device, :delete],

          # Segmentator
          [:bacstack, :segmentator, :exception],
          [:bacstack, :segmentator, :sequence, :ack],
          [:bacstack, :segmentator, :sequence, :error],
          [:bacstack, :segmentator, :sequence, :start],
          [:bacstack, :segmentator, :sequence, :segment],
          [:bacstack, :segmentator, :sequence, :stop],

          # Segments Store
          [:bacstack, :segments_store, :exception],
          [:bacstack, :segments_store, :sequence, :ack],
          [:bacstack, :segments_store, :sequence, :error],
          [:bacstack, :segments_store, :sequence, :start],
          [:bacstack, :segments_store, :sequence, :segment],
          [:bacstack, :segments_store, :sequence, :stop],

          # Trend Logger
          [:bacstack, :trend_logger, :exception],
          [:bacstack, :trend_logger, :log_object, :start],
          [:bacstack, :trend_logger, :log_object, :stop],
          [:bacstack, :trend_logger, :log_object, :notify],
          [:bacstack, :trend_logger, :log_object, :trigger],
          [:bacstack, :trend_logger, :log_object, :update],
          [:bacstack, :trend_logger, :lookup_object, :cov_sub],
          [:bacstack, :trend_logger, :lookup_object, :cov_unsub],
          [:bacstack, :trend_logger, :lookup_object, :error],
          [:bacstack, :trend_logger, :lookup_object, :start],
          [:bacstack, :trend_logger, :lookup_object, :stop]
        ])

      on_exit(fn -> :telemetry.detach(ref) end)

      %{telemetry_ref: ref}
    end

    @tag :no_cover
    @tag skip: "--cover" in System.argv()
    test "assert compiling without telemetry (no_telemetry) has " <>
           "the same functions defined as normal implementation" do
      # Ignore module conflict warning for the duration of this test
      Code.put_compiler_option(:ignore_module_conflict, true)

      # First compile and load using NO telemetry
      Application.put_env(:bacstack, :no_telemetry, true)
      [{Telemetry, _bin}] = Code.compile_file(@path)

      refute Telemetry.compiled_with_telemetry()
      non_functions = Telemetry.__info__(:functions)

      # Then compile and load using WITH telemetry
      Application.put_env(:bacstack, :no_telemetry, false)
      [{Telemetry, _bin}] = Code.compile_file(@path)

      assert Telemetry.compiled_with_telemetry()
      tele_functions = Telemetry.__info__(:functions)

      # Put the default value back
      Code.put_compiler_option(:ignore_module_conflict, false)

      assert ^non_functions = tele_functions
    end

    test "assert basic metadata contains keys" do
      assert %{monotonic_time: _time, system_time: _os_time} =
               Telemetry.get_telemetry_measurements(%{})

      # Assert the given map OVERRIDES the basic map
      assert %{monotonic_time: false, system_time: _os_time} =
               Telemetry.get_telemetry_measurements(%{monotonic_time: false})
    end

    test "call telemetry bbmd exception function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok = Telemetry.execute_bbmd_exception(self(), nil, nil, [], %{}, struct(BBMD.State, []))

      assert_receive {[:bacstack, :bbmd, :exception], ^telemetry_ref, %{monotonic_time: _time},
                      %{self: _self}}
    end

    test "call telemetry bbmd delete FD registration function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_bbmd_del_fd_registration(
          self(),
          nil,
          struct(BBMD.Registration, []),
          struct(BBMD.State, [])
        )

      assert_receive {[:bacstack, :bbmd, :foreign_device, :delete], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry bbmd add FD registration function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_bbmd_add_fd_registration(
          self(),
          nil,
          struct(BBMD.Registration, []),
          struct(BBMD.State, [])
        )

      assert_receive {[:bacstack, :bbmd, :foreign_device, :add], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry bbmd read FD table function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok = Telemetry.execute_bbmd_read_fd_table(self(), nil, %{}, struct(BBMD.State, []))

      assert_receive {[:bacstack, :bbmd, :foreign_device, :read_table], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry bbmd distribute broadcast function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_bbmd_distribute_broadcast(
          self(),
          nil,
          :original_broadcast,
          "",
          struct(NPCI, []),
          struct(BBMD.State, [])
        )

      assert_receive {[:bacstack, :bbmd, :broadcast_distribution, :distribute], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry bbmd read bdt function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok = Telemetry.execute_bbmd_read_bdt(self(), nil, [], struct(BBMD.State, []))

      assert_receive {[:bacstack, :bbmd, :broadcast_distribution, :read_table], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry bbmd write bdt function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok = Telemetry.execute_bbmd_write_bdt(self(), nil, [], struct(BBMD.State, []))

      assert_receive {[:bacstack, :bbmd, :broadcast_distribution, :write_table], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry client exception function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_client_exception(self(), nil, nil, [], %{}, struct(Client.State, []))

      assert_receive {[:bacstack, :client, :exception], ^telemetry_ref, %{monotonic_time: _time},
                      %{self: _self}}
    end

    test "call telemetry client incoming APDU function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_client_inc_apdu(
          self(),
          nil,
          nil,
          struct(NPCI, []),
          nil,
          struct(Client.State, [])
        )

      assert_receive {[:bacstack, :client, :incoming_apdu], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry client incoming APDU decode error function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_client_inc_apdu_decode_error(
          self(),
          nil,
          nil,
          struct(NPCI, []),
          "",
          nil,
          struct(Client.State, [])
        )

      assert_receive {[:bacstack, :client, :incoming_apdu, :error], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry client incomign APDU duplicated function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_client_inc_apdu_duplicated(
          self(),
          nil,
          nil,
          struct(NPCI, []),
          "",
          struct(Client.State, [])
        )

      assert_receive {[:bacstack, :client, :incoming_apdu, :duplicated], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry client incoming APDU handled function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_client_inc_apdu_handled(
          self(),
          nil,
          nil,
          struct(NPCI, []),
          "",
          struct(Client.State, [])
        )

      assert_receive {[:bacstack, :client, :incoming_apdu, :start], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry client incoming APDU rejected function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_client_inc_apdu_rejected(
          self(),
          nil,
          nil,
          struct(NPCI, []),
          struct(Reject, []),
          "",
          struct(Client.State, [])
        )

      assert_receive {[:bacstack, :client, :incoming_apdu, :rejected], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry client incoming APDU segmented completed function and assert reception",
         %{
           telemetry_ref: telemetry_ref
         } do
      :ok =
        Telemetry.execute_client_inc_apdu_segmentation_completed(
          self(),
          nil,
          nil,
          struct(NPCI, []),
          "",
          "",
          struct(IncompleteAPDU, []),
          struct(Client.State, [])
        )

      assert_receive {[:bacstack, :client, :incoming_apdu, :segmented, :completed],
                      ^telemetry_ref, %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry client incoming APDU segmented incomplete function and assert reception",
         %{telemetry_ref: telemetry_ref} do
      :ok =
        Telemetry.execute_client_inc_apdu_segmentation_incomplete(
          self(),
          nil,
          nil,
          struct(NPCI, []),
          "",
          struct(IncompleteAPDU, []),
          struct(Client.State, [])
        )

      assert_receive {[:bacstack, :client, :incoming_apdu, :segmented, :incomplete],
                      ^telemetry_ref, %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry client incoming APDU segmented error function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_client_inc_apdu_segmentation_error(
          self(),
          nil,
          nil,
          struct(NPCI, []),
          "",
          struct(IncompleteAPDU, []),
          nil,
          false,
          struct(Client.State, [])
        )

      assert_receive {[:bacstack, :client, :incoming_apdu, :segmented, :error], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry client incoming APDU reply function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_client_inc_apdu_reply(
          self(),
          "",
          [],
          struct(Client.ReplyTimer, monotonic_time: System.monotonic_time()),
          struct(Client.State, [])
        )

      assert_receive {[:bacstack, :client, :incoming_apdu, :stop], ^telemetry_ref,
                      %{monotonic_time: _time, duration: _dur}, %{self: _self}}
    end

    test "call telemetry client incoming APDU timed out function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_client_inc_apdu_timeout(
          self(),
          struct(Client.ReplyTimer, monotonic_time: System.monotonic_time()),
          struct(Client.State, [])
        )

      assert_receive {[:bacstack, :client, :incoming_apdu, :stop], ^telemetry_ref,
                      %{monotonic_time: _time, duration: _dur}, %{self: _self}}
    end

    test "call telemetry client request start function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_client_request_start(
          self(),
          nil,
          "",
          [],
          struct(Client.ApduTimer, monotonic_time: System.monotonic_time()),
          struct(Client.State, [])
        )

      assert_receive {[:bacstack, :client, :request, :start], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry client request stop function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_client_request_stop(
          self(),
          nil,
          nil,
          nil,
          nil,
          struct(Client.ApduTimer, monotonic_time: System.monotonic_time()),
          struct(Client.State, [])
        )

      assert_receive {[:bacstack, :client, :request, :stop], ^telemetry_ref,
                      %{monotonic_time: _time, duration: _dur}, %{self: _self}}
    end

    test "call telemetry client request stop timer function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_client_request_apdu_timer(
          self(),
          struct(Client.ApduTimer, monotonic_time: System.monotonic_time()),
          struct(Client.State, [])
        )

      assert_receive {[:bacstack, :client, :request, :stop], ^telemetry_ref,
                      %{monotonic_time: _time, duration: _dur}, %{self: _self}}
    end

    test "call telemetry client send function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok = Telemetry.execute_client_send(self(), nil, nil, [], false, struct(Client.State, []))

      assert_receive {[:bacstack, :client, :send], ^telemetry_ref, %{monotonic_time: _time},
                      %{self: _self}}
    end

    test "call telemetry client send error function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_client_send_error(
          self(),
          nil,
          "",
          [],
          "",
          :error,
          struct(Client.State, [])
        )

      assert_receive {[:bacstack, :client, :send, :error], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry client transport message function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok = Telemetry.execute_client_transport_message(self(), {}, struct(Client.State, []))

      assert_receive {[:bacstack, :client, :transport, :message], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry foreign device exception function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_foreign_device_exception(
          self(),
          nil,
          nil,
          [],
          %{},
          struct(ForeignDevice.State, [])
        )

      assert_receive {[:bacstack, :foreign_device, :exception], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry foreign device distribute broadcast function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_foreign_device_distribute_broadcast(
          self(),
          {{}, 47_808},
          struct(UnconfirmedServiceRequest, []),
          [],
          struct(ForeignDevice.State, [])
        )

      assert_receive {[:bacstack, :foreign_device, :broadcast_distribution, :distribute],
                      ^telemetry_ref, %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry foreign device read BDT function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_foreign_device_read_bdt(
          self(),
          {{}, 47_808},
          [],
          struct(ForeignDevice.State, [])
        )

      assert_receive {[:bacstack, :foreign_device, :broadcast_distribution, :read_table],
                      ^telemetry_ref, %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry foreign device write BDT function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_foreign_device_write_bdt(
          self(),
          {{}, 47_808},
          [],
          struct(ForeignDevice.State, [])
        )

      assert_receive {[:bacstack, :foreign_device, :broadcast_distribution, :write_table],
                      ^telemetry_ref, %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry foreign device read FD table function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_foreign_device_read_fd_table(
          self(),
          {{}, 47_808},
          [],
          struct(ForeignDevice.State, [])
        )

      assert_receive {[:bacstack, :foreign_device, :foreign_device, :read_table], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry foreign device add FD registration function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_foreign_device_add_fd_registration(
          self(),
          {{}, 47_808},
          struct(ForeignDevice.Registration, []),
          struct(ForeignDevice.State, [])
        )

      assert_receive {[:bacstack, :foreign_device, :foreign_device, :add], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry foreign device delete FD registration function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_foreign_device_del_fd_registration(
          self(),
          {{}, 47_808},
          struct(ForeignDevice.Registration, []),
          struct(ForeignDevice.State, [])
        )

      assert_receive {[:bacstack, :foreign_device, :foreign_device, :delete], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry segmentator exception function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_segmentator_exception(
          self(),
          nil,
          nil,
          [],
          %{},
          struct(Segmentator.State, [])
        )

      assert_receive {[:bacstack, :segmentator, :exception], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry segmentator segment ack function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_segmentator_sequence_ack(
          self(),
          struct(Segmentator.Sequence, []),
          struct(SegmentACK, []),
          struct(Segmentator.State, [])
        )

      assert_receive {[:bacstack, :segmentator, :sequence, :ack], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry segmentator segment error function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_segmentator_sequence_error(
          self(),
          __MODULE__,
          self(),
          self(),
          nil,
          nil,
          nil,
          nil,
          :other,
          struct(Segmentator.State, [])
        )

      assert_receive {[:bacstack, :segmentator, :sequence, :error], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry segmentator segment start function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_segmentator_sequence_start(
          self(),
          struct(Segmentator.Sequence, []),
          struct(Segmentator.State, [])
        )

      assert_receive {[:bacstack, :segmentator, :sequence, :start], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry segmentator segment segment function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_segmentator_sequence_segment(
          self(),
          struct(Segmentator.Sequence, []),
          1,
          struct(Segmentator.State, [])
        )

      assert_receive {[:bacstack, :segmentator, :sequence, :segment], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry segmentator segment stop function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_segmentator_sequence_stop(
          self(),
          struct(Segmentator.Sequence, monotonic_time: System.monotonic_time()),
          :completed,
          struct(Segmentator.State, [])
        )

      assert_receive {[:bacstack, :segmentator, :sequence, :stop], ^telemetry_ref,
                      %{monotonic_time: _time, duration: _dur}, %{self: _self}}
    end

    test "call telemetry segments store exception function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_segments_store_exception(
          self(),
          nil,
          nil,
          [],
          %{},
          struct(SegmentsStore.State, [])
        )

      assert_receive {[:bacstack, :segments_store, :exception], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry segments store segment ack function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_segments_store_sequence_ack(
          self(),
          struct(SegmentsStore.Sequence, []),
          struct(SegmentACK, []),
          struct(SegmentsStore.State, [])
        )

      assert_receive {[:bacstack, :segments_store, :sequence, :ack], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry segments store segment error function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_segments_store_sequence_error(
          self(),
          __MODULE__,
          self(),
          nil,
          nil,
          nil,
          nil,
          :other,
          struct(SegmentsStore.State, [])
        )

      assert_receive {[:bacstack, :segments_store, :sequence, :error], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry segments store segment start function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_segments_store_sequence_start(
          self(),
          struct(SegmentsStore.Sequence, []),
          struct(SegmentsStore.State, [])
        )

      assert_receive {[:bacstack, :segments_store, :sequence, :start], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry segments store segment segment function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_segments_store_sequence_segment(
          self(),
          struct(SegmentsStore.Sequence, []),
          1,
          struct(SegmentsStore.State, [])
        )

      assert_receive {[:bacstack, :segments_store, :sequence, :segment], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry segments store segment stop function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_segments_store_sequence_stop(
          self(),
          struct(SegmentsStore.Sequence, monotonic_time: System.monotonic_time()),
          :completed,
          struct(SegmentsStore.State, [])
        )

      assert_receive {[:bacstack, :segments_store, :sequence, :stop], ^telemetry_ref,
                      %{monotonic_time: _time, duration: _dur}, %{self: _self}}
    end

    test "call telemetry trendlogger exception function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_trend_logger_exception(
          self(),
          nil,
          nil,
          [],
          %{},
          struct(TrendLogger.State, [])
        )

      assert_receive {[:bacstack, :trend_logger, :exception], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry trendlogger log start function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_trend_logger_log_start(
          self(),
          struct(TrendLogger.Log, []),
          struct(TrendLogger.State, [])
        )

      assert_receive {[:bacstack, :trend_logger, :log_object, :start], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry trendlogger log stop function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_trend_logger_log_stop(
          self(),
          struct(TrendLogger.Log, []),
          struct(TrendLogger.State, [])
        )

      assert_receive {[:bacstack, :trend_logger, :log_object, :stop], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry trendlogger log notify function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_trend_logger_log_notify(
          self(),
          struct(TrendLogger.Log, []),
          :buffer_full,
          struct(TrendLogger.State, [])
        )

      assert_receive {[:bacstack, :trend_logger, :log_object, :notify], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry trendlogger log trigger function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_trend_logger_log_trigger(
          self(),
          struct(TrendLogger.Log, []),
          :interrupted,
          struct(TrendLogger.State, [])
        )

      assert_receive {[:bacstack, :trend_logger, :log_object, :trigger], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry trendlogger log update function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_trend_logger_log_update(
          self(),
          struct(TrendLogger.Log, []),
          :buffer,
          struct(TrendLogger.State, [])
        )

      assert_receive {[:bacstack, :trend_logger, :log_object, :update], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry trendlogger log cov sub function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_trend_logger_cov_sub(
          self(),
          struct(DeviceObjectPropertyRef, [])
        )

      assert_receive {[:bacstack, :trend_logger, :lookup_object, :cov_sub], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry trendlogger log cov unsub function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_trend_logger_cov_unsub(
          self(),
          struct(DeviceObjectPropertyRef, [])
        )

      assert_receive {[:bacstack, :trend_logger, :lookup_object, :cov_unsub], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry trendlogger log lookup object error function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_trend_logger_lookup_object_error(
          self(),
          struct(DeviceObjectRef, []),
          struct(BACnetError, []),
          500
        )

      assert_receive {[:bacstack, :trend_logger, :lookup_object, :error], ^telemetry_ref,
                      %{monotonic_time: _time, duration: 500}, %{self: _self}}
    end

    test "call telemetry trendlogger log lookup object start function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_trend_logger_lookup_object_start(
          self(),
          struct(DeviceObjectRef, [])
        )

      assert_receive {[:bacstack, :trend_logger, :lookup_object, :start], ^telemetry_ref,
                      %{monotonic_time: _time}, %{self: _self}}
    end

    test "call telemetry trendlogger log lookup object stop function and assert reception", %{
      telemetry_ref: telemetry_ref
    } do
      :ok =
        Telemetry.execute_trend_logger_lookup_object_stop(
          self(),
          struct(DeviceObjectRef, []),
          %{},
          500
        )

      assert_receive {[:bacstack, :trend_logger, :lookup_object, :stop], ^telemetry_ref,
                      %{monotonic_time: _time, duration: 500}, %{self: _self}}
    end
  end
end
