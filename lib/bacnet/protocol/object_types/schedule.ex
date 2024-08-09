defmodule BACnet.Protocol.ObjectTypes.Schedule do
  @moduledoc """
  The Schedule object type defines a standardized object used to describe a periodic schedule
  that may recur during a range of dates, with optional exceptions at arbitrary times on
  arbitrary dates. The Schedule object also serves as a binding between these scheduled times
  and the writing of specified "values" to specific properties of specific objects at those times.

  Schedules are divided into days, of which there are two types: normal days within a week and
  exception days. Both types of days can specify scheduling events for either the full day or
  portions of a day, and a priority mechanism defines which scheduled event is in control at any
  given time. The current state of the Schedule object is represented by the value of its
  Present_Value property, which is normally calculated using the time/value pairs from the
  Weekly_Schedule and Exception_Schedule properties, with a default value for use when no schedules
  are in effect. Details of this calculation are provided in the description of the Present_Value property.

  Versions of the Schedule object prior to Protocol_Revision 4 only support schedules that define
  an entire day, from midnight to midnight. For compatibility with these versions, this whole day
  behavior can be achieved by using a specific schedule format.
  Weekly_Schedule and Exception_Schedule values that begin at 00:00, and do not use any NULL values,
  will define schedules for the entire day. Property values in this format will produce the same
  results in all versions of the Schedule object.

  Schedule objects may optionally support intrinsic reporting to facilitate the reporting of fault conditions.
  Schedule objects that support intrinsic reporting shall apply the NONE event algorithm.

  (ASHRAE 135 - Clause 12.24)
  """

  # TODO: Docs

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DailySchedule
  alias BACnet.Protocol.DateRange
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.ObjectsUtility.Internal, as: UtilityInternal
  alias BACnet.Protocol.SpecialEvent

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Available object options.
  """
  @type object_opts ::
          {:base_type, ApplicationTags.primitive_type()}
          | common_object_opts()

  @typedoc """
  Represents a Schedule object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.
  """
  bac_object Constants.macro_assert_name(:object_type, :schedule) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:reliability, Constants.reliability(), required: true)
    field(:reliability_evaluation_inhibit, boolean())

    field(:out_of_service, boolean(), required: true)

    field(:present_value, Encoding.t(),
      required: true,
      default: %Encoding{
        encoding: :primitive,
        extras: [],
        type: :null,
        value: nil
      }
    )

    field(:effective_period, DateRange.t(),
      required: true,
      default: %DateRange{
        start_date: %BACnetDate{
          year: :unspecified,
          month: :unspecified,
          day: :unspecified,
          weekday: :unspecified
        },
        end_date: %BACnetDate{
          year: :unspecified,
          month: :unspecified,
          day: :unspecified,
          weekday: :unspecified
        }
      }
    )

    field(:weekly_schedule, BACnetArray.t(DailySchedule.t(), 7),
      init_fun: &UtilityInternal.init_fun_schedule_weekly_schedule/0
    )

    field(:exception_schedule, BACnetArray.t(SpecialEvent.t()))

    field(:schedule_default, Encoding.t(),
      required: true,
      default: %Encoding{
        encoding: :primitive,
        extras: [],
        type: :null,
        value: nil
      }
    )

    field(:list_of_object_property_references, BACnetArray.t(DeviceObjectPropertyRef.t()),
      required: true,
      default: BACnetArray.new()
    )

    field(:priority_for_writing, 1..16, required: true, default: 16)
    field(:profile_name, String.t())
  end

  # Override add_defaults/2, to assert weeky_schedule or exception_schedule is present
  defp add_defaults(properties, metadata) do
    props = super(properties, metadata)

    if Map.has_key?(props, :weekly_schedule) or Map.has_key?(props, :exception_schedule) do
      props
    else
      {:error, {:missing_required_property, {:weekly_schedule, :or, :exception_schedule}}}
    end
  end
end
