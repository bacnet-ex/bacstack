defmodule BACnet.Protocol.ObjectsUtility.Internal do
  @moduledoc false

  alias BACnet.Protocol
  alias BACnet.Protocol.BACnetArray

  def init_fun_schedule_weekly_schedule() do
    BACnetArray.new(7, %Protocol.DailySchedule{schedule: []})
  end

  defmodule ReadPropertyAckTransformOptions do
    @moduledoc false

    @type t :: %__MODULE__{
            allow_unknown_properties: boolean(),
            ignore_array_indexes: boolean(),
            ignore_invalid_properties: boolean(),
            ignore_object_identifier_mismatch: boolean(),
            ignore_unknown_properties: boolean()
          }

    @fields [
      :allow_unknown_properties,
      :ignore_array_indexes,
      :ignore_invalid_properties,
      :ignore_object_identifier_mismatch,
      :ignore_unknown_properties
    ]
    @enforce_keys @fields
    defstruct @fields
  end
end
