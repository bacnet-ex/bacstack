defmodule BACnet.Protocol.Constants.Object do
  @moduledoc false
  # Can be extended through env :bacstack, :additional_object_type

  use ConstEnum, exception: BACnet.Protocol.Constants.ConstantError

  # The name usually matches the clause 21 definition and `-` translated to `_`.
  # Some exceptions were done for better readability (inserting `_`).
  #
  # When new object types are added that don't match with the clause 21,
  # with - translated to _, these need to be added to the `clause21_translation` map below.
  defconst(:object_type, :analog_input, 0x00)
  defconst(:object_type, :analog_output, 0x01)
  defconst(:object_type, :analog_value, 0x02)
  defconst(:object_type, :binary_input, 0x03)
  defconst(:object_type, :binary_output, 0x04)
  defconst(:object_type, :binary_value, 0x05)
  defconst(:object_type, :calendar, 0x06)
  defconst(:object_type, :command, 0x07)
  defconst(:object_type, :device, 0x08)
  defconst(:object_type, :event_enrollment, 0x09)
  defconst(:object_type, :file, 0x0A)
  defconst(:object_type, :group, 0x0B)
  defconst(:object_type, :loop, 0x0C)
  defconst(:object_type, :multi_state_input, 0x0D)
  defconst(:object_type, :multi_state_output, 0x0E)
  defconst(:object_type, :notification_class, 0x0F)
  defconst(:object_type, :program, 0x10)
  defconst(:object_type, :schedule, 0x11)
  defconst(:object_type, :averaging, 0x12)
  defconst(:object_type, :multi_state_value, 0x13)
  defconst(:object_type, :trend_log, 0x14)
  defconst(:object_type, :life_safety_point, 0x15)
  defconst(:object_type, :life_safety_zone, 0x16)
  defconst(:object_type, :accumulator, 0x17)
  defconst(:object_type, :pulse_converter, 0x18)
  defconst(:object_type, :event_log, 0x19)
  defconst(:object_type, :global_group, 0x1A)
  defconst(:object_type, :trend_log_multiple, 0x1B)
  defconst(:object_type, :load_control, 0x1C)
  defconst(:object_type, :structured_view, 0x1D)
  defconst(:object_type, :access_door, 0x1E)
  defconst(:object_type, :timer, 0x1F)
  defconst(:object_type, :access_credential, 0x20)
  defconst(:object_type, :access_point, 0x21)
  defconst(:object_type, :access_rights, 0x22)
  defconst(:object_type, :access_user, 0x23)
  defconst(:object_type, :access_zone, 0x24)
  defconst(:object_type, :credential_data_input, 0x25)
  defconst(:object_type, :network_security, 0x26)
  defconst(:object_type, :bitstring_value, 0x27)
  defconst(:object_type, :character_string_value, 0x28)
  defconst(:object_type, :date_pattern_value, 0x29)
  defconst(:object_type, :date_value, 0x2A)
  defconst(:object_type, :datetime_pattern_value, 0x2B)
  defconst(:object_type, :datetime_value, 0x2C)
  defconst(:object_type, :integer_value, 0x2D)
  defconst(:object_type, :large_analog_value, 0x2E)
  defconst(:object_type, :octet_string_value, 0x2F)
  defconst(:object_type, :positive_integer_value, 0x30)
  defconst(:object_type, :time_pattern_value, 0x31)
  defconst(:object_type, :time_value, 0x32)
  defconst(:object_type, :notification_forwarder, 0x33)
  defconst(:object_type, :alert_enrollment, 0x34)
  defconst(:object_type, :channel, 0x35)
  defconst(:object_type, :lighting_output, 0x36)
  defconst(:object_type, :binary_lighting_output, 0x37)
  defconst(:object_type, :network_port, 0x38)
  defconst(:object_type, :elevator_group, 0x39)
  defconst(:object_type, :escalator, 0x3A)
  defconst(:object_type, :lift, 0x3B)

  defconst_extend_env(
    :object_type,
    :bacstack,
    :additional_object_type,
    &(&1 != nil and is_integer(&2) and &2 >= 0)
  )

  @doc """
  Any object type names that dont match the Clause 21 definition,
  are to be listed here.

  Note that if the difference is only `-` translated to `_`, they are not listed here.
  """
  @spec clause21_translation() :: %{optional(atom()) => String.t()}
  def clause21_translation() do
    # Listed in order of the object type number
    %{
      character_string_value: "characterstring-value",
      date_pattern_value: "datepattern-value",
      datetime_pattern_value: "datetimepattern-value",
      octet_string_value: "octetstring-value",
      time_pattern_value: "timepattern-value"
    }
  end

  @doc """
  Translates a object type to the Clause 21 string.

  If the input is a number, it will be resolved to the atom and then translated.
  If the number can't be resolved, `nil` will be returned.
  """
  @spec translate_to_clause21(atom() | non_neg_integer()) ::
          String.t() | nil
  def translate_to_clause21(object_type)

  def translate_to_clause21(object_type)
      when is_atom(object_type) and object_type not in [true, false, nil] do
    case Map.fetch(clause21_translation(), object_type) do
      {:ok, str} ->
        str

      :error ->
        object_type
        |> Atom.to_string()
        |> String.replace("_", "-")
    end
  end

  def translate_to_clause21(object_type)
      when is_integer(object_type) and object_type >= 0 do
    case by_value(:object_type, object_type) do
      {:ok, id} -> translate_to_clause21(id)
      :error -> nil
    end
  end
end
