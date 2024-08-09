defmodule BACnet.Protocol.AddressBinding do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.NetworkLayerProtocolMessage
  alias BACnet.Protocol.ObjectIdentifier

  require Constants

  @type t :: %__MODULE__{
          device_identifier: ObjectIdentifier.t(),
          network: NetworkLayerProtocolMessage.dnet(),
          address: binary()
        }

  @fields [:device_identifier, :network, :address]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnet address binding into BACnet application tags encoding.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(
        %__MODULE__{
          device_identifier: %ObjectIdentifier{type: :device},
          network: net,
          address: mac
        } = access_spec,
        _opts \\ []
      )
      when is_integer(net) and net >= 0 and is_binary(mac) do
    params = [
      {:object_identifier, access_spec.device_identifier},
      {:unsigned_integer, net},
      {:octet_string, String.upcase(mac, :ascii)}
    ]

    {:ok, params}
  end

  @doc """
  Parses a BACnet address binding from BACnet application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}}
          | {:error, term()}
  def parse(tags) when is_list(tags) do
    case tags do
      [
        {:object_identifier, dev},
        {:unsigned_integer, net},
        {:octet_string, mac}
        | rest
      ] ->
        addr = %__MODULE__{
          device_identifier: dev,
          network: net,
          address: String.upcase(mac, :ascii)
        }

        {:ok, {addr, rest}}

      _else ->
        {:error, :invalid_tags}
    end
  end

  @doc """
  Validates whether the given address binding is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          device_identifier: %ObjectIdentifier{type: :device} = dev_ref,
          network: net,
          address: mac
        } = _t
      )
      when is_integer(net) and net >= 0 and net <= 65_535 and is_binary(mac) do
    ObjectIdentifier.valid?(dev_ref) and String.match?(mac, ~r/[A-Z0-9]+/)
  end

  def valid?(%__MODULE__{} = _t), do: false
end
