defmodule BACnet.Protocol.ActionCommand do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectIdentifier

  import BACnet.Protocol.Utility, only: [pattern_extract_tags: 4]
  require Constants

  @type t :: %__MODULE__{
          device_identifier: ObjectIdentifier.t() | nil,
          object_identifier: ObjectIdentifier.t(),
          property_identifier: Constants.property_identifier() | non_neg_integer(),
          property_array_index: non_neg_integer() | nil,
          property_value: ApplicationTags.Encoding.t(),
          priority: 1..16 | nil,
          post_delay: non_neg_integer() | nil,
          quit_on_failure: boolean(),
          write_successful: boolean()
        }

  @fields [
    :device_identifier,
    :object_identifier,
    :property_identifier,
    :property_array_index,
    :property_value,
    :priority,
    :post_delay,
    :quit_on_failure,
    :write_successful
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encode a BACnet action command into application tag-encoded.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(
        %__MODULE__{
          object_identifier: %ObjectIdentifier{},
          property_value: %ApplicationTags.Encoding{}
        } = cmd,
        opts \\ []
      ) do
    with {:ok, devident, _header} <-
           (if cmd.device_identifier do
              ApplicationTags.encode_value({:object_identifier, cmd.device_identifier}, opts)
            else
              {:ok, nil, nil}
            end),
         {:ok, objident, _header} <-
           ApplicationTags.encode_value({:object_identifier, cmd.object_identifier}, opts),
         {:ok, propident, _header} <-
           ApplicationTags.encode_value(
             {:enumerated, Constants.by_name_atom(:property_identifier, cmd.property_identifier)},
             opts
           ),
         {:ok, propindex, _header} <-
           (if cmd.property_array_index do
              ApplicationTags.encode_value({:unsigned_integer, cmd.property_array_index}, opts)
            else
              {:ok, nil, nil}
            end),
         {:ok, property_value} <- ApplicationTags.Encoding.to_encoding(cmd.property_value),
         {:ok, priority, _header} <-
           (if cmd.priority do
              ApplicationTags.encode_value({:unsigned_integer, cmd.priority}, opts)
            else
              {:ok, nil, nil}
            end),
         {:ok, post_delay, _header} <-
           (if cmd.post_delay do
              ApplicationTags.encode_value({:unsigned_integer, cmd.post_delay}, opts)
            else
              {:ok, nil, nil}
            end),
         {:ok, quit, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, cmd.quit_on_failure}, opts),
         {:ok, write_successful, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, cmd.write_successful}, opts) do
      base = [
        {:tagged, {0, devident, byte_size(devident || <<>>)}},
        {:tagged, {1, objident, byte_size(objident)}},
        {:tagged, {2, propident, byte_size(propident)}},
        {:tagged, {3, propindex, byte_size(propindex || <<>>)}},
        {:constructed, {4, property_value, 0}},
        {:tagged, {5, priority, byte_size(priority || <<>>)}},
        {:tagged, {6, post_delay, byte_size(post_delay || <<>>)}},
        {:tagged, {7, quit, byte_size(quit)}},
        {:tagged, {8, write_successful, byte_size(write_successful)}}
      ]

      {:ok, Enum.filter(base, fn {_type, {_t, con, _l}} -> con end)}
    else
      {:error, _err} = err -> err
    end
  end

  @doc """
  Parse a BACnet action command from application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}}
          | {:error, term()}
  def parse(tags) when is_list(tags) do
    with {:ok, device_identifier, rest} <-
           pattern_extract_tags(tags, {:tagged, {0, _t, _l}}, :object_identifier, true),
         {:ok, object_identifier, rest} <-
           pattern_extract_tags(rest, {:tagged, {1, _t, _l}}, :object_identifier, false),
         {:ok, property_identifier, rest} <-
           pattern_extract_tags(rest, {:tagged, {2, _t, _l}}, :enumerated, false),
         {:ok, property_array_index, rest} <-
           pattern_extract_tags(rest, {:tagged, {3, _t, _l}}, :unsigned_integer, true),
         {:ok, {:constructed, {4, property_value, _l}}, rest} <-
           pattern_extract_tags(rest, {:constructed, {4, _t, _l}}, nil, false),
         {:ok, priority, rest} <-
           pattern_extract_tags(rest, {:tagged, {5, _t, _l}}, :unsigned_integer, true),
         {:ok, post_delay, rest} <-
           pattern_extract_tags(rest, {:tagged, {6, _t, _l}}, :unsigned_integer, true),
         {:ok, quit, rest} <-
           pattern_extract_tags(rest, {:tagged, {7, _t, _l}}, :unsigned_integer, false),
         {:ok, write_successful, rest} <-
           pattern_extract_tags(rest, {:tagged, {8, _t, _l}}, :unsigned_integer, false) do
      cmd = %__MODULE__{
        device_identifier: device_identifier,
        object_identifier: object_identifier,
        property_identifier:
          Constants.by_value(:property_identifier, property_identifier, property_identifier),
        property_array_index: property_array_index,
        property_value: ApplicationTags.Encoding.create!(property_value),
        priority: priority,
        post_delay: post_delay,
        quit_on_failure: quit == 1,
        write_successful: write_successful == 1
      }

      {:ok, {cmd, rest}}
    else
      {:error, :missing_pattern} -> {:error, :invalid_tags}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Validates whether the given action command is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          device_identifier: dev_ref,
          object_identifier: %ObjectIdentifier{} = obj_ref,
          property_identifier: prop_identifier,
          property_array_index: array_index,
          property_value: %ApplicationTags.Encoding{},
          priority: priority,
          post_delay: post_delay,
          quit_on_failure: quit_on_failure,
          write_successful: write_successful
        } = _t
      ) do
    (is_nil(dev_ref) or
       (is_struct(dev_ref, ObjectIdentifier) and ObjectIdentifier.valid?(dev_ref) and
          dev_ref.type == :device)) and
      ObjectIdentifier.valid?(obj_ref) and
      (Constants.has_by_name(:property_identifier, prop_identifier) or
         (is_integer(prop_identifier) and prop_identifier >= 0 and
            prop_identifier <= Constants.macro_by_name(:asn1, :max_instance_and_property_id))) and
      (is_nil(array_index) or (is_integer(array_index) and array_index >= 0)) and
      (is_nil(priority) or priority in 1..16) and
      (is_nil(post_delay) or (is_integer(post_delay) and post_delay >= 0)) and
      is_boolean(quit_on_failure) and
      is_boolean(write_successful)
  end

  def valid?(%__MODULE__{} = _t), do: false
end
