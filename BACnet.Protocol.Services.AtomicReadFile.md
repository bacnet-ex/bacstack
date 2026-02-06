# `BACnet.Protocol.Services.AtomicReadFile`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/atomic_read_file.ex#L1)

This module represents the BACnet Atomic Read File service.

The Atomic Read File service is used to atomically read from a file on a device.

Service Description (ASHRAE 135):
> The AtomicReadFile Service is used by a client BACnet-user to perform an open-read-close operation on the contents of the
> specified file. The file may be accessed as records or as a stream of octets.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.AtomicReadFile{
  object_identifier: BACnet.Protocol.ObjectIdentifier.t(),
  requested_count: non_neg_integer(),
  start_position: integer(),
  stream_access: boolean()
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.ConfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Confirmed Service Request into an Atomic Read File Service.

# `get_name`

```elixir
@spec get_name() :: atom()
```

Get the service name atom.

# `is_confirmed`

```elixir
@spec is_confirmed() :: true
```

Whether the service is of type confirmed or unconfirmed.

# `to_apdu`

```elixir
@spec to_apdu(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.APDU.ConfirmedServiceRequest.t()} | {:error, term()}
```

Get the Confirmed Service request for the given Atomic Read File Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
