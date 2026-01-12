defmodule BACnet.Protocol.Services.WhoHas do
  @moduledoc """
  This module represents the BACnet Who-Has service.

  The Who-Has service is used to find a specific object (by identifier or name),
  either by querying all or a subset of BACnet devices.

  Service Description (ASHRAE 135):
  > The Who-Has service is used by a sending BACnet-user to identify the device object identifiers and network addresses of
  > other BACnet devices whose local databases contain an object with a given Object_Name or a given Object_Identifier.
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants
  require Constants

  @behaviour Protocol.Services.Behaviour

  # TODO: Docs
  # TODO: Add Service Procedure to docs

  @type t :: %__MODULE__{
          device_id_low_limit: non_neg_integer() | nil,
          device_id_high_limit: non_neg_integer() | nil,
          object: Protocol.ObjectIdentifier.t() | String.t()
        }

  @fields [
    :device_id_low_limit,
    :device_id_high_limit,
    :object
  ]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(:unconfirmed_service_choice, :who_has)

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
  Converts the given Unconfirmed Service Request into a Who-Has Service.
  """
  @spec from_apdu(Protocol.APDU.UnconfirmedServiceRequest.t()) ::
          {:ok, t()} | {:error, term()}
  def from_apdu(
        %Protocol.APDU.UnconfirmedServiceRequest{
          service: @service_name
        } = request
      ) do
    with {id_low, id_high, params} <-
           (case request.parameters do
              [
                {:tagged, {0, low_limit, low_length}},
                {:tagged, {1, high_limit, high_length}} | tail
              ] ->
                <<id_low::size(^low_length)-unit(8)>> = low_limit
                <<id_high::size(^high_length)-unit(8)>> = high_limit
                {id_low, id_high, tail}

              _term ->
                {nil, nil, request.parameters}
            end),
         {:ok, {_type, object}} <-
           (case params do
              [{:tagged, {2, object, _length}} | _tail] ->
                ApplicationTags.unfold_to_type(:object_identifier, object)

              [{:tagged, {3, object, _length}} | _tail] ->
                ApplicationTags.unfold_to_type(:character_string, object)

              _else ->
                {:error, :invalid_request_parameters}
            end) do
      whohas = %__MODULE__{
        device_id_low_limit: id_low,
        device_id_high_limit: id_high,
        object: object
      }

      {:ok, whohas}
    else
      {:error, :missing_pattern} -> {:error, :invalid_request_parameters}
      {:error, _err} = err -> err
    end
  end

  def from_apdu(%Protocol.APDU.UnconfirmedServiceRequest{} = _request) do
    {:error, :invalid_request}
  end

  @doc """
  Get the Unconfirmed Service request for the given Who-Has Service.

  Additional supported `request_data`:
    - `encoding: atom()` - Optional. The encoding of the object name (defaults to `:utf8`).

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec to_apdu(t(), Keyword.t()) ::
          {:ok, Protocol.APDU.UnconfirmedServiceRequest.t()}
          | {:error, term()}
  def to_apdu(%__MODULE__{} = service, request_data) do
    # TODO: Refactor

    id_params =
      if service.device_id_low_limit && service.device_id_high_limit do
        if service.device_id_low_limit > service.device_id_high_limit do
          raise ArgumentError, "Low limit must be less than or equal to high limit"
        end

        unless service.device_id_low_limit >= 0 and service.device_id_low_limit <= 4_194_303 do
          raise ArgumentError,
                "Low limit must be between 0 and 4194303 inclusive, got: " <>
                  inspect(service.device_id_low_limit)
        end

        unless service.device_id_high_limit >= 0 and service.device_id_high_limit <= 4_194_303 do
          raise ArgumentError,
                "High limit must be between 0 and 4194303 inclusive, got: " <>
                  inspect(service.device_id_high_limit)
        end

        {:ok, id_low, _header} =
          ApplicationTags.encode_value(
            {:unsigned_integer, service.device_id_low_limit},
            request_data
          )

        low_size = byte_size(id_low)

        {:ok, id_high, _header} =
          ApplicationTags.encode_value(
            {:unsigned_integer, service.device_id_high_limit},
            request_data
          )

        high_size = byte_size(id_high)

        [{:tagged, {0, id_low, low_size}}, {:tagged, {1, id_high, high_size}}]
      else
        if service.device_id_low_limit || service.device_id_high_limit do
          raise ArgumentError,
                "Both of device_id_low_limit and device_id_high_limit must be set or unset"
        end

        []
      end

    params =
      id_params ++
        [
          case service.object do
            %Protocol.ObjectIdentifier{} = _object ->
              {:ok, value, _header} =
                ApplicationTags.encode_value(
                  {:object_identifier, service.object},
                  request_data
                )

              {:tagged, {2, value, byte_size(value)}}

            string when is_binary(string) ->
              unless String.valid?(string) and String.printable?(string) do
                raise ArgumentError,
                      "Invalid UTF-8 string for object name (must be valid UTF-8 and printable)"
              end

              {:ok, value, _header} =
                ApplicationTags.encode_value(
                  {:character_string, service.object},
                  request_data
                )

              {:tagged, {3, value, byte_size(value)}}

            term ->
              raise ArgumentError,
                    "Invalid object, must be a string or an ObjectIdentifier, got: #{inspect(term)}"
          end
        ]

    req = %Protocol.APDU.UnconfirmedServiceRequest{
      service: @service_name,
      parameters: params
    }

    {:ok, req}
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
