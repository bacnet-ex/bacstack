# `BACnet.Protocol.NPCI`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/npci.ex#L1)

Network Protocol Control Information (NPCI) are used to determine
priority, whether reply is expected, for who by who this frame is
and what kind of BACnet Data Unit this is.

BACnet Data Units can be divided into Application and Network Service.
Where Application frames are called APDU and Network Service frames are
called NSDU. Network Service frames are mostly used by and for BACnet routers.

# `t`

```elixir
@type t() :: %BACnet.Protocol.NPCI{
  destination: BACnet.Protocol.NpciTarget.t() | nil,
  expects_reply: boolean(),
  hopcount: non_neg_integer() | nil,
  is_network_message: boolean(),
  priority: BACnet.Protocol.Constants.npdu_control_priority(),
  source: BACnet.Protocol.NpciTarget.t() | nil
}
```

Represents Network Protocol Control Information (NPCI).

# `encode`

```elixir
@spec encode(t(), Keyword.t()) :: iodata()
```

Creates a NPCI iodata from the NPCI struct.

If `destination` is not nil, but `net` is nil, `net` will default to `1`.

# `get_version`

```elixir
@spec get_version() :: non_neg_integer()
```

Get the NPCI version.

# `new`

```elixir
@spec new(Keyword.t()) :: t()
```

Creates a new NPCI struct with the given fields.

The following default values are applied:
```ex
priority: :normal,
expects_reply: false,
destination: nil,
source: nil,
hopcount: nil,
is_network_message: false
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
