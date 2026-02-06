# `BACnet.Protocol.APDU.ConfirmedServiceRequest`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/apdu/confirmed_service_request.ex#L1)

Confirmed Service Request APDUs are used to convey
the information contained in confirmed service request primitives.

Confirmed Service Requests require the BACnet server
to reply with an appropriate response (such as ACK or error).

This module has functions for encoding Confirmed Service Request APDUs.
Decoding is handled by `BACnet.Protocol.APDU`.

This module implements the `BACnet.Stack.EncoderProtocol`.

# `service`

```elixir
@type service() ::
  BACnet.Protocol.Services.AcknowledgeAlarm.t()
  | BACnet.Protocol.Services.AddListElement.t()
  | BACnet.Protocol.Services.AtomicReadFile.t()
  | BACnet.Protocol.Services.AtomicWriteFile.t()
  | BACnet.Protocol.Services.ConfirmedCovNotification.t()
  | BACnet.Protocol.Services.ConfirmedEventNotification.t()
  | BACnet.Protocol.Services.ConfirmedPrivateTransfer.t()
  | BACnet.Protocol.Services.ConfirmedTextMessage.t()
  | BACnet.Protocol.Services.CreateObject.t()
  | BACnet.Protocol.Services.DeleteObject.t()
  | BACnet.Protocol.Services.DeviceCommunicationControl.t()
  | BACnet.Protocol.Services.GetAlarmSummary.t()
  | BACnet.Protocol.Services.GetEnrollmentSummary.t()
  | BACnet.Protocol.Services.GetEventInformation.t()
  | BACnet.Protocol.Services.LifeSafetyOperation.t()
  | BACnet.Protocol.Services.ReadProperty.t()
  | BACnet.Protocol.Services.ReadPropertyMultiple.t()
  | BACnet.Protocol.Services.ReadRange.t()
  | BACnet.Protocol.Services.ReinitializeDevice.t()
  | BACnet.Protocol.Services.RemoveListElement.t()
  | BACnet.Protocol.Services.SubscribeCov.t()
  | BACnet.Protocol.Services.SubscribeCovProperty.t()
  | BACnet.Protocol.Services.WriteProperty.t()
  | BACnet.Protocol.Services.WritePropertyMultiple.t()
```

BACnet Confirmed Service Request service structs.

# `t`

```elixir
@type t() :: %BACnet.Protocol.APDU.ConfirmedServiceRequest{
  invoke_id: 0..255,
  max_apdu: BACnet.Protocol.Constants.max_apdu(),
  max_segments: BACnet.Protocol.Constants.max_segments(),
  parameters: BACnet.Protocol.ApplicationTags.encoding_list(),
  proposed_window_size: 1..127 | nil,
  segmented_response_accepted: boolean(),
  sequence_number: 0..255 | nil,
  service:
    BACnet.Protocol.Constants.confirmed_service_choice() | non_neg_integer()
}
```

Represents the Application Data Unit (APDU) Confirmed Service Request.

To allow forward compatibility, service is allowed to be an integer.

# `encode`

```elixir
@spec encode(t()) :: {:ok, iodata()} | {:error, Exception.t()}
```

Encodes the Confirmed Service Request APDU into binary data.

Note that segmentation is ignored.

# `to_service`

```elixir
@spec to_service(t()) :: {:ok, service()} | {:error, term()} | :not_supported
```

Converts the APDU into a service, if supported and possible.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
