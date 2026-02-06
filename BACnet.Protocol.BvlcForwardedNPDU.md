# `BACnet.Protocol.BvlcForwardedNPDU`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/bvlc_forwarded_npdu.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.BvlcForwardedNPDU{
  originating_ip: :inet.ip_address(),
  originating_port: :inet.port_number()
}
```

# `decode`

```elixir
@spec decode(binary()) :: {:ok, {t(), rest :: binary()}} | {:error, term()}
```

Decodes a BVLC Forwarded NPDU from binary data.

# `encode`

```elixir
@spec encode(t()) :: {:ok, binary()} | {:error, term()}
```

Encodes a BVLC Forwarded NPDU to binary data.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
