defmodule BACnet.Protocol.ObjectTypes.IntegerValue do
  @moduledoc """
  The Integer Value object type defines a standardized object whose properties represent
  the externally visible characteristics of a named data value in a BACnet device.
  A BACnet device can use an Integer Value object to make any kind of signed integer data
  value accessible to other BACnet devices.
  The mechanisms by which the value is derived are not visible to the BACnet client.

  Integer Value objects that support intrinsic reporting shall apply the SIGNED_OUT_OF_RANGE event algorithm.

  (ASHRAE 135 - Clause 12.43)
  """

  # TODO: Docs

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.PriorityArray

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Available object options.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()} | common_object_opts()

  @typedoc """
  Represents an Integer Value object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  For commandable objects (objects with a priority array), the present value property is protected,
  unless out of service is active. For the duration of out of service, updates to the present value
  using `update_property/3` are allowed. Once out of service is disabled, the present value is once
  again protected from updates, as the present value is updated through the relinquish_default and
  priority_array properties.
  """
  bac_object Constants.macro_assert_name(:object_type, :integer_value) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:device_type, String.t())
    field(:event_state, Constants.event_state(), required: true)
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean(), required: true)
    field(:present_value, integer(), required: true, default: 0)
    field(:priority_array, PriorityArray.t(integer()), readonly: true)
    field(:relinquish_default, integer(), default: 0)

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())
    field(:resolution, integer(), readonly: true)
    field(:units, Constants.engineering_unit(), required: true, default: :no_units)

    field(:max_present_value, integer())
    field(:min_present_value, integer())
    field(:profile_name, String.t())

    # COV Reporting
    field(:cov_increment, non_neg_integer(), cov: true, default: 0)

    # Intrinsic Reporting
    field(:deadband, non_neg_integer(), intrinsic: true, default: 0)
    field(:high_limit, integer(), intrinsic: true, default: 0)
    field(:low_limit, integer(), intrinsic: true, default: 0)
  end

  # Override set_priority/3, to check present_value for max_/min_present_value
  def set_priority(%__MODULE__{priority_array: nil} = _object, _priority, _value) do
    {:error, {:unknown_property, :priority_array}}
  end

  def set_priority(
        %__MODULE__{priority_array: %PriorityArray{} = _pa} = object,
        priority,
        value
      )
      when priority in 1..16 do
    with :ok <-
           if(value == nil,
             do: :ok,
             else: check_min_max_present_value(object, :priority_array, value)
           ),
         do: super(object, priority, value)
  end

  # Override update_property/3, to check present_value and relinquish_default for max_/min_present_value
  def update_property(%__MODULE__{} = object, :present_value, value) do
    with :ok <- check_min_max_present_value(object, :present_value, value),
         do: super(object, :present_value, value)
  end

  def update_property(%__MODULE__{} = object, :relinquish_default, value) do
    with :ok <- check_min_max_present_value(object, :relinquish_default, value),
         do: super(object, :relinquish_default, value)
  end

  def update_property(%__MODULE__{} = object, property, value) when is_atom(property) do
    super(object, property, value)
  end

  @spec check_min_max_present_value(t(), Constants.property_identifier(), integer()) ::
          :ok | property_update_error()
  defp check_min_max_present_value(object, property, value) do
    if check_property_exists(object, :max_present_value) == :ok and
         check_property_exists(object, :min_present_value) == :ok do
      with true <- value <= object.max_present_value,
           true <- value >= object.min_present_value do
        :ok
      else
        false -> {:error, {:property_out_of_range, property}}
      end
    else
      :ok
    end
  end
end
