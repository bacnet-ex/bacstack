defmodule BACnet.Protocol.GroupChannelValue do
  @moduledoc """
  A Group Channel Value is the payload element used by the Write Group service.
  It allows a single confirmed or unconfirmed request to command many objects
  at once by addressing them through a numeric "channel" rather than by object
  identifier.

  Each entry specifies a channel number (0-65535), an optional overriding
  priority (used when writing to commandable properties), and the actual value
  to be written. The value may be a normal primitive or a specially encoded
  lightning command when the target objects are lighting output objects. The
  receiving device is responsible for mapping the channel number to one or more
  actual objects and performing the write on their behalf.

  The Write Group service and this data type were introduced to support large
  scale lighting control and similar "mass command" use cases where sending
  thousands of individual Write Property requests would be impractical. A single
  Write Group message can affect hundreds of objects with very low network
  overhead.
  """

  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  import BACnet.Protocol.Utility, only: [pattern_extract_tags: 4]

  @typedoc """
  Represents a single channel/value pair used by the Write Group service.
  """
  @type t :: %__MODULE__{
          channel: ApplicationTags.unsigned16(),
          overriding_priority: 1..16 | nil,
          value:
            ApplicationTags.Encoding.t() | (lightning_command :: [ApplicationTags.Encoding.t()])
        }

  @fields [
    :channel,
    :overriding_priority,
    :value
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a group channel value struct into application tags encoding.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = value, _opts \\ []) do
    with :ok <-
           if(ApplicationTags.valid_int?(value.channel, 16),
             do: :ok,
             else: {:error, :invalid_channel_value}
           ),
         {:ok, channel, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, value.channel}),
         {:ok, priority} <-
           (if value.overriding_priority do
              ApplicationTags.create_tag_encoding(
                1,
                {:unsigned_integer, value.overriding_priority}
              )
            else
              {:ok, nil}
            end),
         {:ok, val} <-
           (if is_list(value.value) do
              with {:ok, list} <- encode_list_value(value) do
                {:ok, {:constructed, {0, list, 0}}}
              end
            else
              ApplicationTags.Encoding.to_encoding(value.value)
            end) do
      params = [
        {:tagged, {0, channel, byte_size(channel)}},
        priority,
        val
      ]

      {:ok, Enum.reject(params, &is_nil/1)}
    else
      {:error, _err} = err -> err
    end
  end

  @doc """
  Parses a BACnet group channel value into a struct.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}} | {:error, term()}
  def parse(tags) when is_list(tags) do
    with {:ok, channel, rest} <-
           pattern_extract_tags(tags, {:tagged, {0, _t, _l}}, :unsigned_integer, false),
         :ok <-
           if(ApplicationTags.valid_int?(channel, 16),
             do: :ok,
             else: {:error, :invalid_channel_value}
           ),
         {:ok, priority, rest} <-
           pattern_extract_tags(rest, {:tagged, {1, _t, _l}}, :unsigned_integer, true),
         {:ok, {value, rest}} <- parse_value(rest) do
      # TODO: Implement BACnetLightningCommand
      chanvalue = %__MODULE__{
        channel: channel,
        overriding_priority: priority,
        value: value
      }

      {:ok, {chanvalue, rest}}
    else
      {:error, :missing_pattern} -> {:error, :invalid_tags}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Validates whether the given BACnet group channel value is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(t)

  def valid?(
        %__MODULE__{
          channel: channel,
          overriding_priority: priority,
          value: %ApplicationTags.Encoding{}
        } = _t
      )
      when (is_nil(priority) or priority in 1..16) and is_integer(channel) and channel >= 0 and
             channel <= 65_535,
      do: true

  def valid?(
        %__MODULE__{
          channel: channel,
          overriding_priority: priority,
          value: value
        } = _t
      )
      when (is_nil(priority) or priority in 1..16) and is_integer(channel) and channel >= 0 and
             channel <= 65_535 and
             is_list(value) do
    Enum.all?(value, &is_struct(&1, ApplicationTags.Encoding))
  end

  def valid?(%__MODULE__{} = _t), do: false

  @spec parse_value(ApplicationTags.encoding_list()) ::
          {:ok, {[ApplicationTags.Encoding.t()], rest :: ApplicationTags.encoding_list()}}
          | {:error, term()}
  defp parse_value([{type, _value} = tag | rest])
       when type in [
              :null,
              :boolean,
              :enumerated,
              :unsigned_integer,
              :integer,
              :real,
              :double,
              :date,
              :time,
              :octet_string,
              :character_string,
              :bitstring,
              :object_identifier
            ] do
    {:ok, {ApplicationTags.Encoding.create!(tag), rest}}
  end

  defp parse_value([{:constructed, {0, value, _len}} | rest]) do
    {:ok, {Enum.map(value, &ApplicationTags.Encoding.create!/1), rest}}
  end

  defp parse_value(_tag), do: {:error, :invalid_tags}

  defp encode_list_value(%__MODULE__{} = value) do
    result =
      Enum.reduce_while(value.value, {:ok, []}, fn val, {:ok, acc} ->
        case ApplicationTags.Encoding.to_encoding(val) do
          {:ok, enc} -> {:cont, {:ok, [enc | acc]}}
          term -> {:halt, term}
        end
      end)

    case result do
      {:ok, list} ->
        new_list =
          list
          |> Enum.reverse()
          |> List.flatten()

        {:ok, new_list}

      term ->
        term
    end
  end
end
