defmodule BACnet.Protocol.ObjectTypes.LargeAnalogValue do
  @moduledoc """
  The Large Analog Value object type defines a standardized object whose properties represent
  the externally visible characteristics of a named data value in a BACnet device.
  A BACnet device can use a Large Analog Value object to make any kind of
  double-precision data value accessible to other BACnet devices. The mechanisms by
  which the value is derived are not visible to the BACnet client.

  Large Analog Value objects that support intrinsic reporting shall apply
  the DOUBLE_OUT_OF_RANGE event algorithm.

  (ASHRAE 135 - Clause 12.39)
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
  Represents a Large Analog Value object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  For commandable objects (objects with a priority array), the present value property is protected,
  unless out of service is active. For the duration of out of service, updates to the present value
  using `update_property/3` are allowed. Once out of service is disabled, the present value is once
  again protected from updates, as the present value is updated through the relinquish_default and
  priority_array properties.
  """
  bac_object Constants.macro_assert_name(:object_type, :large_analog_value) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean())
    field(:present_value, float(), required: true, default: 0.0, bac_type: :double)
    field(:priority_array, PriorityArray.t(float()), readonly: true)
    field(:relinquish_default, float(), default: 0.0, bac_type: :double)

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())
    field(:resolution, float(), readonly: true, bac_type: :double)
    field(:units, Constants.engineering_unit(), required: true, default: :no_units)

    field(:max_present_value, float(), bac_type: :double)
    field(:min_present_value, float(), bac_type: :double)
    field(:profile_name, String.t())

    # COV Reporting
    field(:cov_increment, float(), cov: true, default: 0.1, bac_type: :double)

    # Intrinsic Reporting
    field(:event_state, Constants.event_state(), intrinsic: true)
    field(:deadband, float(), intrinsic: true, default: 0.0, bac_type: :double)
    field(:high_limit, float(), intrinsic: true, default: 0.0, bac_type: :double)
    field(:low_limit, float(), intrinsic: true, default: 0.0, bac_type: :double)
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

  @spec check_min_max_present_value(t(), Constants.property_identifier(), float()) ::
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
