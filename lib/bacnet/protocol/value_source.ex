defmodule BACnet.Protocol.ValueSource do
  @moduledoc """
  The Value Source Identifies the source of a value.

  In building control systems, an object may be manipulated by a number of entities,
  and it may be important to know which entity is the current source of the current value.
  The priority at which an object is commanded indicates the general process that is
  controlling it (scheduling, manual override, etc.), the value source mechanism
  allows for an object to indicate the device,
  and/or object that was the source of the command or write operation.

  The `type` field selects one of three alternatives:

  - `:none`: no source is specified.
  - `:object`: the `object` field contains a `BACnet.Protocol.DeviceObjectRef`.
    Its optional device identifier qualifies a remote object; without it the
    object is local.
  - `:address`: the `address` field contains a `BACnet.Protocol.RecipientAddress`.
    Network number 0 denotes the local network.

  The nested structures reuse the existing reference and address types. All
  fields must be supplied when constructing a source; unused fields should be
  `nil`. Encoding and validation use the field selected by `type`. Parsing sets
  unused fields to `nil`.

  ### Value source mechanism (Clause 19.5)

  `value_source` identifies the origin of the current `present_value` (or `mode`
  for Life Safety objects). For commandable properties, it follows the entry in
  `value_source_array` at the priority supplying the current value. If all
  priorities are relinquished and `relinquish_default` supplies the value, the
  source is `none`. For non-commandable properties, it records the last writer;
  there is no `value_source_array`.

  A write or command normally records the originating device's Device object
  when its instance is known, or its network address otherwise. A local object
  initiating the operation is identified directly. Thus an `object` source can
  reference either a Device object or the specific object initiating a command.

  The originating device may subsequently refine the source information by
  writing `value_source`, using the same priority for a commandable property.
  Such a refinement does not update `last_command_time`. Subscriptions to
  `value_source` also report source changes according to Clause 19.5.2. This
  module represents the datatype; priority selection, write authorization, and
  COV reporting are responsibilities of the objects using it.

  ### ASN.1 (ASHRAE 135-2016)

      BACnetValueSource ::= CHOICE {
        none     [0] NULL,
        object   [1] BACnetDeviceObjectReference,
        address  [2] BACnetAddress
      }

  Alternative 0 uses a primitive context tag with an empty payload. Alternatives
  1 and 2 use constructed context tags containing the respective SEQUENCE.
  The address SEQUENCE contains an application-tagged Unsigned16 network number
  followed by an application-tagged OCTET STRING MAC address.

  ### Examples

      iex> alias BACnet.Protocol.ValueSource
      iex> source = %ValueSource{type: :none, object: nil, address: nil}
      iex> ValueSource.encode(source)
      {:ok, [tagged: {0, <<>>, 0}]}
      iex> ValueSource.parse([{:tagged, {0, <<>>, 0}}, {:unsigned_integer, 7}])
      {:ok, {%ValueSource{type: :none, object: nil, address: nil}, [unsigned_integer: 7]}}

      iex> alias BACnet.Protocol.{DeviceObjectRef, ObjectIdentifier, ValueSource}
      iex> source = %ValueSource{type: :object, address: nil, object: %DeviceObjectRef{
      ...>   device_identifier: nil,
      ...>   object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24}
      ...> }}
      iex> ValueSource.encode(source)
      {:ok, [constructed: {1, [tagged: {1, <<0, 0, 0, 24>>, 4}], 0}]}

      iex> alias BACnet.Protocol.{RecipientAddress, ValueSource}
      iex> source = %ValueSource{type: :address, object: nil,
      ...>   address: %RecipientAddress{network: 0, address: :broadcast}}
      iex> ValueSource.encode(source)
      {:ok, [constructed: {2, [unsigned_integer: 0, octet_string: <<>>], 0}]}
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.DeviceObjectRef
  alias BACnet.Protocol.RecipientAddress

  @typedoc """
  The representative type for a value source.

  The `type` discriminator selects context tag 0 (`:none`), 1 (`:object`), or
  2 (`:address`). The selected source is stored in the matching field; unused
  fields are normally `nil`. All fields are enforced when constructing a struct.
  """
  @type t :: %__MODULE__{
          type: :none | :object | :address,
          object: DeviceObjectRef.t() | nil,
          address: RecipientAddress.t() | nil
        }

  @fields [:type, :object, :address]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encode a BACnet value source into application tag-encoded.
  """
  @spec encode(t(), Keyword.t()) :: {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = source, opts \\ []) do
    if valid?(source) do
      encode_value(source, opts)
    else
      {:error, :invalid_value}
    end
  end

  @doc """
  Parse a BACnet value source from application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}} | {:error, term()}
  def parse(tags)

  def parse([{:tagged, {0, <<>>, 0}} | rest]) do
    {:ok, {%__MODULE__{type: :none, object: nil, address: nil}, rest}}
  end

  def parse([{:constructed, {1, tags, 0}} | rest]) do
    case DeviceObjectRef.parse(List.wrap(tags)) do
      {:ok, {ref, []}} ->
        {:ok, {%__MODULE__{type: :object, object: ref, address: nil}, rest}}

      {:ok, {_ref, _extra}} ->
        {:error, :invalid_tags}

      {:error, _reason} = error ->
        error
    end
  end

  def parse([
        {:constructed, {2, [{:unsigned_integer, network}, {:octet_string, address}], 0}}
        | rest
      ])
      when is_integer(network) and network >= 0 and network <= 65_535 and is_binary(address) do
    address = %RecipientAddress{
      network: network,
      address: if(address == <<>>, do: :broadcast, else: address)
    }

    {:ok, {%__MODULE__{type: :address, object: nil, address: address}, rest}}
  end

  def parse(tags) when is_list(tags), do: {:error, :invalid_tags}

  @doc """
  Returns whether the selected source is well-formed.

  Object references are validated by `BACnet.Protocol.DeviceObjectRef.valid?/1`.
  Addresses require an integer network number in `0..65_535` and a binary MAC
  address or `:broadcast`. MAC length and format depend on the data link and are
  not restricted here. The `:none` alternative is always valid. Unused fields
  do not affect validation.
  """
  @spec valid?(t()) :: boolean()
  def valid?(t)

  def valid?(%__MODULE__{type: :none}), do: true

  def valid?(%__MODULE__{type: :object, object: %DeviceObjectRef{} = ref}),
    do: DeviceObjectRef.valid?(ref)

  def valid?(%__MODULE__{
        type: :address,
        address: %RecipientAddress{network: network, address: address}
      })
      when is_integer(network) and network >= 0 and network <= 65_535 and
             (is_binary(address) or address == :broadcast),
      do: true

  def valid?(%__MODULE__{}), do: false

  @spec encode_value(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  defp encode_value(value, opts)

  defp encode_value(%__MODULE__{type: :none}, _opts), do: {:ok, [tagged: {0, <<>>, 0}]}

  defp encode_value(%__MODULE__{type: :object, object: ref}, opts) do
    with {:ok, tags} <- DeviceObjectRef.encode(ref, opts) do
      {:ok, [constructed: {1, tags, 0}]}
    end
  end

  defp encode_value(
         %__MODULE__{
           type: :address,
           address: %RecipientAddress{network: network, address: address}
         },
         _opts
       ) do
    mac = if address == :broadcast, do: <<>>, else: address
    {:ok, [constructed: {2, [unsigned_integer: network, octet_string: mac], 0}]}
  end
end
