# `BACnet.Protocol.PropertyState`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/property_state.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.PropertyState{
  type: BACnet.Protocol.Constants.property_state(),
  value: value()
}
```

Represents a BACnet property state.

# `value`

```elixir
@type value() ::
  (boolean_value :: boolean())
  | (binary_value :: boolean())
  | (event_type :: BACnet.Protocol.Constants.event_type())
  | (polarity :: BACnet.Protocol.Constants.polarity())
  | (program_change :: BACnet.Protocol.Constants.program_request())
  | (program_state :: BACnet.Protocol.Constants.program_state())
  | (reason_for_halt :: BACnet.Protocol.Constants.program_error())
  | (reliability :: BACnet.Protocol.Constants.reliability())
  | (state :: BACnet.Protocol.Constants.event_state())
  | (system_status :: BACnet.Protocol.Constants.device_status())
  | (units :: BACnet.Protocol.Constants.engineering_unit())
  | (unsigned_value :: non_neg_integer())
  | (life_safety_mode :: BACnet.Protocol.Constants.life_safety_mode())
  | (life_safety_state :: BACnet.Protocol.Constants.life_safety_state())
  | (restart_reason :: BACnet.Protocol.Constants.restart_reason())
  | (door_alarm_state :: BACnet.Protocol.Constants.door_alarm_state())
  | (action :: BACnet.Protocol.Constants.action())
  | (door_secured_status :: BACnet.Protocol.Constants.door_secured_status())
  | (door_status :: BACnet.Protocol.Constants.door_status())
  | (door_value :: BACnet.Protocol.Constants.door_value())
  | (file_access_method :: BACnet.Protocol.Constants.file_access_method())
  | (lock_status :: BACnet.Protocol.Constants.lock_status())
  | (life_safety_operation :: BACnet.Protocol.Constants.life_safety_operation())
  | (maintenance :: BACnet.Protocol.Constants.maintenance())
  | (node_type :: BACnet.Protocol.Constants.node_type())
  | (notify_type :: BACnet.Protocol.Constants.notify_type())
  | (security_level :: BACnet.Protocol.Constants.security_level())
  | (shed_state :: BACnet.Protocol.Constants.shed_state())
  | (silenced_state :: BACnet.Protocol.Constants.silenced_state())
  | (backup_state :: BACnet.Protocol.Constants.backup_state())
  | (write_status :: BACnet.Protocol.Constants.write_status())
  | (lighting_in_progress :: BACnet.Protocol.Constants.lighting_in_progress())
  | (lighting_operation :: BACnet.Protocol.Constants.lighting_operation())
  | (lighting_transition :: BACnet.Protocol.Constants.lighting_transition())
  | (integer_value :: integer())
```

Represents the value type for property states.

The name for each value type represents the property state type (`t:Constants.property_state/0`).

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes a BACnet property state into application tags encoding.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet property state from application tags encoding.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given property state is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
