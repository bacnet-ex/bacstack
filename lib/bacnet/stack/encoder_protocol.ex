defprotocol BACnet.Stack.EncoderProtocol do
  @moduledoc """
  This protocol is used inside the BACnet stack (transport modules) to encode APDU structs into binary BACnet APDUs,
  which then are sent through the transport layer.
  """

  @doc """
  Whether the struct expects a reply (i.e. Confirmed Service Request).

  This is useful for NPCI calculation.
  """
  @spec expects_reply(t()) :: boolean()
  def expects_reply(apdu)

  @doc """
  Whether the struct is a request.
  """
  @spec is_request(t()) :: boolean()
  def is_request(apdu)

  @doc """
  Whether the struct is a response.
  """
  @spec is_response(t()) :: boolean()
  def is_response(apdu)

  @doc """
  Encodes the struct into a BACnet APDU binary packet.

  Any information that is additionally required by the transport layer,
  must be added by the transport layer.

  Any segmentation that needs to be applied, can not and will not be
  respected by this function.
  """
  @spec encode(t()) :: iodata()
  def encode(apdu)

  @doc """
  Whether the struct can be segmented (supported by the BACnet protocol).
  """
  @spec supports_segmentation(t()) :: boolean()
  def supports_segmentation(apdu)

  @doc """
  Same as `encode/1`, but respects the APDU maximum size.

  It will output a list of segmented binaries, that can be sent ordered to the transport layer. Rules around segmentation
  (such as Segment ACK) still apply for the transport layer.

  Conventionally, this function simply takes the encoded body and splits it apart into individual segments
  and adds the header.
  """
  @spec encode_segmented(t(), integer()) :: [iodata()]
  def encode_segmented(apdu, apdu_size)
end
