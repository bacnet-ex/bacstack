<!--t: Driving a Group object -->

# Driving a Group object

`BACnet.Protocol.ObjectTypes.Group` provides a named view over properties of local objects.
When the host prepares a Present_Value read, Group fetches its member properties and
builds a list of `BACnet.Protocol.ReadAccessResult` values. Each property has a value
or an access error.

The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
is the integrating application that owns results, serializes operations, supplies property
I/O and serves BACnet requests. Group owns traversal, value conversion and result construction.

Run the example from the repository root.

```sh
mix run examples/objects_lifecycle/group_lifecycle.exs
```

The example's Agent holds a Group, an Analog Value and a Calendar. The example initializes
each object and retains its lifecycle state before reading it. Its selector catalog uses
the base property declarations of those objects. A catalog for a BACnet service also needs
to account for the instance's conditional and proprietary properties.

## Configure membership and initialize

Supply a nonempty list of `BACnet.Protocol.AccessSpecification` values. Each contains a local
object identifier and a nonempty property list. Explicit properties use
`BACnet.Protocol.AccessSpecification.Property` with `property_value: nil`, and may include an
array index. Selectors use `:all`, `:required` or `:optional`.

Members must reside in the same device. Their specifications have no device field, and Group
passes local references to its callbacks. A Group may read metadata of another Group or Global
Group, but cannot read their `present_value`. `ALL` and `REQUIRED` on those object types are
rejected because they include that required property. `OPTIONAL` remains permitted.

Initialization clears any previous aggregate without reading members. Group requests no timer
and preserves the supplied runtime state. Retain the initialization result before serving it.
An unavailable member need not be rejected during configuration - its later access failure
belongs in the result.

## Keep ordinary reads as native values

`BACnet.Protocol.ObjectExecution.Context.read_property/2` receives a
`BACnet.Protocol.DeviceObjectPropertyRef` and returns `{:ok, value}` or `{:error, reason}`.
The walkthrough's callback obtains a native float, string or boolean from each source.

For a computed source, the callback first calls
`BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2` with that source's retained state
and the operation's clocks. It retains the refreshed source before reading its property.
A source requesting immediate continuations needs those completed before its value is returned.
The example's Calendar and plain Analog Value require no such continuations.

Group converts native property values with `BACnet.Protocol.ObjectsUtility.cast_value_to_property/4`.
It handles NULL, array-length reads, priority slots and common virtual properties at that
boundary. Encodings or encoding lists may also be returned when a native datatype cannot be
inferred, such as a proprietary property. Unencodable native values produce a property access
error and do not stop following reads.

## Supply a separate multiple-property callback

Selectors use `BACnet.Protocol.ObjectExecution.Context.read_property_multiple/3`.
The callback receives a local `BACnet.Protocol.DeviceObjectRef` and a one-element selector
list. On success, return `{:ok, property_map}`, using property identifiers or
`{property_identifier, array_index}` keys. The map values are native property values or
`{:error, reason}` for individual failures. For an operation-wide failure, return
`{:error, reason}` directly.

This complete example uses only a selector callback:

```elixir
alias BACnet.Protocol.AccessSpecification
alias BACnet.Protocol.ObjectExecution.{Context, Lifecycle}
alias BACnet.Protocol.ObjectIdentifier
alias BACnet.Protocol.ObjectTypes.Group

member = %AccessSpecification{
  object_identifier: %ObjectIdentifier{type: :analog_value, instance: 2},
  properties: [:all]
}
{:ok, group} = Group.create(1600, "Room view", %{list_of_group_members: [member]})
context = Context.new({:property_read, :present_value, nil},
  now: ~U[2026-11-09 08:00:00Z], monotonic_time: 0,
  read_property_multiple: fn _reference, [:all] ->
    {:ok, %{object_name: "Room temperature", present_value: 21.5,
      description: {:error, :read_access_denied}}}
  end)
{:ok, stored} = Lifecycle.prepare_read(group, context)
{:ok, [member_result]} = Group.get_property(stored.object, :present_value)
Enum.map(member_result.results, &{&1.property_identifier, &1.error})
# [description: %BACnet.Protocol.BACnetError{class: :property, code: :read_access_denied},
#  object_name: nil, present_value: nil]
```

The callback shape resembles `BACnet.Stack.ClientHelper.read_property_multiple/5`'s transformed
map. Group also needs selected-property failures retained as error entries - that helper's
transformed map omits them, so a faithful adapter needs to preserve them separately. Group
constructs the protocol results from the returned values and errors.

The host's catalog needs these selection rules:

| Selector | Included properties |
| --- | --- |
| `ALL` | All implemented properties, including proprietary ones, except Property_List. |
| `REQUIRED` | Standard properties with conformance code R or W, except Property_List. |
| `OPTIONAL` | Present standard properties with conformance code O. |

Group preserves explicit member/property ordering and duplicates. It sorts each map expansion
by numeric property identifier and array index, giving a stable order without relying on map
iteration. An empty map produces an empty expansion. A callback must not introduce an
unexpanded selector or a forbidden nested Group value.

## Refresh before every read

Call `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2` for every read of `present_value`,
retain the successful result, then use `BACnet.Protocol.ObjectTypes.Group.get_property/2`.
The example changes the Analog Value and reads the Group again with the same clock
samples. The second read includes the new value. The example then advances past midnight
and refreshes the Calendar before returning its new value.

Use the same refresh for `ALL` and `REQUIRED` because both include Present_Value.
Group reads its members on demand. Present_Value is a BACnet list. A request
with an array index fails before Group reads any member.

## Retain partial failures and prepare membership writes

An inaccessible property becomes a `BACnet.Protocol.BACnetError` in that property's result.
The walkthrough denies access to the description and still reads the following Calendar
member. Later it selects an unavailable object and returns OBJECT / UNKNOWN_OBJECT.
Even an entirely failed acquisition produces a successful lifecycle result to retain and serve.

Hosts can return a BACnet error directly for precise standard or proprietary codes. Group also
maps common library errors and maps other operational reasons to DEVICE / OPERATIONAL_PROBLEM.
The module documentation lists those mappings. Callback exceptions and malformed results remain
programming errors.

Membership changes follow preparation, commit and execution. The example builds a candidate
with `BACnet.Protocol.ObjectTypes.Group.update_property/3`, prepares it with
`BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3`, commits it while retaining state,
then executes the same property-write trigger. Preparation clears the old aggregate without
reading replacements. The next read acquires the new membership. `present_value` is read-only
to clients, and property updates alone do not invoke the lifecycle.

Group has no intrinsic reporting implementation or Reliability property. After restart,
initialize with fresh context and refresh before reading. Remote Group snapshots remain passive
and reject local write preparation. The host remains responsible for property-service access,
bounded waits and avoiding cyclic reads or synchronous re-entry into a blocked owner.
