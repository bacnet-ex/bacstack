# `BACnet.Protocol.Services.AtomicWriteFile`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/atomic_write_file.ex#L1)

This module represents the BACnet Atomic Write File service.

The Atomic Write File service is used to atomically write to a file on a device.

Service Description (ASHRAE 135):
> The AtomicWriteFile Service is used by a client BACnet-user to perform an open-write-close operation of an OCTET
> STRING into a specified position or a list of OCTET STRINGs into a specified group of records in a file. The file may be
> accessed as records or as a stream of octets.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.AtomicWriteFile{
  data: (stream_based :: binary()) | (record_based :: [binary()]),
  object_identifier: BACnet.Protocol.ObjectIdentifier.t(),
  start_position: integer(),
  stream_access: boolean()
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.ConfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Confirmed Service Request into an Atomic Write File Service.

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

Get the Confirmed Service request for the given Atomic Write File Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
