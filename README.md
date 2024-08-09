# BACstack

BACstack is a low-level Elixir implementation for the ASHRAE standard 135, BACnet - Building Automation and Controller network.
This implementation supports ASHRAE 135-xxxx and BACnet/IPv4. Support for other transport layers (such as BACnet/SC, BACnet/MSTP)
can be straight forward added on top of it.

As this is a low-level implementation, users of this library are required to do the heavy-lifting of the BACnet stack,
such as automatically replying to Who-Is services, applying hard application timeout constraints, synchronizing time, etc.

If you're looking for a high level Elixir abstraction on top of this library, check out [BACnex].
BACnex is a high level abstraction on top of this library, that offers the high level features of a regular BACnet stack.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `bacstack` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bacstack, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/bacstack>.

## Character Sets

This library uses the library [Codepagex](https://hex.pm/packages/codepagex) to implement character set conversion.
By default, Codepagex only generates conversion code for fast conversion algorithms to and from UTF-8 (such as ISO-8859-1).

If you need to use other character sets, such as CP932 (JIS-X-0208) or CP850 (DBCS), you will have to configure  Codepagex accordingly.
Refer to their documentation for the necessary steps.

## Status of BACnet objects implementation

| Object Type                  | Representation | Execute | Intrinsic Reporting |
|------------------------------|----------------|---------|---------------------|
| Accumulator                  |      Beta      |    -    |          -          |
| Analog Input                 |      Beta      |    -    |          -          |
| Analog Output                |      Beta      |    -    |          -          |
| Analog Value                 |      Beta      |    -    |          -          |
| Averaging                    |      Beta      |    -    |          -          |
| Binary Input                 |      Beta      |    -    |          -          |
| Binary Output                |      Beta      |    -    |          -          |
| Binary Value                 |      Beta      |    -    |          -          |
| Calendar                     |      Beta      |    -    |          -          |
| Command                      |      Beta      |    -    |          -          |
| Device                       |      Beta      |    -    |          -          |
| Event Enrollment             |      Beta      |    -    |          -          |
| File                         |      Beta      |    -    |          -          |
| Group                        |      Beta      |    -    |          -          |
| Life Safety Point            |       N/A      |    -    |          -          |
| Life Safety Zone             |       N/A      |    -    |          -          |
| Loop                         |      Beta      |    -    |          -          |
| Multistate Input             |      Beta      |    -    |          -          |
| Multistate Output            |      Beta      |    -    |          -          |
| Multistate Value             |      Beta      |    -    |          -          |
| Notification Class           |      Beta      |    -    |          -          |
| Program                      |      Beta      |    -    |          -          |
| Pulse Converter              |      Beta      |    -    |          -          |
| Schedule                     |      Beta      |    -    |          -          |
| Event Log                    |      Beta      |    -    |          -          |
| Trend Log                    |      Beta      |    -    |          -          |
| Trend Log Multiple           |      Beta      |    -    |          -          |
| Load Control                 |        -       |    -    |          -          |
| Access Point                 |       N/A      |    -    |          -          |
| Access Zone                  |       N/A      |    -    |          -          |
| Access User                  |       N/A      |    -    |          -          |
| Access Rights                |       N/A      |    -    |          -          |
| Access Credential            |       N/A      |    -    |          -          |
| Credential Data Input        |       N/A      |    -    |          -          |
| Structured View              |      Beta      |    -    |          -          |
| Character String Value       |      Beta      |    -    |          -          |
| DateTime Value               |      Beta      |    -    |          -          |
| Large Analog Value           |      Beta      |    -    |          -          |
| Bitstring                    |      Beta      |    -    |          -          |
| Octet String Value           |      Beta      |    -    |          -          |
| Time Value                   |      Beta      |    -    |          -          |
| Integer Value                |      Beta      |    -    |          -          |
| Positive Integer Value       |      Beta      |    -    |          -          |
| Date Value                   |      Beta      |    -    |          -          |
| DateTime Pattern Value       |      Beta      |    -    |          -          |
| Time Pattern Value           |      Beta      |    -    |          -          |
| Date Pattern Value           |      Beta      |    -    |          -          |
| Network Security             |       N/A      |    -    |          -          |
| Global Group                 |        -       |    -    |          -          |
| Notification Forwarder       |        -       |    -    |          -          |
| Alert Enrollment             |        -       |    -    |          -          |
| Channel                      |        -       |    -    |          -          |
| Lighting Output              |        -       |    -    |          -          |

## Status of BACnet services implementation

| Service Name                 | Receive | Send  | ACK (Pos/Neg)  |
|------------------------------|---------|-------|----------------|
| Confirmed COV                |    x    |   x   |  Simple/Error  |
| Unconfirmed COV              |    x    |   x   |                |
| Confirmed Event              |    x    |   x   |  Simple/Error  |
| Unconfirmed Event            |    x    |   x   |                |
| Acknowledge Alarm            |    x    |   x   |  Simple/Error  |
| Get Alarm Summary            |    x    |   x   |     x/Error    |
| Get Enrollment Summary       |    x    |   x   |     x/Error    |
| Get Event Information        |    x    |   x   |     x/Error    |
| Life Safety Operation        |    x    |   x   |  Simple/Error  |
| Subscribe COV                |    x    |   x   |  Simple/Error  |
| Subscribe COV Property       |    x    |   x   |  Simple/Error  |
| Atomic Read File             |    x    |   x   |     x/Error    |
| Atomic Write File            |    x    |   x   |     x/Error    |
| Add List Element             |    x    |   x   |    Simple/x    |
| Remove List Element          |    x    |   x   |    Simple/x    |
| Create Object                |    x    |   x   |       x/x      |
| Delete Object                |    x    |   x   |    Simple/x    |
| Read Property                |    x    |   x   |     x/Error    |
| Read Property Multiple       |    x    |   x   |     x/Error    |
| Read Range                   |    x    |   x   |     x/Error    |
| Write Property               |    x    |   x   |  Simple/Error  |
| Write Property Multiple      |    x    |   x   |    Simple/x    |
| Write Group                  |    x    |   x   |                |
| Device Communication Control |    x    |   x   |  Simple/Error  |
| Confirmed Private Transfer   |    x    |   x   |       x/x      |
| Unconfirmed Private Transfer |    x    |   x   |                |
| Reinitialize Device          |    x    |   x   |  Simple/Error  |
| Confirmed Text Message       |    x    |   x   |  Simple/Error  |
| Unconfirmed Text Message     |    x    |   x   |                |
| Time Synchronization         |    x    |   x   |                |
| UTC Time Synchronization     |    x    |   x   |                |
| Who-Has                      |    x    |   x   |                |
| I-Have                       |    x    |   x   |                |
| Who-Is                       |    x    |   x   |                |
| I-Am                         |    x    |   x   |                |
| VT Open                      |   N/A   |  N/A  |                |
| VT Close                     |   N/A   |  N/A  |                |
| VT Data                      |   N/A   |  N/A  |                |

## Status of Event Algorithms Implementation

| Event Algorithm            | Implemented |
|----------------------------|-------------|
| Buffer Ready               |     Beta    |
| Change Of Bitstring        |     Beta    |
| Change Of Character String |     Beta    |
| Change Of Life Safety      |     Beta    |
| Change Of State            |     Beta    |
| Change Of Status Flags     |     Beta    |
| Change Of Value            |     Beta    |
| Command Failure            |     Beta    |
| Complex Event Type         |     N/A     |
| Double Out Of Range        |     Beta    |
| Extended                   |     N/A     |
| Floating Limit             |     Beta    |
| Out Of Range               |     Beta    |
| Signed Out Of Range        |     Beta    |
| Unsigned Out Of Range      |     Beta    |
| Unsigned Range             |     Beta    |

## Status of Fault Algorithms Implementation

| Fault Algorithm        | Implemented |
|------------------------|-------------|
| Fault Character String |     Beta    |
| Fault Extended         |     N/A     |
| Fault Life Safety      |     Beta    |
| Fault State            |     Beta    |
| Fault Status Flags     |     Beta    |
