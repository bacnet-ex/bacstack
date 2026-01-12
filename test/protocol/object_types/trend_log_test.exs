defmodule BACnet.Test.Protocol.ObjectTypes.TrendLogTest do
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.LogRecord
  alias BACnet.Protocol.LogStatus
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.ObjectTypes.TrendLog

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_trend_log

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "verify create/4 fails with log_interval = 1 and cov" do
    assert {:error, {:invalid_property_value_for_logging_type, :log_interval}} =
             TrendLog.create(1, "TEST", %{
               buffer_size: 100,
               log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
               log_interval: 1,
               logging_type: :cov
             })
  end

  test "verify create/4 fails with log_interval = 0 and polled" do
    assert {:error, {:invalid_property_value_for_logging_type, :log_interval}} =
             TrendLog.create(1, "TEST", %{
               buffer_size: 100,
               log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
               log_interval: 0,
               logging_type: :polled
             })
  end

  test "verify create/4 succeeds with any log_interval and triggered" do
    assert {:ok, %{log_interval: 0, logging_type: :triggered}} =
             TrendLog.create(1, "TEST", %{
               buffer_size: 100,
               log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
               log_interval: 0,
               logging_type: :triggered
             })

    assert {:ok, %{log_interval: 1, logging_type: :triggered}} =
             TrendLog.create(1, "TEST", %{
               buffer_size: 100,
               log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
               log_interval: 1,
               logging_type: :triggered
             })
  end

  test "verify create/4 verifies clock_aligned_logging and requires both properties" do
    assert {:error, {:missing_required_property, _property}} =
             TrendLog.create(
               1,
               "TEST",
               %{
                 buffer_size: 100,
                 log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
                 log_interval: 0,
                 logging_type: :triggered
               },
               clock_aligned_logging: true
             )
  end

  test "verify create/4 verifies clock_aligned_logging and requires property align_intervals" do
    assert {:error, {:missing_required_property, :align_intervals}} =
             TrendLog.create(
               1,
               "TEST",
               %{
                 interval_offset: 0,
                 buffer_size: 100,
                 log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
                 log_interval: 0,
                 logging_type: :triggered
               },
               clock_aligned_logging: true
             )
  end

  test "verify create/4 verifies clock_aligned_logging and requires property interval_offset" do
    assert {:error, {:missing_required_property, :interval_offset}} =
             TrendLog.create(
               1,
               "TEST",
               %{
                 align_intervals: false,
                 buffer_size: 100,
                 log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
                 log_interval: 0,
                 logging_type: :triggered
               },
               clock_aligned_logging: true
             )
  end

  test "verify create/4 verifies clock_aligned_logging and with both properties succeeds" do
    assert {:ok, %TrendLog{}} =
             TrendLog.create(
               1,
               "TEST",
               %{
                 align_intervals: false,
                 interval_offset: 0,
                 buffer_size: 100,
                 log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
                 log_interval: 0,
                 logging_type: :triggered
               },
               clock_aligned_logging: true
             )
  end

  test "verify property_writable?/2 for log_interval and cov is true" do
    {:ok, obj} =
      TrendLog.create(1, "TEST", %{
        buffer_size: 100,
        log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
        log_interval: 0,
        logging_type: :cov
      })

    assert true == TrendLog.property_writable?(obj, :log_interval)
  end

  test "verify property_writable?/2 for log_interval and polled is true" do
    {:ok, obj} =
      TrendLog.create(1, "TEST", %{
        buffer_size: 100,
        log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
        log_interval: 1,
        logging_type: :polled
      })

    assert true == TrendLog.property_writable?(obj, :log_interval)
  end

  test "verify property_writable?/2 for log_interval and triggered is false" do
    {:ok, obj} =
      TrendLog.create(1, "TEST", %{
        buffer_size: 100,
        log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
        log_interval: 0,
        logging_type: :triggered
      })

    assert false == TrendLog.property_writable?(obj, :log_interval)
  end

  test "verify property_writable?/2 for buffer_size and enabled is false" do
    {:ok, obj} =
      TrendLog.create(1, "TEST", %{
        buffer_size: 100,
        enable: true,
        log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
        log_interval: 0,
        logging_type: :triggered
      })

    assert false == TrendLog.property_writable?(obj, :buffer_size)
  end

  test "verify property_writable?/2 for buffer_size and disabled is true" do
    {:ok, obj} =
      TrendLog.create(1, "TEST", %{
        buffer_size: 100,
        enable: false,
        log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
        log_interval: 0,
        logging_type: :triggered
      })

    assert true == TrendLog.property_writable?(obj, :buffer_size)
  end

  test "verify property_writable?/2 for any other works" do
    {:ok, obj} =
      TrendLog.create(1, "TEST", %{
        buffer_size: 100,
        enable: false,
        log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
        log_interval: 0,
        logging_type: :triggered
      })

    assert true == TrendLog.property_writable?(obj, :logging_type)
  end

  test "verify update_property/3 for buffer_size accepts valid lists" do
    {:ok, obj} =
      TrendLog.create(1, "TEST", %{
        buffer_size: 1,
        log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
        log_interval: 0,
        logging_type: :triggered
      })

    assert {:ok, %{}} =
             TrendLog.update_property(obj, :log_buffer, [
               %LogRecord{
                 timestamp: ObjectsMacro.get_default_bacnet_datetime(),
                 log_datum: {:time_change, 0.0},
                 status_flags: nil
               }
             ])
  end

  test "verify update_property/3 for buffer_size accepts rejects too large lists" do
    {:ok, obj} =
      TrendLog.create(1, "TEST", %{
        buffer_size: 1,
        log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
        log_interval: 0,
        logging_type: :triggered
      })

    assert {:error, {:value_failed_property_validation, :log_buffer}} =
             TrendLog.update_property(obj, :log_buffer, [
               %LogRecord{
                 timestamp: ObjectsMacro.get_default_bacnet_datetime(),
                 log_datum: {:time_change, 0.0},
                 status_flags: nil
               },
               %LogRecord{
                 timestamp: ObjectsMacro.get_default_bacnet_datetime(),
                 log_datum: {:time_change, 1.0},
                 status_flags: nil
               }
             ])
  end

  test "verify update_property/3 for log_interval = 0 sets logging_type = cov" do
    {:ok, obj} =
      TrendLog.create(1, "TEST", %{
        buffer_size: 100,
        log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
        log_interval: 1,
        logging_type: :triggered
      })

    assert {:ok, %{log_interval: 0, logging_type: :cov}} =
             TrendLog.update_property(obj, :log_interval, 0)
  end

  test "verify update_property/3 for log_interval = 1 sets logging_type = polled" do
    {:ok, obj} =
      TrendLog.create(1, "TEST", %{
        buffer_size: 100,
        log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
        log_interval: 0,
        logging_type: :triggered
      })

    assert {:ok, %{log_interval: 1, logging_type: :polled}} =
             TrendLog.update_property(obj, :log_interval, 1)
  end

  test "verify update_property/3 for record_count = 0 truncates log_buffer" do
    {:ok, obj} =
      TrendLog.create(1, "TEST", %{
        buffer_size: 100,
        log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
        log_interval: 0,
        logging_type: :triggered,
        log_buffer: [
          %LogRecord{
            timestamp: ObjectsMacro.get_default_bacnet_datetime(),
            log_datum: {:time_change, 0.0},
            status_flags: nil
          }
        ],
        record_count: 1
      })

    assert {:ok,
            %{
              record_count: 1,
              log_buffer: [
                %LogRecord{
                  timestamp: %BACnetDateTime{},
                  log_datum: %LogStatus{
                    log_disabled: false,
                    buffer_purged: true,
                    log_interrupted: false
                  },
                  status_flags: nil
                }
              ],
              records_since_notification: nil
            }} = TrendLog.update_property(obj, :record_count, 0)
  end

  test "verify update_property/3 intrinsic for record_count = 0 truncates log_buffer" do
    {:ok, obj} =
      TrendLog.create(
        1,
        "TEST",
        %{
          buffer_size: 100,
          log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
          log_interval: 0,
          logging_type: :triggered,
          log_buffer: [
            %LogRecord{
              timestamp: ObjectsMacro.get_default_bacnet_datetime(),
              log_datum: {:time_change, 0.0},
              status_flags: nil
            }
          ],
          record_count: 1,
          records_since_notification: 1
        },
        intrinsic_reporting: true
      )

    assert {:ok,
            %{
              record_count: 1,
              log_buffer: [
                %LogRecord{
                  timestamp: %BACnetDateTime{},
                  log_datum: %LogStatus{
                    log_disabled: false,
                    buffer_purged: true,
                    log_interrupted: false
                  },
                  status_flags: nil
                }
              ],
              records_since_notification: 0
            }} = TrendLog.update_property(obj, :record_count, 0)
  end

  test "verify update_property/3 for record_count > 0 fails" do
    {:ok, obj} =
      TrendLog.create(1, "TEST", %{
        buffer_size: 100,
        log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
        log_interval: 0,
        logging_type: :triggered
      })

    assert {:error, {:invalid_property_value, :record_count}} =
             TrendLog.update_property(obj, :record_count, 1)
  end
end
