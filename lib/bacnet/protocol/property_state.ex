defmodule BACnet.Protocol.PropertyState do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants
  require Constants

  @typedoc """
  Represents the value type for property states.

  The name for each value type represents the property state type (`t:Constants.property_state/0`).
  """
  @type value ::
          (boolean_value :: boolean())
          | (binary_value :: boolean())
          | (event_type :: Constants.event_type())
          | (polarity :: Constants.polarity())
          | (program_change :: Constants.program_request())
          | (program_state :: Constants.program_state())
          | (reason_for_halt :: Constants.program_error())
          | (reliability :: Constants.reliability())
          | (state :: Constants.event_state())
          | (system_status :: Constants.device_status())
          | (units :: Constants.engineering_unit())
          | (unsigned_value :: non_neg_integer())
          | (life_safety_mode :: Constants.life_safety_mode())
          | (life_safety_state :: Constants.life_safety_state())
          | (restart_reason :: Constants.restart_reason())
          | (door_alarm_state :: Constants.door_alarm_state())
          | (action :: Constants.action())
          | (door_secured_status :: Constants.door_secured_status())
          | (door_status :: Constants.door_status())
          | (door_value :: Constants.door_value())
          | (file_access_method :: Constants.file_access_method())
          | (lock_status :: Constants.lock_status())
          | (life_safety_operation :: Constants.life_safety_operation())
          | (maintenance :: Constants.maintenance())
          | (node_type :: Constants.node_type())
          | (notify_type :: Constants.notify_type())
          | (security_level :: Constants.security_level())
          | (shed_state :: Constants.shed_state())
          | (silenced_state :: Constants.silenced_state())
          | (backup_state :: Constants.backup_state())
          | (write_status :: Constants.write_status())
          | (lighting_in_progress :: Constants.lighting_in_progress())
          | (lighting_operation :: Constants.lighting_operation())
          | (lighting_transition :: Constants.lighting_transition())
          | (integer_value :: integer())

  @typedoc """
  Represents a BACnet property state.
  """
  @type t :: %__MODULE__{
          type: Constants.property_state(),
          value: value()
        }

  @fields [
    :type,
    :value
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnet property state into application tags encoding.
  """
  @spec encode(t(), Keyword.t()) :: {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = state, opts \\ []) do
    with {:ok, encoding} <- do_encode(state, opts) do
      {:ok, [encoding]}
    end
  end

  @doc """
  Parses a BACnet property state from application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}} | {:error, term()}
  def parse(tags) when is_list(tags) do
    with [head | rest] <- tags,
         {:ok, result} <- do_parse(head) do
      {:ok, {result, rest}}
    else
      [] -> {:error, :invalid_tags}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Validates whether the given property state is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(t)

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :boolean_value),
          value: value
        } = _t
      )
      when is_boolean(value),
      do: true

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :binary_value),
          value: value
        } = _t
      )
      when is_boolean(value),
      do: true

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :event_type),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:event_type, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :polarity),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:polarity, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :program_change),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:program_request, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :program_state),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:program_state, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :reason_for_halt),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:program_error, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :reliability),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:reliability, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :state),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:event_state, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :system_status),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:device_status, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :units),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:engineering_unit, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :unsigned_value),
          value: value
        } = _t
      )
      when is_integer(value) and value >= 0,
      do: true

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :life_safety_mode),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:life_safety_mode, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :life_safety_state),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:life_safety_state, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :restart_reason),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:restart_reason, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :door_alarm_state),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:door_alarm_state, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :action),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:action, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :door_secured_status),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:door_secured_status, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :door_status),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:door_status, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :door_value),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:door_value, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :file_access_method),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:file_access_method, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :lock_status),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:lock_status, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :life_safety_operation),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:life_safety_operation, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :maintenance),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:maintenance, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :node_type),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:node_type, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :notify_type),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:notify_type, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :security_level),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:security_level, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :shed_state),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:shed_state, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :silenced_state),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:silenced_state, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :backup_state),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:backup_state, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :write_status),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:write_status, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :lighting_in_progress),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:lighting_in_progress, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :lighting_operation),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:lighting_operation, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :lighting_transition),
          value: value
        } = _t
      ) do
    Constants.has_by_name(:lighting_transition, value)
  end

  def valid?(
        %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :integer_value),
          value: value
        } = _t
      )
      when is_integer(value),
      do: true

  def valid?(%__MODULE__{} = _t), do: false

  @spec do_parse(ApplicationTags.encoding()) :: {:ok, t()} | {:error, term()}
  defp do_parse(tag)

  # 0 = Boolean
  defp do_parse({:tagged, {0, value, _len}}) do
    case ApplicationTags.unfold_to_type(:unsigned_integer, value) do
      {:ok, {:unsigned_integer, val}} ->
        state = %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :boolean_value),
          value: val == 1
        }

        {:ok, state}

      {:error, _term} = term ->
        term
    end
  end

  # 1 = BACnetBinaryPV
  defp do_parse({:tagged, {1, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        state = %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :binary_value),
          value: val == 1
        }

        {:ok, state}

      {:error, _term} = term ->
        term
    end
  end

  # 2 = BACnetEventType
  defp do_parse({:tagged, {2, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(:event_type, val, {:unknown_event_type, val}) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :event_type),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 3 = BACnetPolarity
  defp do_parse({:tagged, {3, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(:polarity, val, {:unknown_polarity, val}) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :polarity),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 4 = BACnetProgramRequest
  defp do_parse({:tagged, {4, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(
                 :program_request,
                 val,
                 {:unknown_program_request, val}
               ) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :program_change),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 5 = BACnetProgramState
  defp do_parse({:tagged, {5, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(:program_state, val, {:unknown_program_state, val}) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :program_state),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 6 = BACnetProgramError
  defp do_parse({:tagged, {6, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(:program_error, val, {:unknown_program_error, val}) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :reason_for_halt),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 7 = BACnetReliability
  defp do_parse({:tagged, {7, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(:reliability, val, {:unknown_reliability, val}) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :reliability),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 8 = BACnetEventState
  defp do_parse({:tagged, {8, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(:event_state, val, {:unknown_event_state, val}) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :state),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 9 = BACnetDeviceStatus
  defp do_parse({:tagged, {9, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(:device_status, val, {:unknown_device_status, val}) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :system_status),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 10 = BACnetEngineeringUnits
  defp do_parse({:tagged, {10, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(
                 :engineering_unit,
                 val,
                 {:unknown_engineering_unit, val}
               ) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :units),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 11 = Unsigned
  defp do_parse({:tagged, {11, value, _len}}) do
    case ApplicationTags.unfold_to_type(:unsigned_integer, value) do
      {:ok, {:unsigned_integer, val}} ->
        state = %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :unsigned_value),
          value: val
        }

        {:ok, state}

      {:error, _term} = term ->
        term
    end
  end

  # 12 = BACnetLifeSafetyMode
  defp do_parse({:tagged, {12, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(
                 :life_safety_mode,
                 val,
                 {:unknown_life_safety_mode, val}
               ) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :life_safety_mode),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 13 = BACnetLifeSafetyState
  defp do_parse({:tagged, {13, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(
                 :life_safety_state,
                 val,
                 {:unknown_life_safety_state, val}
               ) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :life_safety_state),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 14 = BACnetRestartReason
  defp do_parse({:tagged, {14, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(
                 :restart_reason,
                 val,
                 {:unknown_restart_reason, val}
               ) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :restart_reason),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 15 = BACnetDoorAlarmState
  defp do_parse({:tagged, {15, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(
                 :door_alarm_state,
                 val,
                 {:unknown_door_alarm_state, val}
               ) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :door_alarm_state),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 16 = BACnetAction
  defp do_parse({:tagged, {16, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <- Constants.by_value_with_reason(:action, val, {:unknown_action, val}) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :action),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 17 = BACnetDoorSecuredStatus
  defp do_parse({:tagged, {17, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(
                 :door_secured_status,
                 val,
                 {:unknown_door_secured_status, val}
               ) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :door_secured_status),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 18 = BACnetDoorStatus
  defp do_parse({:tagged, {18, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(:door_status, val, {:unknown_door_status, val}) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :door_status),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 19 = BACnetDoorValue
  defp do_parse({:tagged, {19, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(:door_value, val, {:unknown_door_value, val}) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :door_value),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 20 = BACnetFileAccessMethod
  defp do_parse({:tagged, {20, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(
                 :file_access_method,
                 val,
                 {:unknown_file_access_method, val}
               ) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :file_access_method),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 21 = BACnetLockStatus
  defp do_parse({:tagged, {21, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(:lock_status, val, {:unknown_lock_status, val}) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :lock_status),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 22 = BACnetLifeSafetyOperation
  defp do_parse({:tagged, {22, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(
                 :life_safety_operation,
                 val,
                 {:unknown_life_safety_operation, val}
               ) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :life_safety_operation),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 23 = BACnetMaintenance
  defp do_parse({:tagged, {23, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(:maintenance, val, {:unknown_maintenance, val}) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :maintenance),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 24 = BACnetNodeType
  defp do_parse({:tagged, {24, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(:node_type, val, {:unknown_node_type, val}) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :node_type),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 25 = BACnetNotifyType
  defp do_parse({:tagged, {25, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(:notify_type, val, {:unknown_notify_type, val}) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :notify_type),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 26 = BACnetSecurityLevel
  defp do_parse({:tagged, {26, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(
                 :security_level,
                 val,
                 {:unknown_security_level, val}
               ) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :security_level),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 27 = BACnetShedState
  defp do_parse({:tagged, {27, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(:shed_state, val, {:unknown_shed_state, val}) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :shed_state),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 28 = BACnetSilencedState
  defp do_parse({:tagged, {28, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(
                 :silenced_state,
                 val,
                 {:unknown_silenced_state, val}
               ) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :silenced_state),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 30 = BACnetAccessEvent
  defp do_parse({:tagged, {30, _value, _len}}) do
    {:error, :not_supported}
  end

  # 31 = BACnetAccessZoneOccupancyState
  defp do_parse({:tagged, {31, _value, _len}}) do
    {:error, :not_supported}
  end

  # 32 = BACnetAccessCredentialDisableReason
  defp do_parse({:tagged, {32, _value, _len}}) do
    {:error, :not_supported}
  end

  # 33 = BACnetAccessCredentialDisable
  defp do_parse({:tagged, {33, _value, _len}}) do
    {:error, :not_supported}
  end

  # 34 = BACnetAuthenticationStatus
  defp do_parse({:tagged, {34, _value, _len}}) do
    {:error, :not_supported}
  end

  # 36 = BACnetBackupState
  defp do_parse({:tagged, {36, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(:backup_state, val, {:unknown_backup_state, val}) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :backup_state),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 37 = BACnetWriteStatus
  defp do_parse({:tagged, {37, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(:write_status, val, {:unknown_write_status, val}) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :write_status),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 38 = BACnetLightingInProgress
  defp do_parse({:tagged, {38, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(
                 :lighting_in_progress,
                 val,
                 {:unknown_lighting_in_progress, val}
               ) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :lighting_in_progress),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 39 = BACnetLightingOperation
  defp do_parse({:tagged, {39, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(
                 :lighting_operation,
                 val,
                 {:unknown_lighting_operation, val}
               ) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :lighting_operation),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 40 = BACnetLightingTransition
  defp do_parse({:tagged, {40, value, _len}}) do
    case ApplicationTags.unfold_to_type(:enumerated, value) do
      {:ok, {:enumerated, val}} ->
        with {:ok, val_c} <-
               Constants.by_value_with_reason(
                 :lighting_transition,
                 val,
                 {:unknown_lighting_transition, val}
               ) do
          state = %__MODULE__{
            type: Constants.macro_assert_name(:property_state, :lighting_transition),
            value: val_c
          }

          {:ok, state}
        end

      {:error, _term} = term ->
        term
    end
  end

  # 41 = Integer
  defp do_parse({:tagged, {41, value, _len}}) do
    case ApplicationTags.unfold_to_type(:signed_integer, value) do
      {:ok, {:signed_integer, val}} ->
        state = %__MODULE__{
          type: Constants.macro_assert_name(:property_state, :integer_value),
          value: val
        }

        {:ok, state}

      {:error, _term} = term ->
        term
    end
  end

  defp do_parse(_tag) do
    {:error, :not_supported}
  end

  @spec do_encode(t(), Keyword.t()) :: {:ok, ApplicationTags.encoding()} | {:error, term()}
  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :boolean_value)
         } = state,
         opts
       ) do
    bool = if state.value, do: 1, else: 0

    with {:ok, bits, _header} <- ApplicationTags.encode_value({:unsigned_integer, bool}, opts) do
      {:ok, {:tagged, {0, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :binary_value)
         } = state,
         opts
       ) do
    bool = if state.value, do: 1, else: 0

    with {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, bool}, opts) do
      {:ok, {:tagged, {1, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :event_type)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(
             :event_type,
             state.value,
             {:unknown_event_type, state.value}
           ),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {2, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :polarity)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(:polarity, state.value, {:unknown_polarity, state.value}),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {3, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :program_change)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(
             :program_request,
             state.value,
             {:unknown_program_request, state.value}
           ),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {4, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :program_state)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(
             :program_state,
             state.value,
             {:unknown_program_state, state.value}
           ),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {5, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :reason_for_halt)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(
             :program_error,
             state.value,
             {:unknown_program_error, state.value}
           ),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {6, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :reliability)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(
             :reliability,
             state.value,
             {:unknown_reliability, state.value}
           ),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {7, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :state)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(
             :event_state,
             state.value,
             {:unknown_event_state, state.value}
           ),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {8, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :system_status)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(
             :device_status,
             state.value,
             {:unknown_device_status, state.value}
           ),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {9, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :units)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(
             :engineering_unit,
             state.value,
             {:unknown_engineering_unit, state.value}
           ),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {10, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :unsigned_value)
         } = state,
         opts
       ) do
    with {:ok, bits, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, state.value}, opts) do
      {:ok, {:tagged, {11, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :life_safety_mode)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(
             :life_safety_mode,
             state.value,
             {:unknown_life_safety_mode, state.value}
           ),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {12, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :life_safety_state)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(
             :life_safety_state,
             state.value,
             {:unknown_life_safety_state, state.value}
           ),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {13, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :restart_reason)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(
             :restart_reason,
             state.value,
             {:unknown_restart_reason, state.value}
           ),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {14, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :door_alarm_state)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(
             :door_alarm_state,
             state.value,
             {:unknown_door_alarm_state, state.value}
           ),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {15, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :action)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(:action, state.value, {:unknown_action, state.value}),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {16, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :door_secured_status)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(
             :door_secured_status,
             state.value,
             {:unknown_door_secured_status, state.value}
           ),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {17, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :door_status)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(
             :door_status,
             state.value,
             {:unknown_door_status, state.value}
           ),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {18, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :door_value)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(
             :door_value,
             state.value,
             {:unknown_door_value, state.value}
           ),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {19, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :file_access_method)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(
             :file_access_method,
             state.value,
             {:unknown_file_access_method, state.value}
           ),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {20, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :lock_status)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(
             :lock_status,
             state.value,
             {:unknown_lock_status, state.value}
           ),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {21, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :life_safety_operation)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(
             :life_safety_operation,
             state.value,
             {:unknown_life_safety_operation, state.value}
           ),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {22, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :maintenance)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(
             :maintenance,
             state.value,
             {:unknown_maintenance, state.value}
           ),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {23, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :node_type)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(
             :node_type,
             state.value,
             {:unknown_node_type, state.value}
           ),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {24, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :notify_type)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(
             :notify_type,
             state.value,
             {:unknown_notify_type, state.value}
           ),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {25, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :security_level)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(
             :security_level,
             state.value,
             {:unknown_security_level, state.value}
           ),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {26, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :shed_state)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(
             :shed_state,
             state.value,
             {:unknown_shed_state, state.value}
           ),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {27, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :silenced_state)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(
             :silenced_state,
             state.value,
             {:unknown_silenced_state, state.value}
           ),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {28, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :backup_state)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(
             :backup_state,
             state.value,
             {:unknown_backup_state, state.value}
           ),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {36, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :write_status)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(
             :write_status,
             state.value,
             {:unknown_write_status, state.value}
           ),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {37, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :lighting_in_progress)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(
             :lighting_in_progress,
             state.value,
             {:unknown_lighting_in_progress, state.value}
           ),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {38, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :lighting_operation)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(
             :lighting_operation,
             state.value,
             {:unknown_lighting_operation, state.value}
           ),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {39, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :lighting_transition)
         } = state,
         opts
       ) do
    with {:ok, val_c} <-
           Constants.by_name_with_reason(
             :lighting_transition,
             state.value,
             {:unknown_lighting_transition, state.value}
           ),
         {:ok, bits, _header} <- ApplicationTags.encode_value({:enumerated, val_c}, opts) do
      {:ok, {:tagged, {40, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(
         %__MODULE__{
           type: Constants.macro_assert_name(:property_state, :integer_value)
         } = state,
         opts
       ) do
    with {:ok, bits, _header} <-
           ApplicationTags.encode_value({:signed_integer, state.value}, opts) do
      {:ok, {:tagged, {41, bits, byte_size(bits)}}}
    end
  end

  defp do_encode(_state, _opts) do
    {:error, :not_supported}
  end
end
