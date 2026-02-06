defmodule BACnet.Protocol.ObjectTypes.File do
  @moduledoc """
  The File object type defines a standardized object that is used
  to describe properties of data files that may be accessed using
  File Services (see Clause 14).

  (ASHRAE 135 - Clause 12.13)
  """

  # TODO: Docs

  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectsMacro

  require Constants
  use ObjectsMacro

  @typedoc """
  Available object options.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents a File object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.
  """
  bac_object Constants.macro_assert_name(:object_type, :file) do
    services(intrinsic: false)

    field(:description, String.t())
    field(:file_type, String.t(), required: true, default: "regular")
    field(:file_size, non_neg_integer(), required: true, readonly: true, default: 0)

    field(:modification_date, BACnetDateTime.t(),
      required: true,
      default: ObjectsMacro.get_default_bacnet_datetime()
    )

    field(:archive, boolean(), required: true, default: false)
    field(:read_only, boolean(), required: true, default: false)

    field(:file_access_method, Constants.file_access_method(),
      required: true,
      readonly: true,
      default: :stream_access
    )

    field(:record_count, non_neg_integer(),
      validator_fun: fn _value, object ->
        object.file_access_method ==
          Constants.macro_assert_name(:file_access_method, :record_access)
      end
    )

    field(:profile_name, String.t())
  end

  # Override property_writable?/2, to be able to override :file_size behaviour
  # (writable if not read_only and stream_access)
  def property_writable?(%__MODULE__{} = object, property) when is_atom(property) do
    case property do
      :file_size ->
        not object.read_only and
          object.file_access_method ==
            Constants.macro_assert_name(:file_access_method, :stream_access)

      _term ->
        super(object, property)
    end
  end
end
