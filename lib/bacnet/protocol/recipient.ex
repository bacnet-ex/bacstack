defmodule BACnet.Protocol.Recipient do
  @moduledoc """
  A Recipient identifies the target of an event notification or a COV notification.
  It is a CHOICE between either a specific device (identified by its Device
  object identifier) or a network address (which may be a unicast address, a
  broadcast address, or a remote network broadcast).

  The distinction is important for event distribution. When a Notification Class
  object is configured with a device identifier as the recipient, it will
  automatically resolve the current network address of that device before sending
  the notification. When an address is configured directly, the notification is
  sent to that exact address without any resolution step. This gives system
  designers flexibility between robust "follow the device" addressing and
  lightweight "send to this fixed location" addressing.

  ### BACnet Specification References
  - **ASN.1** (Clause 21): `BACnetRecipient ::= CHOICE { device [0] BACnetObjectIdentifier, address [1] BACnetAddress }`
  - Combined with `BACnet.Protocol.Destination` (valid days, time window, transitions, etc.)
    inside Notification Class `recipient_list`.

  ### Examples (Doc Test)

  ```elixir
  iex> recipient = %Recipient{type: :device, device: %ObjectIdentifier{type: :device, instance: 123}, address: nil}
  iex> recipient.type
  :device
  ```
  """

  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.RecipientAddress

  @typedoc """
  Represents a BACnet notification recipient, which can be either a specific
  device (identified by its Device object identifier) or a raw network address.
  """
  @type t :: %__MODULE__{
          type: :address | :device,
          address: RecipientAddress.t() | nil,
          device: ObjectIdentifier.t() | nil
        }

  @fields [
    :type,
    :address,
    :device
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnet recipient into application tags encoding.
  """
  @spec encode(t(), Keyword.t()) :: {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = recipient, opts \\ []) do
    with {:ok, encoding} <- do_encode(recipient, opts) do
      {:ok, [encoding]}
    end
  end

  @doc """
  Decodes the given application tags encoding into a BACnet recipient.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}} | {:error, term()}
  def parse(tags) when is_list(tags) do
    with [head | rest] <- tags,
         {:ok, result} <- do_parse(head) do
      {:ok, {result, rest}}
    else
      [] -> {:error, :invalid_tags}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Validates whether the given BACnet recipient is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(t)

  def valid?(
        %__MODULE__{
          type: :address,
          address: %RecipientAddress{network: net, address: mac}
        } = _t
      )
      when is_integer(net) and net >= 0 and net <= 65_535 and
             (is_binary(mac) or mac == :broadcast) do
    # mac == :broadcast or String.match?(mac, ~r/[A-Z0-9]+/)
    true
  end

  def valid?(
        %__MODULE__{
          type: :device,
          device: %ObjectIdentifier{} = dev_ref
        } = _t
      ) do
    ObjectIdentifier.valid?(dev_ref)
  end

  def valid?(%__MODULE__{} = _t), do: false

  @spec do_parse(ApplicationTags.encoding()) :: {:ok, t()} | {:error, term()}
  defp do_parse({:tagged, {0, bytes, _length}}) do
    case ApplicationTags.unfold_to_type(:object_identifier, bytes) do
      {:ok, {_type, device}} ->
        recip = %__MODULE__{
          type: :device,
          address: nil,
          device: device
        }

        {:ok, recip}

      term ->
        term
    end
  end

  defp do_parse({:constructed, {1, tags, 0}}) do
    case tags do
      [{:unsigned_integer, network}, {:octet_string, mac_addr} | _tl] ->
        recip = %__MODULE__{
          type: :address,
          address: %RecipientAddress{
            network: network,
            address: if(mac_addr == "", do: :broadcast, else: mac_addr)
          },
          device: nil
        }

        {:ok, recip}

      _term ->
        {:error, :invalid_tags}
    end
  end

  defp do_parse(_tag_encoding) do
    {:error, :invalid_tags}
  end

  @spec do_encode(t(), Keyword.t()) :: {:ok, ApplicationTags.encoding()} | {:error, term()}
  defp do_encode(
         %__MODULE__{type: :address, address: %RecipientAddress{network: net, address: addr}} =
           _recipient,
         _opts
       ) do
    {:ok,
     {:constructed,
      {1, [unsigned_integer: net, octet_string: if(addr == :broadcast, do: "", else: addr)], 0}}}
  end

  defp do_encode(%__MODULE__{type: :device} = recipient, opts) do
    case ApplicationTags.encode_value({:object_identifier, recipient.device}, opts) do
      {:ok, bytes, _header} -> {:ok, {:tagged, {0, bytes, byte_size(bytes)}}}
      term -> term
    end
  end
end
