# `BACnet.Protocol.Services.Behaviour`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/behaviour.ex#L1)

# `get_name`

```elixir
@callback get_name() :: atom()
```

Get the service name atom.

# `is_confirmed`

```elixir
@callback is_confirmed() :: boolean()
```

Whether the service is of type confirmed or unconfirmed.

# `to_apdu`

```elixir
@callback to_apdu(
  struct(),
  Keyword.t()
) ::
  {:ok,
   BACnet.Protocol.APDU.ConfirmedServiceRequest.t()
   | BACnet.Protocol.APDU.UnconfirmedServiceRequest.t()}
  | {:error, term()}
```

Get a service request APDU for this service.

For confirmed service requests, the following keys default to specific values, if not specified:
  - `segmented_response_accepted: true`
  - `max_segments: :more_than_64`
  - `max_apdu: 1476`
  - `invoke_id: 0`

These keys can be overriden through `request_data`. `request_data` may be ignored for unconfirmed services.

When setting `max_segments`, do not use `:unspecified` because it makes it for the server unable to determine
if the response is transmittable or not. Thus `:unspecified` might be as low as maximum two segments.
For that reason, always use a specific max segments or `:more_than_64`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
