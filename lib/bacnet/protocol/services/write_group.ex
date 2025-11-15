defmodule BACnet.Protocol.Services.WriteGroup do
  @moduledoc """
  This module represents the BACnet Write Group service.

  The Write Group service is used to write efficiently values to a large number of devices and objects.

  Service Description (ASHRAE 135):
  > The purpose of WriteGroup is to facilitate the efficient distribution of values to a large number of devices and objects.
  > WriteGroup provides compact representations for data values that allow rapid transfer of many values. See Clause 12-53 and
  > Figure 12-10.
  > The WriteGroup service is used by a sending BACnet-user to update arbitrary Channel objects' Present_Value properties for
  > a particular numbered control group. The WriteGroup service is an unconfirmed service. Upon receipt of a WriteGroup
  > service request, all devices that are members of the specified control group shall write to their corresponding Channel objects'
  > Present_Value properties with the value applicable to the Channel Number, if any. A device shall be considered to be a
  > member of a control group if that device has one or more Channel objects for which the 'Group Number' from the service
  > appears in its Control_Groups property. If the receiving device does not contain one or more Channel objects with matching
  > channel numbers, then those values shall be ignored.
  > The WriteGroup service may be unicast, multicast, broadcast locally, on a particular remote network, or using the global
  > BACnet network address. Since global broadcasts are generally discouraged, the use of multiple directed broadcasts is
  > preferred.
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.GroupChannelValue
  alias BACnet.Protocol.Constants

  import Protocol.Utility, only: [pattern_extract_tags: 4]
  require Constants

  @behaviour Protocol.Services.Behaviour

  # TODO: Docs
  # TODO: Add Service Procedure to docs

  @type t :: %__MODULE__{
          group_number: ApplicationTags.unsigned32(),
          write_priority: 1..16,
          changelist: [GroupChannelValue.t()],
          inhibit_delay: boolean() | nil
        }

  @fields [
    :group_number,
    :write_priority,
    :changelist,
    :inhibit_delay
  ]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(:unconfirmed_service_choice, :write_group)

  @doc """
  Get the service name atom.
  """
  @spec get_name() :: atom()
  def get_name(), do: @service_name

  @doc """
  Whether the service is of type confirmed or unconfirmed.
  """
  @spec is_confirmed() :: false
  def is_confirmed(), do: false

  @doc """
  Converts the given Unconfirmed Service Request into a Write Group Service.
  """
  @spec from_apdu(Protocol.APDU.UnconfirmedServiceRequest.t()) ::
          {:ok, t()} | {:error, term()}
  def from_apdu(
        %Protocol.APDU.UnconfirmedServiceRequest{
          service: @service_name
        } = request
      ) do
    with {:ok, group_number, rest} <-
           pattern_extract_tags(
             request.parameters,
             {:tagged, {0, _c, _l}},
             :unsigned_integer,
             false
           ),
         :ok <-
           if(ApplicationTags.valid_int?(group_number, 32),
             do: :ok,
             else: {:error, :invalid_group_number_value}
           ),
         {:ok, write_priority, rest} <-
           pattern_extract_tags(rest, {:tagged, {1, _c, _l}}, :unsigned_integer, false),
         {:ok, {:constructed, {2, raw_changelist, _l}}, rest} <-
           pattern_extract_tags(rest, {:constructed, {2, _c, _l}}, nil, false),
         {:ok, changelist} <- parse_changelist(raw_changelist),
         {:ok, inhibit, _rest} <-
           pattern_extract_tags(rest, {:tagged, {3, _c, _l}}, :boolean, true) do
      write = %__MODULE__{
        group_number: group_number,
        write_priority: write_priority,
        changelist: changelist,
        inhibit_delay: inhibit
      }

      {:ok, write}
    else
      {:error, :missing_pattern} -> {:error, :invalid_request_parameters}
      {:error, _err} = err -> err
    end
  end

  def from_apdu(%Protocol.APDU.UnconfirmedServiceRequest{} = _request) do
    {:error, :invalid_request}
  end

  @doc """
  Get the Unconfirmed Service request for the given Write Group Service.

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec to_apdu(t(), Keyword.t()) ::
          {:ok, Protocol.APDU.UnconfirmedServiceRequest.t()}
          | {:error, term()}
  def to_apdu(%__MODULE__{} = service, _request_data) do
    with :ok <-
           if(ApplicationTags.valid_int?(service.group_number, 32),
             do: :ok,
             else: {:error, :invalid_group_number_value}
           ),
         {:ok, group_number, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, service.group_number}),
         {:ok, write_priority, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, service.write_priority}),
         {:ok, changelist} <- encode_changelist(service.changelist),
         {:ok, inhibit} <-
           (if service.inhibit_delay do
              with {:ok, inhibit, _header} <-
                     ApplicationTags.encode_value({:unsigned_integer, service.inhibit_delay}) do
                {:ok, [{:tagged, {3, inhibit, byte_size(inhibit)}}]}
              end
            else
              {:ok, []}
            end) do
      req = %Protocol.APDU.UnconfirmedServiceRequest{
        service: @service_name,
        parameters: [
          {:tagged, {0, group_number, byte_size(group_number)}},
          {:tagged, {1, write_priority, byte_size(write_priority)}},
          {:constructed, {2, changelist, 0}}
          | inhibit
        ]
      }

      {:ok, req}
    else
      {:error, _err} = err -> err
    end
  end

  defp parse_changelist(tags) do
    result =
      Enum.reduce_while(1..100_000//1, {tags, []}, fn
        _iter, {tags, acc} ->
          case GroupChannelValue.parse(tags) do
            {:ok, {item, []}} -> {:halt, {:ok, [item | acc]}}
            {:ok, {item, rest}} -> {:cont, {rest, [item | acc]}}
            {:error, _term} = term -> {:halt, term}
          end
      end)

    case result do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      term -> term
    end
  end

  defp encode_changelist(changelist) do
    result =
      Enum.reduce_while(changelist, {:ok, []}, fn change, {:ok, acc} ->
        case GroupChannelValue.encode(change) do
          {:ok, value} -> {:cont, {:ok, [value | acc]}}
          term -> {:halt, term}
        end
      end)

    case result do
      {:ok, list} ->
        tags =
          list
          |> Enum.reverse()
          |> List.flatten()

        {:ok, tags}

      term ->
        term
    end
  end

  defimpl Protocol.Services.Protocol do
    alias BACnet.Protocol
    alias BACnet.Protocol.Constants
    require Constants

    @spec get_name(@for.t()) :: atom()
    def get_name(%@for{} = _service), do: @for.get_name()

    @spec is_confirmed(@for.t()) :: boolean()
    def is_confirmed(%@for{} = _service), do: @for.is_confirmed()

    @spec to_apdu(@for.t(), Keyword.t()) ::
            {:ok, Protocol.APDU.UnconfirmedServiceRequest.t()}
            | {:error, term()}
    def to_apdu(%@for{} = service, request_data), do: @for.to_apdu(service, request_data)
  end
end
