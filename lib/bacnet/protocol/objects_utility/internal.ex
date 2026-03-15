defmodule BACnet.Protocol.ObjectsUtility.Internal do
  @moduledoc false

  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.DailySchedule

  @spec init_fun_schedule_weekly_schedule() :: BACnetArray.t(DailySchedule.t())
  def init_fun_schedule_weekly_schedule() do
    BACnetArray.new(7, %DailySchedule{schedule: []})
  end

  @spec init_fun_local_date() :: BACnetDate.t()
  def init_fun_local_date() do
    BACnetDate.from_date(
      DateTime.to_date(
        DateTime.now!(
          Application.get_env(:bacstack, :default_timezone, "Etc/UTC"),
          Calendar.get_time_zone_database()
        )
      )
    )
  end

  @spec init_fun_local_time() :: BACnetTime.t()
  def init_fun_local_time() do
    BACnetTime.from_time(
      DateTime.to_time(
        DateTime.now!(
          Application.get_env(:bacstack, :default_timezone, "Etc/UTC"),
          Calendar.get_time_zone_database()
        )
      )
    )
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
