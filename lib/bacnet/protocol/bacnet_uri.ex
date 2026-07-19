defmodule BACnet.Protocol.BACnetURI do
  @moduledoc """
  ASHRAE 135 Annex Q.8 defines a BACnet URI scheme,
  in cases where a URI is needed to refer to data that is accessible using BACnet services.

  A BACnet URI is used to refer to BACnet objects,
  similar to `BACnet.Protocol.DeviceObjectPropertyRef`.

  The format looks like this:
  > bacnet://<device>/<object>[/<property>[/<index>]]

  Where angle brackets indicate variable text and square brackets indicate optionality.

  The `<device>` segment is the device instance number in decimal.
  A `<device>` identifier of `.this` means 'this device' so that it can be used in static files
  that do not need to be changed when the device identifier changes.

  The `<object>` identifier is in the form `<type>,<instance>` where <type> is either
  a decimal number or `t:BACnet.Protocol.Constants.object_type/0`,
  and <instance> is a decimal number.

  The `<property>` identifier is either a decimal number or
  `t:BACnet.Protocol.Constants.property_identifier/0`.
  If it is omitted, it defaults to `:present_value` except for BACnet File objects,
  where absence of `<property>` refers to the entire content of the file accessed with Stream Access.
  In that special case, `property` is set to `nil`.

  The `<index>` is the decimal number for the index of an array property.
  """

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectIdentifier

  require Constants

  @typedoc """
  Represents a BACnet URI.
  """
  @type t :: %__MODULE__{
          object_identifier: ObjectIdentifier.t(),
          property_identifier: Constants.property_identifier() | non_neg_integer() | nil,
          property_array_index: non_neg_integer() | nil,
          device_identifier: ObjectIdentifier.t() | nil
        }

  @fields [:device_identifier, :object_identifier, :property_identifier, :property_array_index]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Parses a BACnet URI string into a `BACnetURI` struct.

  Returns `{:ok, uri}` on success or `{:error, reason}` on failure.

  This function is more permissive than the specification,
  as in allows different casing and `_` for object types
  and property identifiers. Not only `analog-value` is allowed,
  but also `Analog_Value` or `analog_value`.

  ### Examples

  Local object:

      iex> BACnetURI.parse("bacnet://.this/1,5/85")
      {:ok, %BACnetURI{
        device_identifier: nil,
        object_identifier: %BACnet.Protocol.ObjectIdentifier{type: :analog_output, instance: 5},
        property_identifier: :present_value,
        property_array_index: nil
      }}

      iex> BACnetURI.parse("bacnet://.this/analog-output,5")
      {:ok, %BACnetURI{
        device_identifier: nil,
        object_identifier: %BACnet.Protocol.ObjectIdentifier{type: :analog_output, instance: 5},
        property_identifier: :present_value,
        property_array_index: nil
      }}

  Remote object with array index:

      iex> BACnetURI.parse("bacnet://114705/4,15555/priority-array/16")
      {:ok, %BACnetURI{
        device_identifier: %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 114705},
        object_identifier: %BACnet.Protocol.ObjectIdentifier{type: :binary_output, instance: 15555},
        property_identifier: :priority_array,
        property_array_index: 16
      }}
  """
  @spec parse(String.t()) :: {:ok, t()} | {:error, term()}
  def parse(uri) when is_binary(uri) do
    with {:ok, %URI{scheme: "bacnet"} = url} <- URI.new(uri),
         {:ok, device} <- parse_device(url.host),
         {:ok, segments} <- parse_path(url.path),
         {:ok, {obj_str, prop_str, idx_str}} <- normalize_segments(segments),
         {:ok, object} <- parse_object(obj_str),
         {:ok, property} <- parse_property(prop_str, object),
         {:ok, index} <- parse_index(idx_str) do
      {:ok,
       %__MODULE__{
         device_identifier: device,
         object_identifier: object,
         property_identifier: property,
         property_array_index: index
       }}
    else
      {:error, _reason} = err -> err
      _other -> {:error, :invalid_bacnet_uri}
    end
  end

  @doc """
  Encodes a `BACnetURI` struct into a BACnet URI string.

  When the property is `nil` (for File objects), the property segment is omitted.
  Otherwise the property is always included.

  This function will never use Clause 21 text for the URI encoding and
  always use the decimal number for better compatibility.

  ### Examples

  Local object:

      iex> object = %BACnet.Protocol.ObjectIdentifier{type: :analog_output, instance: 5}
      iex> BACnetURI.encode(%BACnetURI{
      ...>   device_identifier: nil, object_identifier: object,
      ...>   property_identifier: :present_value, property_array_index: nil
      ...> })
      {:ok, "bacnet://.this/1,5/85"}

  Remote object with array index:

      iex> device = %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 114705}
      iex> object = %BACnet.Protocol.ObjectIdentifier{type: :binary_output, instance: 15555}
      iex> BACnetURI.encode(%BACnetURI{
      ...>   device_identifier: device, object_identifier: object,
      ...>   property_identifier: :priority_array, property_array_index: 16
      ...> })
      {:ok, "bacnet://114705/4,15555/87/16"}
  """
  @spec encode(t()) :: {:ok, String.t()} | {:error, term()}
  def encode(uri)

  def encode(%__MODULE__{
        device_identifier: device,
        object_identifier: %ObjectIdentifier{type: obj_type, instance: obj_inst} = object,
        property_identifier: prop,
        property_array_index: idx
      })
      when (is_nil(device) or (is_struct(device, ObjectIdentifier) and device.type == :device)) and
             (is_nil(idx) or (is_integer(idx) and idx >= 0)) do
    device_str = if device, do: Integer.to_string(device.instance), else: ".this"

    obj_type_str = identifier_to_string(:object_type, obj_type)
    obj_str = "#{obj_type_str},#{obj_inst}"

    path =
      if omit_property?(prop, object) do
        "/" <> obj_str
      else
        prop_str = identifier_to_string(:property_identifier, prop)
        pstr = "/" <> obj_str <> "/" <> prop_str

        if idx do
          pstr <> "/" <> Integer.to_string(idx)
        else
          pstr
        end
      end

    uri = URI.to_string(%URI{scheme: "bacnet", host: device_str, path: path})
    {:ok, uri}
  end

  def encode(%__MODULE__{} = _uri), do: {:error, :invalid_data}

  @doc """
  Returns `true` if the `BACnetURI` struct contains valid data according to
  the BACnet URI scheme rules (Annex Q.8).
  """
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{
        device_identifier: device,
        object_identifier: object,
        property_identifier: property,
        property_array_index: index
      }) do
    (is_nil(device) or
       (is_struct(device, ObjectIdentifier) and ObjectIdentifier.valid?(device) and
          device.type == :device)) and
      (is_struct(object, ObjectIdentifier) and ObjectIdentifier.valid?(object)) and
      ((is_nil(property) and object.type == :file) or
         (Constants.has_by_name(:property_identifier, property) or
            (is_integer(property) and property >= 0 and
               property <= Constants.macro_by_name(:asn1, :max_instance_and_property_id)))) and
      (is_nil(index) or (is_integer(index) and index >= 0))
  end

  @doc """
  Returns `true` if the given BACnet URI string is valid.

  This function will attempt to parse the string and then validate it.
  """
  @spec valid_str?(binary()) :: boolean()
  def valid_str?(uri) when is_binary(uri) do
    case parse(uri) do
      {:ok, %__MODULE__{} = url} -> valid?(url)
      {:error, _err} -> false
    end
  end

  @spec parse_device(binary()) :: {:ok, ObjectIdentifier.t() | nil} | {:error, term()}
  defp parse_device(".this"), do: {:ok, nil}

  defp parse_device(host) when is_binary(host) do
    case Integer.parse(host) do
      {int, ""} -> {:ok, %ObjectIdentifier{type: :device, instance: int}}
      _other -> {:error, :invalid_device}
    end
  end

  @spec parse_path(binary() | nil) :: {:ok, list()} | {:error, term()}
  defp parse_path(path)

  defp parse_path(nil), do: {:ok, []}

  defp parse_path("/" <> rest) when is_binary(rest) do
    segments =
      case rest do
        "" -> []
        _other -> String.split(rest, "/")
      end

    {:ok, segments}
  end

  defp parse_path(_path), do: {:error, :invalid_path}

  @spec normalize_segments([binary()]) ::
          {:ok, {binary(), binary() | nil, binary() | nil}} | {:error, term()}
  defp normalize_segments(segments)

  defp normalize_segments([]), do: {:error, :missing_object}
  defp normalize_segments([obj]), do: {:ok, {obj, nil, nil}}
  defp normalize_segments([obj, prop]), do: {:ok, {obj, prop, nil}}
  defp normalize_segments([obj, prop, idx]), do: {:ok, {obj, prop, idx}}
  defp normalize_segments(_segments), do: {:error, :invalid_path_segments}

  @spec parse_object(binary()) :: {:ok, ObjectIdentifier.t()} | {:error, term()}
  defp parse_object(str)

  defp parse_object(obj_str) when is_binary(obj_str) do
    case String.split(obj_str, ",", parts: 2) do
      [type_str, inst_str] ->
        with {:ok, type} <- parse_object_type(type_str),
             {:ok, instance} <- parse_instance(inst_str) do
          {:ok, %ObjectIdentifier{type: type, instance: instance}}
        end

      _other ->
        {:error, :invalid_object}
    end
  end

  defp parse_object_type(type_str) when is_binary(type_str) do
    # We are more permissive than the BACnet specification
    # "exactly equal to the Clause 21 identifier text of BACnetObjectType"
    # -> analog-value (valid), Analog_Value (invalid), analog_value (invalid)

    cleaned =
      type_str
      |> String.replace("-", "_")
      |> String.downcase()

    try do
      atom = String.to_existing_atom(cleaned)
      Constants.assert_name!(:object_type, atom)
      {:ok, atom}
    rescue
      _other ->
        case Integer.parse(type_str) do
          {num, ""} when num >= 0 and num <= Constants.macro_by_name(:asn1, :max_object_type) ->
            {:ok, Constants.by_value(:object_type, num, num)}

          _other ->
            {:error, :invalid_object_type}
        end
    end
  end

  @spec parse_instance(binary()) :: {:ok, non_neg_integer()} | {:error, term()}
  defp parse_instance(str)

  defp parse_instance(str) when is_binary(str) do
    case Integer.parse(str) do
      {num, ""}
      when num >= 0 and num <= Constants.macro_by_name(:asn1, :max_instance_and_property_id) ->
        {:ok, num}

      _other ->
        {:error, :invalid_instance}
    end
  end

  @spec parse_property(binary() | nil, ObjectIdentifier.t()) ::
          {:ok, Constants.property_identifier() | non_neg_integer() | nil} | {:error, term()}
  defp parse_property(str, object)

  defp parse_property(nil, %ObjectIdentifier{type: :file}), do: {:ok, nil}
  defp parse_property(nil, _object), do: {:ok, :present_value}

  defp parse_property(prop_str, _object) when is_binary(prop_str) do
    cleaned =
      prop_str
      |> String.replace("-", "_")
      |> String.downcase()

    try do
      atom = String.to_existing_atom(cleaned)
      Constants.assert_name!(:property_identifier, atom)
      {:ok, atom}
    rescue
      _other ->
        case Integer.parse(prop_str) do
          {num, ""} -> {:ok, Constants.by_value(:property_identifier, num, num)}
          _other -> {:error, :invalid_property}
        end
    end
  end

  @spec parse_index(binary() | nil) :: {:ok, non_neg_integer() | nil} | {:error, term()}
  defp parse_index(str)

  defp parse_index(nil), do: {:ok, nil}

  defp parse_index(str) when is_binary(str) do
    case Integer.parse(str) do
      {num, ""} when num >= 0 -> {:ok, num}
      _other -> {:error, :invalid_index}
    end
  end

  @spec omit_property?(atom() | non_neg_integer() | nil, ObjectIdentifier.t()) :: boolean()
  defp omit_property?(property, object)

  defp omit_property?(nil, %ObjectIdentifier{type: :file}), do: true
  defp omit_property?(_prop, _object), do: false

  @spec identifier_to_string(atom(), atom() | non_neg_integer() | nil) :: binary()
  defp identifier_to_string(category, value)

  defp identifier_to_string(_category, nil), do: ""

  defp identifier_to_string(category, val) when is_atom(val) do
    Integer.to_string(Constants.by_name!(category, val))
  end

  defp identifier_to_string(_category, val) when is_integer(val) do
    Integer.to_string(val)
  end

  defp identifier_to_string(_category, _val), do: ""
end
