defmodule BACnet.Protocol.Services.IAm do
  @moduledoc """
  This module represents the BACnet I-Am service.

  The I-Am service is used as a response to the Who-Is service. It may also be used to announce itself (the device).

  Service Description (ASHRAE 135):
  > The I-Am service is used to respond to Who-Is service requests. However, the IAm service request may be issued at any time.
  > It does not need to be preceded by the receipt of a Who-Is service request.
  > In particular, a device may wish to broadcast an I-Am service request when it powers up. The network address is derived either
  > from the MAC address associated with the I-Am service request, if the device issuing the request is on the local network, or
  > from the NPCI if the device is on a remote network.
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants
  require Constants

  @behaviour Protocol.Services.Behaviour

  # TODO: Docs
  # TODO: Add Service Procedure to docs

  @type t :: %__MODULE__{
          device: Protocol.ObjectIdentifier.t(),
          max_apdu: pos_integer(),
          segmentation_supported: Constants.segmentation(),
          vendor_id: ApplicationTags.unsigned16()
        }

  @fields [
    :device,
    :max_apdu,
    :segmentation_supported,
    :vendor_id
  ]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(:unconfirmed_service_choice, :i_am)

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
  Converts the given Unconfirmed Service Request into an I-Am Service.

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec from_apdu(Protocol.APDU.UnconfirmedServiceRequest.t()) ::
          {:ok, t()} | {:error, term()}
  def from_apdu(
        %Protocol.APDU.UnconfirmedServiceRequest{
          service: @service_name
        } = request
      ) do
    case request.parameters do
      [
        {:object_identifier, %Protocol.ObjectIdentifier{} = object_identifier},
        {:unsigned_integer, apdu},
        {:enumerated, segmented},
        {:unsigned_integer, vendor_id} | _tail
      ] ->
        with :ok <-
               if(ApplicationTags.valid_int?(vendor_id, 16),
                 do: :ok,
                 else: {:error, :invalid_vendor_id_value}
               ),
             {:ok, seg_c} <-
               Constants.by_value_with_reason(
                 :segmentation,
                 segmented,
                 {:unknown_segmentation, segmented}
               ) do
          iam = %__MODULE__{
            device: object_identifier,
            max_apdu: apdu,
            segmentation_supported: seg_c,
            vendor_id: vendor_id
          }

          {:ok, iam}
        end

      _term ->
        {:error, :invalid_request_parameters}
    end
  end

  def from_apdu(%Protocol.APDU.UnconfirmedServiceRequest{} = _request) do
    {:error, :invalid_request}
  end

  @doc """
  Get the Unconfirmed Service request for the given I-Am Service.

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec to_apdu(t(), Keyword.t()) ::
          {:ok, Protocol.APDU.UnconfirmedServiceRequest.t()}
          | {:error, term()}
  def to_apdu(
        %__MODULE__{
          device: %Protocol.ObjectIdentifier{} = device,
          max_apdu: apdu,
          segmentation_supported: seg,
          vendor_id: vendor
        } = service,
        _request_data
      )
      when is_integer(apdu) and apdu >= 0 and
             is_integer(vendor) and vendor >= 0 do
    with :ok <-
           if(ApplicationTags.valid_int?(vendor, 16),
             do: :ok,
             else: {:error, :invalid_vendor_id_value}
           ),
         {:ok, seg_c} <-
           Constants.by_name_with_reason(:segmentation, seg, {:unknown_segmentation, seg}) do
      req = %Protocol.APDU.UnconfirmedServiceRequest{
        service: @service_name,
        parameters: [
          object_identifier: device,
          unsigned_integer: service.max_apdu,
          enumerated: seg_c,
          unsigned_integer: service.vendor_id
        ]
      }

      {:ok, req}
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
