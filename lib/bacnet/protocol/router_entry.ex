defmodule BACnet.Protocol.RouterEntry do
  @moduledoc """
  A BACnetRouterEntry describes one first-hop router that can be used to reach
  a remote BACnet network.

  It is the element type of the `Routing_Table` property of the Network Port
  object. The table is normally maintained automatically by the network layer
  from received I-Am-Router-To-Network / I-Could-Be-Router-To-Network messages,
  but may also be configured statically.

  ### ASN.1 (ASHRAE 135)

      BACnetRouterEntry ::= SEQUENCE {
          network-number    [0] Unsigned16,
          mac-address       [1] OCTET STRING,
          status            [2] ENUMERATED {
                                  available    (0),
                                  busy         (1),
                                  disconnected (2)
                                },
          performance-index [3] Unsigned8 OPTIONAL
      }

  ### Status values

  - `:available`   - the router is ready to forward traffic
  - `:busy`        - the router is temporarily unable to accept more traffic
  - `:disconnected`- the router is known but currently unreachable

  The optional `performance_index` is the value carried in an
  I-Could-Be-Router-To-Network message (Clause 6.4.3).
  """

  alias BACnet.Protocol.ApplicationTags

  @typedoc """
  Status of a router entry.
  """
  @type status :: :available | :busy | :disconnected

  @typedoc """
  A single entry in a Network Port Routing_Table.
  """
  @type t :: %__MODULE__{
          network_number: 0..65_535,
          mac_address: binary(),
          status: status(),
          performance_index: 0..255 | nil
        }

  @fields [:network_number, :mac_address, :status, :performance_index]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnetRouterEntry into application tags encoding.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = entry, _opts \\ []) do
    with true <- entry.network_number >= 0 and entry.network_number <= 65_535,
         true <- is_binary(entry.mac_address),
         {:ok, status_val} <- status_to_int(entry.status),
         {:ok, net_tag} <-
           ApplicationTags.create_tag_encoding(0, :unsigned_integer, entry.network_number),
         {:ok, mac_tag} <-
           ApplicationTags.create_tag_encoding(1, :octet_string, entry.mac_address),
         {:ok, status_tag} <-
           ApplicationTags.create_tag_encoding(2, :enumerated, status_val) do
      tags = [net_tag, mac_tag, status_tag]

      tags =
        case entry.performance_index do
          nil ->
            tags

          idx when is_integer(idx) and idx >= 0 and idx <= 255 ->
            case ApplicationTags.create_tag_encoding(3, :unsigned_integer, idx) do
              # credo:disable-for-next-line Credo.Check.Refactor.AppendSingleItem
              {:ok, perf_tag} -> tags ++ [perf_tag]
              err -> err
            end

          _other ->
            {:error, :invalid_performance_index}
        end

      case tags do
        list when is_list(list) -> {:ok, list}
        {:error, _err} = err -> err
      end
    else
      {:error, _err} = err -> err
      _else -> {:error, :invalid_data}
    end
  end

  @doc """
  Parses a BACnetRouterEntry from application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}} | {:error, term()}
  def parse(tags) when is_list(tags) do
    with [
           {:tagged, {0, net_bytes, _len1}},
           {:tagged, {1, mac, _len2}},
           {:tagged, {2, status_bytes, _len3}}
           | rest0
         ] <- tags,
         {:ok, {:unsigned_integer, network}} <-
           ApplicationTags.unfold_to_type(:unsigned_integer, net_bytes),
         {:ok, {:enumerated, status_int}} <-
           ApplicationTags.unfold_to_type(:enumerated, status_bytes),
         {:ok, status} <- int_to_status(status_int) do
      if network >= 0 and network <= 65_535 do
        {perf, rest} =
          case rest0 do
            [{:tagged, {3, perf_bytes, _len}} | r] ->
              case ApplicationTags.unfold_to_type(:unsigned_integer, perf_bytes) do
                {:ok, {:unsigned_integer, index}} when index >= 0 and index <= 255 -> {index, r}
                _else -> {nil, rest0}
              end

            _else ->
              {nil, rest0}
          end

        entry = %__MODULE__{
          network_number: network,
          mac_address: mac,
          status: status,
          performance_index: perf
        }

        {:ok, {entry, rest}}
      else
        {:error, :invalid_network_number}
      end
    else
      {:error, _err} = err -> err
      _else -> {:error, :invalid_tags}
    end
  end

  @doc """
  Validates whether the given RouterEntry is well-formed.
  """
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{
        network_number: net,
        mac_address: mac,
        status: status,
        performance_index: perf
      })
      when is_integer(net) and net >= 0 and net <= 65_535 and is_binary(mac) and
             status in [:available, :busy, :disconnected] and
             (is_nil(perf) or (is_integer(perf) and perf >= 0 and perf <= 255)) do
    true
  end

  def valid?(%__MODULE__{}), do: false

  @spec status_to_int(status()) :: {:ok, non_neg_integer()} | {:error, term()}
  defp status_to_int(:available), do: {:ok, 0}
  defp status_to_int(:busy), do: {:ok, 1}
  defp status_to_int(:disconnected), do: {:ok, 2}
  defp status_to_int(__other), do: {:error, :invalid_status}

  @spec int_to_status(non_neg_integer()) :: {:ok, status()} | {:error, term()}
  defp int_to_status(0), do: {:ok, :available}
  defp int_to_status(1), do: {:ok, :busy}
  defp int_to_status(2), do: {:ok, :disconnected}
  defp int_to_status(_other), do: {:error, :invalid_status}
end
