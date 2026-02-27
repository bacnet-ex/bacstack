# bacstack v0.1.0 - API Reference

## Modules

- [BACnet](BACnet.md): BACstack is a low-level Elixir implementation for the ASHRAE standard 135, BACnet - Building Automation and Controller network.
This implementation supports ASHRAE 135-xxxx<!-- TODO --> and BACnet/IPv4. Support for other transport layers (such as BACnet/SC, BACnet/MSTP)
can be straight forward added on top of it.

- Protocol: General
  - [BACnet.Protocol](BACnet.Protocol.md): This module is mostly used for basic decoding of BACnet frames (Protocol Data Units - PDU).
  - [BACnet.Protocol.APDU](BACnet.Protocol.APDU.md): This module provides decoding of Application Data Units (APDU).
Encoding of APDUs are directly handled in the APDU modules.
  - [BACnet.Protocol.APDU.Abort](BACnet.Protocol.APDU.Abort.md): Abort APDUs are used to terminate a transaction between two peers.
  - [BACnet.Protocol.APDU.ComplexACK](BACnet.Protocol.APDU.ComplexACK.md): Complex ACK APDUs are used to convey the information contained
in a positive service response primitive that contains information
in addition to the fact that the service request
was successfully carried out.
  - [BACnet.Protocol.APDU.ConfirmedServiceRequest](BACnet.Protocol.APDU.ConfirmedServiceRequest.md): Confirmed Service Request APDUs are used to convey
the information contained in confirmed service request primitives.
  - [BACnet.Protocol.APDU.Error](BACnet.Protocol.APDU.Error.md): Error APDUs are used to the information contained in a
service response primitive that indicates the reason why
a previous confirmed service request failed,
either in its entirety or only partially.
  - [BACnet.Protocol.APDU.Reject](BACnet.Protocol.APDU.Reject.md): Reject APDUs are used to reject a received confirmed service request
based on syntactical flaws or other protocol errors that prevent
the PDU from being interpreted or the requested service from being provided.
Only confirmed request PDUs may be rejected (see ASHRAE 135 Clause 18.8).
A Reject APDU shall be sent only before the execution of the service.
  - [BACnet.Protocol.APDU.SegmentACK](BACnet.Protocol.APDU.SegmentACK.md): Segment ACK APDUs are used to acknowledge the receipt of one or more frames
containing portions of a segmented message. It may also request the
next segment or segments of the segmented message.
  - [BACnet.Protocol.APDU.SimpleACK](BACnet.Protocol.APDU.SimpleACK.md): Simple ACK APDUs are used to convey the information contained
in a positive service response primitive that contains no other
information except that the service request was successfully carried out.
  - [BACnet.Protocol.APDU.UnconfirmedServiceRequest](BACnet.Protocol.APDU.UnconfirmedServiceRequest.md): Unconfirmed Service Request APDUs are used to convey the information
contained in unconfirmed service request primitives.
  - [BACnet.Protocol.ApplicationTags](BACnet.Protocol.ApplicationTags.md): This module provides application tags encoding and decoding as per ASHRAE 135 chapter 20.2, including constructed tags.
  - [BACnet.Protocol.ApplicationTags.Encoding](BACnet.Protocol.ApplicationTags.Encoding.md): This module should help dealing with application tags encodings in user code, as
application tags encoding can be more easily dealt with as the values can be accessed directly.

  - [BACnet.Protocol.Constants](BACnet.Protocol.Constants.md): BACnet Protocol constants.
  - [BACnet.Protocol.IncompleteAPDU](BACnet.Protocol.IncompleteAPDU.md): This module is used to represent a segmented incomplete APDU.
  - [BACnet.Protocol.NPCI](BACnet.Protocol.NPCI.md): Network Protocol Control Information (NPCI) are used to determine
priority, whether reply is expected, for who by who this frame is
and what kind of BACnet Data Unit this is.
  - [BACnet.Protocol.NetworkLayerProtocolMessage](BACnet.Protocol.NetworkLayerProtocolMessage.md): Network layer messages are used for prividing the basis for
router auto-configuration, router maintenance and
network layer congestion control.
  - [BACnet.Protocol.NpciTarget](BACnet.Protocol.NpciTarget.md): Network Protocol Control Information targets are used to describe
source and destination targets (network and address information) inside
of Network Protocol Control Information (`BACnet.Protocol.NPCI`).

- Protocol: Data Types
  - [BACnet.Protocol.AccessSpecification](BACnet.Protocol.AccessSpecification.md): Represents BACnet Access Specification, used in BACnet `Read-Property-Multiple` and `Write-Property-Multiple`,
as Read Access Specification and Write Access Specification, respectively.

  - [BACnet.Protocol.AccessSpecification.Property](BACnet.Protocol.AccessSpecification.Property.md)
  - [BACnet.Protocol.AccumulatorRecord](BACnet.Protocol.AccumulatorRecord.md)
  - [BACnet.Protocol.ActionCommand](BACnet.Protocol.ActionCommand.md)
  - [BACnet.Protocol.ActionList](BACnet.Protocol.ActionList.md)
  - [BACnet.Protocol.AddressBinding](BACnet.Protocol.AddressBinding.md)
  - [BACnet.Protocol.AlarmSummary](BACnet.Protocol.AlarmSummary.md)
  - [BACnet.Protocol.BACnetArray](BACnet.Protocol.BACnetArray.md): A BACnet Array is a structured datatype in ordered sequences.
A BACnet Array consists of data elements each having the same datatype.
  - [BACnet.Protocol.BACnetDate](BACnet.Protocol.BACnetDate.md): A BACnet Date is used to represent dates, but also can represent unspecific dates,
such as a single component being unspecified (i.e. can match anything in that component),
or can be something like targeting even or odd numbers.
  - [BACnet.Protocol.BACnetDateTime](BACnet.Protocol.BACnetDateTime.md): A BACnet DateTime is used to represent date with timepoints.
It wraps both `BACnetDate` and `BACnetTime`.
  - [BACnet.Protocol.BACnetError](BACnet.Protocol.BACnetError.md)
  - [BACnet.Protocol.BACnetTime](BACnet.Protocol.BACnetTime.md): A BACnet Time is used to represent timepoints of the day, but also can represent
unspecific timepoints, such as a single component being unspecified
(i.e. can match anything in that component).
  - [BACnet.Protocol.BACnetTimestamp](BACnet.Protocol.BACnetTimestamp.md)
  - [BACnet.Protocol.CalendarEntry](BACnet.Protocol.CalendarEntry.md)
  - [BACnet.Protocol.CovSubscription](BACnet.Protocol.CovSubscription.md)
  - [BACnet.Protocol.DailySchedule](BACnet.Protocol.DailySchedule.md)
  - [BACnet.Protocol.DateRange](BACnet.Protocol.DateRange.md)
  - [BACnet.Protocol.DaysOfWeek](BACnet.Protocol.DaysOfWeek.md)
  - [BACnet.Protocol.Destination](BACnet.Protocol.Destination.md)
  - [BACnet.Protocol.DeviceObjectPropertyRef](BACnet.Protocol.DeviceObjectPropertyRef.md)
  - [BACnet.Protocol.DeviceObjectRef](BACnet.Protocol.DeviceObjectRef.md)
  - [BACnet.Protocol.EnrollmentSummary](BACnet.Protocol.EnrollmentSummary.md)
  - [BACnet.Protocol.EventInformation](BACnet.Protocol.EventInformation.md)
  - [BACnet.Protocol.EventLogRecord](BACnet.Protocol.EventLogRecord.md)
  - [BACnet.Protocol.EventMessageTexts](BACnet.Protocol.EventMessageTexts.md)
  - [BACnet.Protocol.EventTimestamps](BACnet.Protocol.EventTimestamps.md)
  - [BACnet.Protocol.EventTransitionBits](BACnet.Protocol.EventTransitionBits.md)
  - [BACnet.Protocol.GroupChannelValue](BACnet.Protocol.GroupChannelValue.md)
  - [BACnet.Protocol.LimitEnable](BACnet.Protocol.LimitEnable.md): BACnet Limit Enable conveys several flags that describe the enabled limit detection algorithms.
  - [BACnet.Protocol.LogMultipleRecord](BACnet.Protocol.LogMultipleRecord.md)
  - [BACnet.Protocol.LogRecord](BACnet.Protocol.LogRecord.md)
  - [BACnet.Protocol.LogStatus](BACnet.Protocol.LogStatus.md)
  - [BACnet.Protocol.NotificationClassPriority](BACnet.Protocol.NotificationClassPriority.md): The notification class priority BACnet array is used to convey the priority
used for event notifications. A lower number indicates a higher priority.

  - [BACnet.Protocol.ObjectIdentifier](BACnet.Protocol.ObjectIdentifier.md)
  - [BACnet.Protocol.ObjectPropertyRef](BACnet.Protocol.ObjectPropertyRef.md)
  - [BACnet.Protocol.Prescale](BACnet.Protocol.Prescale.md)
  - [BACnet.Protocol.PriorityArray](BACnet.Protocol.PriorityArray.md): The Priority Array is a BACnet means of ensuring Command Prioritization.
The Priority Array is an array (or in this case a struct) that contains 16 levels of priority,
each which can take a particular value (each priority must have the same type) or NULL (`nil`).
The highest priority (lowest array index) with a non-NULL value is the active command.
  - [BACnet.Protocol.PropertyRef](BACnet.Protocol.PropertyRef.md)
  - [BACnet.Protocol.PropertyState](BACnet.Protocol.PropertyState.md)
  - [BACnet.Protocol.PropertyValue](BACnet.Protocol.PropertyValue.md)
  - [BACnet.Protocol.ReadAccessResult](BACnet.Protocol.ReadAccessResult.md): Represents BACnet Read Access Result, used in BACnet `Read-Property-Multiple`.

  - [BACnet.Protocol.ReadAccessResult.ReadResult](BACnet.Protocol.ReadAccessResult.ReadResult.md)
  - [BACnet.Protocol.Recipient](BACnet.Protocol.Recipient.md)
  - [BACnet.Protocol.RecipientAddress](BACnet.Protocol.RecipientAddress.md)
  - [BACnet.Protocol.ResultFlags](BACnet.Protocol.ResultFlags.md): BACnet Result Flags conveys several flags that describe characteristics of the response data.
  - [BACnet.Protocol.SetpointReference](BACnet.Protocol.SetpointReference.md)
  - [BACnet.Protocol.SpecialEvent](BACnet.Protocol.SpecialEvent.md)
  - [BACnet.Protocol.StatusFlags](BACnet.Protocol.StatusFlags.md)
  - [BACnet.Protocol.TimeValue](BACnet.Protocol.TimeValue.md)
  - [BACnet.Protocol.WeekNDay](BACnet.Protocol.WeekNDay.md)

- Protocol: Objects
  - [BACnet.Protocol.Device.ObjectTypesSupported](BACnet.Protocol.Device.ObjectTypesSupported.md): BACnet object types need to be supported by the device, in order for a BACnet client
to be able to handle them.
  - [BACnet.Protocol.Device.ServicesSupported](BACnet.Protocol.Device.ServicesSupported.md): BACnet Services need to be supported by the device, in order for a BACnet client
to be able to invoke them.
  - [BACnet.Protocol.ObjectsUtility](BACnet.Protocol.ObjectsUtility.md): This module offers utility functions that work on all object types.
  - [BACnet.Protocol.ObjectTypes.Accumulator](BACnet.Protocol.ObjectTypes.Accumulator.md): The Accumulator object type defines a standardized object whose properties
represent the externally visible characteristics of a device that indicates
measurements made by counting pulses.
  - [BACnet.Protocol.ObjectTypes.AnalogInput](BACnet.Protocol.ObjectTypes.AnalogInput.md): The Analog Input object type defines a standardized object whose properties represent
the externally visible characteristics of an analog input.
  - [BACnet.Protocol.ObjectTypes.AnalogOutput](BACnet.Protocol.ObjectTypes.AnalogOutput.md): The Analog Output object type defines a standardized object whose properties represent
the externally visible characteristics of an analog output.
  - [BACnet.Protocol.ObjectTypes.AnalogValue](BACnet.Protocol.ObjectTypes.AnalogValue.md): The Analog Value object type defines a standardized object whose properties represent
the externally visible characteristics of an analog value.
An "analog value" is a control system parameter residing in the memory of the BACnet Device.
  - [BACnet.Protocol.ObjectTypes.Averaging](BACnet.Protocol.ObjectTypes.Averaging.md): The Averaging object type defines a standardized object whose properties represent
the externally visible characteristics of a value that is sampled periodically over
a specified time interval. The Averaging object records the minimum, maximum and
average value over the interval, and makes these values visible as properties of
the Averaging object. The sampled value may be the value of any BOOLEAN, INTEGER,
Unsigned, Enumerated or REAL property value of any object within the BACnet
Device in which the object resides. Optionally, the object property to be sampled
may exist in a different BACnet Device.
  - [BACnet.Protocol.ObjectTypes.BinaryInput](BACnet.Protocol.ObjectTypes.BinaryInput.md): The Binary Input object type defines a standardized object whose properties represent
the externally visible characteristics of a binary input.
A "binary input" is a physical device or hardware input that can be in only one of two distinct states.
In this description, those states are referred to as ACTIVE (`true`) and INACTIVE (`false`).
A typical use of a binary input is to indicate whether a particular piece of mechanical equipment,
such as a fan or pump, is running or idle.
  - [BACnet.Protocol.ObjectTypes.BinaryOutput](BACnet.Protocol.ObjectTypes.BinaryOutput.md): The Binary Output object type defines a standardized object whose properties represent
the externally visible characteristics of a binary output.
A "binary output" is a physical device or hardware output that can be in only one of two distinct states.
In this description, those states are referred to as ACTIVE (`true`) and INACTIVE (`false`).
A typical use of a binary output is to switch a particular piece of mechanical equipment,
such as a fan or pump, on or off. The state ACTIVE corresponds to the situation when the
equipment is on or running, and INACTIVE corresponds to the situation when the equipment is off or idle.
  - [BACnet.Protocol.ObjectTypes.BinaryValue](BACnet.Protocol.ObjectTypes.BinaryValue.md): The Binary Value object type defines a standardized object whose properties represent
the externally visible characteristics of a binary value.
A "binary value" is a control system parameter residing in the memory of the BACnet Device.
This parameter may assume only one of two distinct states.
In this description, those states are referred to as ACTIVE and INACTIVE.
  - [BACnet.Protocol.ObjectTypes.BitstringValue](BACnet.Protocol.ObjectTypes.BitstringValue.md): The Bitstring Value object type defines a standardized object whose properties
represent the externally visible characteristics of a named data value
in a BACnet device. A BACnet device can use a Bitstring Value object to make
any kind of bitstring data value accessible to other BACnet devices.
The mechanisms by which the value is derived are not visible to the BACnet
client.
  - [BACnet.Protocol.ObjectTypes.Calendar](BACnet.Protocol.ObjectTypes.Calendar.md): The Calendar object type defines a standardized object used to describe
a list of calendar dates, which might be thought of as "holidays", "special events",
or simply as a list of dates.
  - [BACnet.Protocol.ObjectTypes.CharacterStringValue](BACnet.Protocol.ObjectTypes.CharacterStringValue.md): The CharacterString Value object type defines a standardized object whose properties
represent the externally visible characteristics of a named data value in a BACnet device.
A BACnet device can use a CharacterString Value object to make any kind of character
string data value accessible to other BACnet devices. The mechanisms by which the
value is derived are not visible to the BACnet client.
  - [BACnet.Protocol.ObjectTypes.Command](BACnet.Protocol.ObjectTypes.Command.md): The Command object type defines a standardized object whose properties represent
the externally visible characteristics of a multi-action command procedure.
A Command object is used to write a set of values to a group of object properties,
based on the "action code" that is written to the Present_Value of the Command object.
Whenever the Present_Value property of the Command object is written to,
it triggers the Command object to take a set of actions that change the values of
a set of other objects' properties.
  - [BACnet.Protocol.ObjectTypes.DatePatternValue](BACnet.Protocol.ObjectTypes.DatePatternValue.md): The Date Pattern Value object type defines a standardized object whose properties
represent the externally visible characteristics of a named data value in a BACnet device.
A BACnet device can use a Date Pattern Value object to make any kind of date data
value accessible to other BACnet devices. The mechanisms by which the value is derived
are not visible to the BACnet client.
  - [BACnet.Protocol.ObjectTypes.DateTimePatternValue](BACnet.Protocol.ObjectTypes.DateTimePatternValue.md): The DateTime Pattern Value object type defines a standardized object whose properties
represent the externally visible characteristics of a named data value in a BACnet device.
A BACnet device can use a DateTime Pattern Value object to make any kind of datetime data
value accessible to other BACnet devices. The mechanisms by which the value is derived are
not visible to the BACnet client.
  - [BACnet.Protocol.ObjectTypes.DateTimeValue](BACnet.Protocol.ObjectTypes.DateTimeValue.md): The DateTime Value object type defines a standardized object whose properties represent
the externally visible characteristics of a named data value in a BACnet device.
A BACnet device can use a DateTime Value object to make any kind of datetime data value
accessible to other BACnet devices. The mechanisms by which the value is derived are not
visible to the BACnet client. A DateTime Value object is used to represent a
single moment in time. In contrast, the DateTime Pattern Value object can be used to
represent multiple recurring dates and times.
  - [BACnet.Protocol.ObjectTypes.DateValue](BACnet.Protocol.ObjectTypes.DateValue.md): The Date Value object type defines a standardized object whose properties represent
the externally visible characteristics of a named data value in a BACnet device.
A BACnet device can use a Date Value object to make any kind of date data value
accessible to other BACnet devices. The mechanisms by which the value is derived
are not visible to the BACnet client.
A Date Value object is used to represent a single day. In contrast,
the Date Pattern Value object can be used to represent multiple recurring dates.
  - [BACnet.Protocol.ObjectTypes.Device](BACnet.Protocol.ObjectTypes.Device.md): The Device object type defines a standardized object whose properties represent
the externally visible characteristics of a BACnet Device.
There shall be exactly one Device object in each BACnet Device.
A Device object is referenced by its Object_Identifier property,
which is not only unique to the BACnet Device that maintains this object
but is also unique throughout the BACnet internetwork.
  - [BACnet.Protocol.ObjectTypes.EventEnrollment](BACnet.Protocol.ObjectTypes.EventEnrollment.md): The Event Enrollment object type defines a standardized object that represents
and contains the information required for algorithmic reporting of events.
For the general event concepts and algorithmic event reporting, see Clause 13.2.
  - [BACnet.Protocol.ObjectTypes.EventLog](BACnet.Protocol.ObjectTypes.EventLog.md): An Event Log object records event notifications with timestamps and other
pertinent data in an internal buffer for subsequent retrieval.
Each timestamped buffer entry is called an event log "record".
  - [BACnet.Protocol.ObjectTypes.File](BACnet.Protocol.ObjectTypes.File.md): The File object type defines a standardized object that is used
to describe properties of data files that may be accessed using
File Services (see Clause 14).
  - [BACnet.Protocol.ObjectTypes.Group](BACnet.Protocol.ObjectTypes.Group.md): The Group object type defines a standardized object whose properties
represent a collection of other objects and one or more of their properties.
A group object is used to simplify the exchange of information between
BACnet Devices by providing a shorthand way to specify all members of the
group at once. A group may be formed using any combination of object types.
  - [BACnet.Protocol.ObjectTypes.IntegerValue](BACnet.Protocol.ObjectTypes.IntegerValue.md): The Integer Value object type defines a standardized object whose properties represent
the externally visible characteristics of a named data value in a BACnet device.
A BACnet device can use an Integer Value object to make any kind of signed integer data
value accessible to other BACnet devices.
The mechanisms by which the value is derived are not visible to the BACnet client.
  - [BACnet.Protocol.ObjectTypes.LargeAnalogValue](BACnet.Protocol.ObjectTypes.LargeAnalogValue.md): The Large Analog Value object type defines a standardized object whose properties represent
the externally visible characteristics of a named data value in a BACnet device.
A BACnet device can use a Large Analog Value object to make any kind of
double-precision data value accessible to other BACnet devices. The mechanisms by
which the value is derived are not visible to the BACnet client.
  - [BACnet.Protocol.ObjectTypes.Loop](BACnet.Protocol.ObjectTypes.Loop.md): The Loop object type defines a standardized object whose properties represent
the externally visible characteristics of any form of feedback control loop.
Flexibility is achieved by providing three independent gain constants with
no assumed values for units. The appropriate gain units are determined by
the details of the control algorithm, which is a local matter.
  - [BACnet.Protocol.ObjectTypes.MultistateInput](BACnet.Protocol.ObjectTypes.MultistateInput.md): The Multi-state Input object type defines a standardized object whose Present_Value
represents the result of an algorithmic process within the BACnet Device in which
the object resides.
  - [BACnet.Protocol.ObjectTypes.MultistateOutput](BACnet.Protocol.ObjectTypes.MultistateOutput.md): The Multi-state Output object type defines a standardized object whose properties
represent the desired state of one or more physical outputs or processes within
the BACnet Device in which the object resides.
  - [BACnet.Protocol.ObjectTypes.MultistateValue](BACnet.Protocol.ObjectTypes.MultistateValue.md): The Multi-state Value object type defines a standardized object whose properties
represent the externally visible characteristics of a multi-state value.
A "multi-state value" is a control system parameter residing in the memory of the
BACnet Device. The actual functions associated with a specific state are a
local matter and not specified by the protocol. For example, a particular state may
represent the active/inactive condition of several physical inputs and outputs or
perhaps the value of an analog input or output.
The Present_Value property is an unsigned integer number representing the state.
The State_Text property associates a description with each state.
  - [BACnet.Protocol.ObjectTypes.NotificationClass](BACnet.Protocol.ObjectTypes.NotificationClass.md): The Notification Class object type defines a standardized object that represents
and contains information required for the distribution of event notifications
within BACnet systems. Notification Classes are useful for event-initiating objects
that have identical needs in terms of how their notifications should be handled,
what the destination(s) for their notifications should be, and how they should
be acknowledged. A notification class defines how event notifications shall be
prioritized in their handling according to TO_OFFNORMAL, TO_FAULT, and TO_NORMAL events;
whether these categories of events require acknowledgment (nearly always by a
human operator); and what destination devices or processes should receive notifications.
  - [BACnet.Protocol.ObjectTypes.OctetStringValue](BACnet.Protocol.ObjectTypes.OctetStringValue.md): The OctetString Value object type defines a standardized object whose properties
represent the externally visible characteristics of a named data value in a
BACnet device.
A BACnet device can use an OctetString Value object to make any kind of
OCTET STRING data value accessible to other BACnet devices.
The mechanisms by which the value is derived are not visible to the BACnet client.
  - [BACnet.Protocol.ObjectTypes.PositiveIntegerValue](BACnet.Protocol.ObjectTypes.PositiveIntegerValue.md): The Integer Value object type defines a standardized object whose properties represent
the externally visible characteristics of a named data value in a BACnet device.
A BACnet device can use a Positive Integer Value object to make any kind of unsigned
integer data value accessible to other BACnet devices.
The mechanisms by which the value is derived are not visible to the BACnet client.
  - [BACnet.Protocol.ObjectTypes.Program](BACnet.Protocol.ObjectTypes.Program.md): The Program object type defines a standardized object whose properties represent
the externally visible characteristics of an application program. In this context,
an application program is an abstract representation of a process within a BACnet
Device, which is executing a particular body of instructions that act upon a particular
collection of data structures. The logic that is embodied in these instructions and
the form and content of these data structures are local matters. The Program object
provides a network-visible view of selected parameters of an application program
in the form of properties of the Program object. Some of these properties are
specified in the standard and exhibit a consistent behavior across different
BACnet Devices. The operating state of the process that executes the application
program may be viewed and controlled through these standardized properties,
which are required for all Program objects. In addition to these standardized
properties, a Program object may also provide vendor-specific properties.
These vendor-specific properties may serve as inputs to the program, outputs from
the program, or both. However, these vendor-specific properties may not be present at all.
  - [BACnet.Protocol.ObjectTypes.PulseConverter](BACnet.Protocol.ObjectTypes.PulseConverter.md): The Pulse Converter object type defines a standardized object that represents
a process whereby ongoing measurements made of some quantity, such as
electric power or water or natural gas usage, and represented by pulses or counts,
might be monitored over some time interval for applications such as
peak load management, where it is necessary to make periodic measurements
but where a precise accounting of every input pulse or count is not required.
The Pulse Converter object might represent a physical input. As an alternative,
it might acquire the data from the Present_Value of an Accumulator object,
representing an input in the same device as the Pulse Converter object.
This linkage is illustrated by the dotted line in Figure 12-4. Every time the
Present_Value property of the Accumulator object is incremented, the Count property
of the Pulse Converter object is also incremented.
The Present_Value property of the Pulse Converter object can be adjusted at any time
by writing to the Adjust_Value property, which causes the Count property to be adjusted,
and the Present_Value recomputed from Count. In the illustration in Figure 12-4,
the Count property of the Pulse Converter was adjusted down to 0 when the Total_Count
of the Accumulator object had the value 0070.
  - [BACnet.Protocol.ObjectTypes.Schedule](BACnet.Protocol.ObjectTypes.Schedule.md): The Schedule object type defines a standardized object used to describe a periodic schedule
that may recur during a range of dates, with optional exceptions at arbitrary times on
arbitrary dates. The Schedule object also serves as a binding between these scheduled times
and the writing of specified "values" to specific properties of specific objects at those times.
  - [BACnet.Protocol.ObjectTypes.StructuredView](BACnet.Protocol.ObjectTypes.StructuredView.md): The Structured View object type defines a standardized object that provides
a container to hold references to subordinate objects, which may include other
Structured View objects, thereby allowing multilevel hierarchies to be created.
  - [BACnet.Protocol.ObjectTypes.TimePatternValue](BACnet.Protocol.ObjectTypes.TimePatternValue.md): The Time Pattern Value object type defines a standardized object whose properties
represent the externally visible characteristics of a named data value in a BACnet device.
A BACnet device can use a Time Pattern Value object to make any kind of time data value
accessible to other BACnet devices. The mechanisms by which the value is derived are not
visible to the BACnet client.
  - [BACnet.Protocol.ObjectTypes.TimeValue](BACnet.Protocol.ObjectTypes.TimeValue.md): The Time Value object type defines a standardized object whose properties represent
the externally visible characteristics of a named data value in a BACnet device.
A BACnet device can use a Time Value object to make any kind of time data value
accessible to other BACnet devices. The mechanisms by which the value is derived
are not visible to the BACnet client.
A Time Value object is used to represent a single moment in time. In contrast,
the Time Pattern Value object can be used to represent multiple recurring times.
  - [BACnet.Protocol.ObjectTypes.TrendLog](BACnet.Protocol.ObjectTypes.TrendLog.md): A Trend Log object monitors a property of a referenced object and,
when predefined conditionsare met, saves ("logs") the value of the property
and a timestamp in an internal buffer for subsequent retrieval.
The data may be logged periodically, upon a change of value or
when "triggered" by a write to the Trigger property.
The Trigger property allows the acquisition of samples to be controlled by
network write operations or internal processes. Errors that prevent the acquisition
of the data, as well as changes in the status or operation of the logging process itself,
are also recorded. Each timestamped buffer entry is called a trend log "record."
  - [BACnet.Protocol.ObjectTypes.TrendLogMultiple](BACnet.Protocol.ObjectTypes.TrendLogMultiple.md): A Trend Log Multiple object monitors one or more properties of one or more
referenced objects, either in the same device as the Trend Log Multiple object
or in an external device. When predefined conditions are met,
the object saves ("logs") the value of the properties and a timestamp into
an internal buffer for subsequent retrieval. The data may be logged periodically
or when "triggered" by a write to the Trigger property. Errors that prevent the
acquisition of the data, as well as changes in the status or operation of the
logging process itself, are also recorded. Each timestamped buffer entry is
called a "log record". The Log_DeviceObjectProperty array holds the list of
properties to be monitored and logged. If an element of the
Log_DeviceObjectProperty array has an object or device instance number equal to 4194303,
this indicates that the element is 'empty' or 'uninitialized'.
For empty or uninitialized elements, an indication that no property was specified
shall be written to the corresponding entry in each log record.

- Protocol: Services
  - [BACnet.Protocol.Services.AcknowledgeAlarm](BACnet.Protocol.Services.AcknowledgeAlarm.md): This module represents the BACnet Acknowledge Alarm service.
  - [BACnet.Protocol.Services.AddListElement](BACnet.Protocol.Services.AddListElement.md): This module represents the BACnet Add List Element service.
  - [BACnet.Protocol.Services.AtomicReadFile](BACnet.Protocol.Services.AtomicReadFile.md): This module represents the BACnet Atomic Read File service.
  - [BACnet.Protocol.Services.AtomicWriteFile](BACnet.Protocol.Services.AtomicWriteFile.md): This module represents the BACnet Atomic Write File service.
  - [BACnet.Protocol.Services.ConfirmedCovNotification](BACnet.Protocol.Services.ConfirmedCovNotification.md): This module represents the BACnet Confirmed COV Notification service.
  - [BACnet.Protocol.Services.ConfirmedEventNotification](BACnet.Protocol.Services.ConfirmedEventNotification.md): This module represents the BACnet Confirmed Event Notification service.
  - [BACnet.Protocol.Services.ConfirmedPrivateTransfer](BACnet.Protocol.Services.ConfirmedPrivateTransfer.md): This module represents the BACnet Confirmed Private Transfer service.
  - [BACnet.Protocol.Services.ConfirmedTextMessage](BACnet.Protocol.Services.ConfirmedTextMessage.md): This module represents the BACnet Confirmed Text Message service.
  - [BACnet.Protocol.Services.CreateObject](BACnet.Protocol.Services.CreateObject.md): This module represents the BACnet Create Object service.
  - [BACnet.Protocol.Services.DeleteObject](BACnet.Protocol.Services.DeleteObject.md): This module represents the BACnet Delete Object service.
  - [BACnet.Protocol.Services.DeviceCommunicationControl](BACnet.Protocol.Services.DeviceCommunicationControl.md): This module represents the BACnet Device Communication Control service.
  - [BACnet.Protocol.Services.GetAlarmSummary](BACnet.Protocol.Services.GetAlarmSummary.md): This module represents the BACnet Get Alarm Summary service.
  - [BACnet.Protocol.Services.GetEnrollmentSummary](BACnet.Protocol.Services.GetEnrollmentSummary.md): This module represents the BACnet Get Enrollment Summary service.
  - [BACnet.Protocol.Services.GetEventInformation](BACnet.Protocol.Services.GetEventInformation.md): This module represents the BACnet Get Event Information service.
  - [BACnet.Protocol.Services.IAm](BACnet.Protocol.Services.IAm.md): This module represents the BACnet I-Am service.
  - [BACnet.Protocol.Services.IHave](BACnet.Protocol.Services.IHave.md): This module represents the BACnet I-Have service.
  - [BACnet.Protocol.Services.LifeSafetyOperation](BACnet.Protocol.Services.LifeSafetyOperation.md): This module represents the BACnet Life Safety Operation service.
  - [BACnet.Protocol.Services.ReadProperty](BACnet.Protocol.Services.ReadProperty.md): This module represents the BACnet Read Property service.
  - [BACnet.Protocol.Services.ReadPropertyMultiple](BACnet.Protocol.Services.ReadPropertyMultiple.md): This module represents the BACnet Read Property Multiple service.
  - [BACnet.Protocol.Services.ReadRange](BACnet.Protocol.Services.ReadRange.md): This module represents the BACnet Read Range service.
  - [BACnet.Protocol.Services.ReinitializeDevice](BACnet.Protocol.Services.ReinitializeDevice.md): This module represents the BACnet Reinitialize Device service.
  - [BACnet.Protocol.Services.RemoveListElement](BACnet.Protocol.Services.RemoveListElement.md): This module represents the BACnet Remove List Element service.
  - [BACnet.Protocol.Services.SubscribeCov](BACnet.Protocol.Services.SubscribeCov.md): This module represents the BACnet Subscribe COV service.
  - [BACnet.Protocol.Services.SubscribeCovProperty](BACnet.Protocol.Services.SubscribeCovProperty.md): This module represents the BACnet Subscribe COV Property service.
  - [BACnet.Protocol.Services.TimeSynchronization](BACnet.Protocol.Services.TimeSynchronization.md): This module represents the BACnet Time Synchronization service.
  - [BACnet.Protocol.Services.UnconfirmedCovNotification](BACnet.Protocol.Services.UnconfirmedCovNotification.md): This module represents the BACnet Unconfirmed COV Notification service (Change Of Value).
  - [BACnet.Protocol.Services.UnconfirmedEventNotification](BACnet.Protocol.Services.UnconfirmedEventNotification.md): This module represents the BACnet Unconfirmed Event Notification service.
  - [BACnet.Protocol.Services.UnconfirmedPrivateTransfer](BACnet.Protocol.Services.UnconfirmedPrivateTransfer.md): This module represents the BACnet Unconfirmed Private Transfer service.
  - [BACnet.Protocol.Services.UnconfirmedTextMessage](BACnet.Protocol.Services.UnconfirmedTextMessage.md): This module represents the BACnet Unconfirmed Text Message service.
  - [BACnet.Protocol.Services.UtcTimeSynchronization](BACnet.Protocol.Services.UtcTimeSynchronization.md): This module represents the BACnet UTC Time Synchronization service.
  - [BACnet.Protocol.Services.WhoHas](BACnet.Protocol.Services.WhoHas.md): This module represents the BACnet Who-Has service.
  - [BACnet.Protocol.Services.WhoIs](BACnet.Protocol.Services.WhoIs.md): This module represents the BACnet Who-Is service.
  - [BACnet.Protocol.Services.WriteGroup](BACnet.Protocol.Services.WriteGroup.md): This module represents the BACnet Write Group service.
  - [BACnet.Protocol.Services.WriteProperty](BACnet.Protocol.Services.WriteProperty.md): This module represents the BACnet Write Property service.
  - [BACnet.Protocol.Services.WritePropertyMultiple](BACnet.Protocol.Services.WritePropertyMultiple.md): This module represents the BACnet Write Property Multiple service.
  - [BACnet.Protocol.Services.Ack.AtomicReadFileAck](BACnet.Protocol.Services.Ack.AtomicReadFileAck.md)
  - [BACnet.Protocol.Services.Ack.AtomicWriteFileAck](BACnet.Protocol.Services.Ack.AtomicWriteFileAck.md)
  - [BACnet.Protocol.Services.Ack.ConfirmedPrivateTransferAck](BACnet.Protocol.Services.Ack.ConfirmedPrivateTransferAck.md)
  - [BACnet.Protocol.Services.Ack.CreateObjectAck](BACnet.Protocol.Services.Ack.CreateObjectAck.md)
  - [BACnet.Protocol.Services.Ack.GetAlarmSummaryAck](BACnet.Protocol.Services.Ack.GetAlarmSummaryAck.md)
  - [BACnet.Protocol.Services.Ack.GetEnrollmentSummaryAck](BACnet.Protocol.Services.Ack.GetEnrollmentSummaryAck.md)
  - [BACnet.Protocol.Services.Ack.GetEventInformationAck](BACnet.Protocol.Services.Ack.GetEventInformationAck.md)
  - [BACnet.Protocol.Services.Ack.ReadPropertyAck](BACnet.Protocol.Services.Ack.ReadPropertyAck.md)
  - [BACnet.Protocol.Services.Ack.ReadPropertyMultipleAck](BACnet.Protocol.Services.Ack.ReadPropertyMultipleAck.md)
  - [BACnet.Protocol.Services.Ack.ReadRangeAck](BACnet.Protocol.Services.Ack.ReadRangeAck.md)
  - [BACnet.Protocol.Services.Error.AddListElementError](BACnet.Protocol.Services.Error.AddListElementError.md)
  - [BACnet.Protocol.Services.Error.ConfirmedPrivateTransferError](BACnet.Protocol.Services.Error.ConfirmedPrivateTransferError.md)
  - [BACnet.Protocol.Services.Error.CreateObjectError](BACnet.Protocol.Services.Error.CreateObjectError.md)
  - [BACnet.Protocol.Services.Error.DeleteObjectError](BACnet.Protocol.Services.Error.DeleteObjectError.md)
  - [BACnet.Protocol.Services.Error.RemoveListElementError](BACnet.Protocol.Services.Error.RemoveListElementError.md)
  - [BACnet.Protocol.Services.Error.WritePropertyMultipleError](BACnet.Protocol.Services.Error.WritePropertyMultipleError.md)

- Protocol: Alarm &amp; Event Subscription
  - [BACnet.Protocol.EventAlgorithms](BACnet.Protocol.EventAlgorithms.md): BACnet has various different types of event algorithms.
Each of them is implemented by a different module.
  - [BACnet.Protocol.EventParameters](BACnet.Protocol.EventParameters.md): BACnet has various different types of event parameters.
Each of them is represented by a different module.
  - [BACnet.Protocol.FaultAlgorithms](BACnet.Protocol.FaultAlgorithms.md): BACnet has various different types of fault algorithms.
Each of them is implemented by a different module.
  - [BACnet.Protocol.FaultParameters](BACnet.Protocol.FaultParameters.md): BACnet has various different types of fault parameters.
Each of them is represented by a different module.
  - [BACnet.Protocol.NotificationParameters](BACnet.Protocol.NotificationParameters.md): BACnet has various different types of notification parameters.
Each of them is represented by a different module.
  - [BACnet.Protocol.EventAlgorithms.BufferReady](BACnet.Protocol.EventAlgorithms.BufferReady.md): Implements the BACnet event algorithm `BufferReady`.
  - [BACnet.Protocol.EventAlgorithms.ChangeOfBitstring](BACnet.Protocol.EventAlgorithms.ChangeOfBitstring.md): Implements the BACnet event algorithm `ChangeOfBitstring`.
  - [BACnet.Protocol.EventAlgorithms.ChangeOfCharacterString](BACnet.Protocol.EventAlgorithms.ChangeOfCharacterString.md): Implements the BACnet event algorithm `ChangeOfCharacterString`.
  - [BACnet.Protocol.EventAlgorithms.ChangeOfLifeSafety](BACnet.Protocol.EventAlgorithms.ChangeOfLifeSafety.md): Implements the BACnet event algorithm `ChangeOfLifeSafety`.
  - [BACnet.Protocol.EventAlgorithms.ChangeOfState](BACnet.Protocol.EventAlgorithms.ChangeOfState.md): Implements the BACnet event algorithm `ChangeOfState`.
  - [BACnet.Protocol.EventAlgorithms.ChangeOfStatusFlags](BACnet.Protocol.EventAlgorithms.ChangeOfStatusFlags.md): Implements the BACnet event algorithm `ChangeOfStatusFlags`.
  - [BACnet.Protocol.EventAlgorithms.ChangeOfValue](BACnet.Protocol.EventAlgorithms.ChangeOfValue.md): Implements the BACnet event algorithm `ChangeOfValue`.
  - [BACnet.Protocol.EventAlgorithms.CommandFailure](BACnet.Protocol.EventAlgorithms.CommandFailure.md): Implements the BACnet event algorithm `CommandFailure`.
  - [BACnet.Protocol.EventAlgorithms.ComplexEventType](BACnet.Protocol.EventAlgorithms.ComplexEventType.md): Implements the BACnet event algorithm `ComplexEventType`.
  - [BACnet.Protocol.EventAlgorithms.DoubleOutOfRange](BACnet.Protocol.EventAlgorithms.DoubleOutOfRange.md): Implements the BACnet event algorithm `DoubleOutOfRange`.
  - [BACnet.Protocol.EventAlgorithms.Extended](BACnet.Protocol.EventAlgorithms.Extended.md): Implements the BACnet event algorithm `Extended`.
  - [BACnet.Protocol.EventAlgorithms.FloatingLimit](BACnet.Protocol.EventAlgorithms.FloatingLimit.md): Implements the BACnet event algorithm `FloatingLimit`.
  - [BACnet.Protocol.EventAlgorithms.OutOfRange](BACnet.Protocol.EventAlgorithms.OutOfRange.md): Implements the BACnet event algorithm `OutOfRange`.
  - [BACnet.Protocol.EventAlgorithms.SignedOutOfRange](BACnet.Protocol.EventAlgorithms.SignedOutOfRange.md): Implements the BACnet event algorithm `SignedOutOfRange`.
  - [BACnet.Protocol.EventAlgorithms.UnsignedOutOfRange](BACnet.Protocol.EventAlgorithms.UnsignedOutOfRange.md): Implements the BACnet event algorithm `UnsignedOutOfRange`.
  - [BACnet.Protocol.EventAlgorithms.UnsignedRange](BACnet.Protocol.EventAlgorithms.UnsignedRange.md): Implements the BACnet event algorithm `UnsignedRange`.
  - [BACnet.Protocol.EventParameters.BufferReady](BACnet.Protocol.EventParameters.BufferReady.md): Represents the BACnet event algorithm `BufferReady` parameters.
  - [BACnet.Protocol.EventParameters.ChangeOfBitstring](BACnet.Protocol.EventParameters.ChangeOfBitstring.md): Represents the BACnet event algorithm `ChangeOfBitstring` parameters.
  - [BACnet.Protocol.EventParameters.ChangeOfCharacterString](BACnet.Protocol.EventParameters.ChangeOfCharacterString.md): Represents the BACnet event algorithm `ChangeOfCharacterString` parameters.
  - [BACnet.Protocol.EventParameters.ChangeOfLifeSafety](BACnet.Protocol.EventParameters.ChangeOfLifeSafety.md): Represents the BACnet event algorithm `ChangeOfLifeSafety` parameters.
  - [BACnet.Protocol.EventParameters.ChangeOfState](BACnet.Protocol.EventParameters.ChangeOfState.md): Represents the BACnet event algorithm `ChangeOfState` parameters.
  - [BACnet.Protocol.EventParameters.ChangeOfStatusFlags](BACnet.Protocol.EventParameters.ChangeOfStatusFlags.md): Represents the BACnet event algorithm `ChangeOfStatusFlags` parameters.
  - [BACnet.Protocol.EventParameters.ChangeOfValue](BACnet.Protocol.EventParameters.ChangeOfValue.md): Represents the BACnet event algorithm `ChangeOfValue` parameters.
  - [BACnet.Protocol.EventParameters.CommandFailure](BACnet.Protocol.EventParameters.CommandFailure.md): Represents the BACnet event algorithm `CommandFailure` parameters.
  - [BACnet.Protocol.EventParameters.DoubleOutOfRange](BACnet.Protocol.EventParameters.DoubleOutOfRange.md): Represents the BACnet event algorithm `DoubleOutOfRange` parameters.
  - [BACnet.Protocol.EventParameters.Extended](BACnet.Protocol.EventParameters.Extended.md): Represents the BACnet event algorithm `Extended` parameters.
  - [BACnet.Protocol.EventParameters.FloatingLimit](BACnet.Protocol.EventParameters.FloatingLimit.md): Represents the BACnet event algorithm `FloatingLimit` parameters.
  - [BACnet.Protocol.EventParameters.None](BACnet.Protocol.EventParameters.None.md): Represents the BACnet event algorithm `None` parameters.
  - [BACnet.Protocol.EventParameters.OutOfRange](BACnet.Protocol.EventParameters.OutOfRange.md): Represents the BACnet event algorithm `OutOfRange` parameters.
  - [BACnet.Protocol.EventParameters.SignedOutOfRange](BACnet.Protocol.EventParameters.SignedOutOfRange.md): Represents the BACnet event algorithm `SignedOutOfRange` parameters.
  - [BACnet.Protocol.EventParameters.UnsignedOutOfRange](BACnet.Protocol.EventParameters.UnsignedOutOfRange.md): Represents the BACnet event algorithm `UnsignedOutOfRange` parameters.
  - [BACnet.Protocol.EventParameters.UnsignedRange](BACnet.Protocol.EventParameters.UnsignedRange.md): Represents the BACnet event algorithm `UnsignedRange` parameters.
  - [BACnet.Protocol.FaultAlgorithms.FaultCharacterString](BACnet.Protocol.FaultAlgorithms.FaultCharacterString.md): Represents the BACnet fault algorithm `FaultCharacterString`.
  - [BACnet.Protocol.FaultAlgorithms.FaultExtended](BACnet.Protocol.FaultAlgorithms.FaultExtended.md): Represents the BACnet fault algorithm `FaultExtended`.
  - [BACnet.Protocol.FaultAlgorithms.FaultLifeSafety](BACnet.Protocol.FaultAlgorithms.FaultLifeSafety.md): Represents the BACnet fault algorithm `FaultLifeSafety`.
  - [BACnet.Protocol.FaultAlgorithms.FaultState](BACnet.Protocol.FaultAlgorithms.FaultState.md): Represents the BACnet fault algorithm `FaultState`.
  - [BACnet.Protocol.FaultAlgorithms.FaultStatusFlags](BACnet.Protocol.FaultAlgorithms.FaultStatusFlags.md): Represents the BACnet fault algorithm `FaultStatusFlags`.
  - [BACnet.Protocol.FaultParameters.FaultCharacterString](BACnet.Protocol.FaultParameters.FaultCharacterString.md): Represents the BACnet fault algorithm `FaultCharacterString` parameters.
  - [BACnet.Protocol.FaultParameters.FaultExtended](BACnet.Protocol.FaultParameters.FaultExtended.md): Represents the BACnet fault algorithm `FaultExtended` parameters.
  - [BACnet.Protocol.FaultParameters.FaultLifeSafety](BACnet.Protocol.FaultParameters.FaultLifeSafety.md): Represents the BACnet fault algorithm `FaultLifeSafety` parameters.
  - [BACnet.Protocol.FaultParameters.FaultState](BACnet.Protocol.FaultParameters.FaultState.md): Represents the BACnet fault algorithm `FaultState` parameters.
  - [BACnet.Protocol.FaultParameters.FaultStatusFlags](BACnet.Protocol.FaultParameters.FaultStatusFlags.md): Represents the BACnet fault algorithm `FaultStatusFlags` parameters.
  - [BACnet.Protocol.FaultParameters.None](BACnet.Protocol.FaultParameters.None.md): Represents the BACnet fault algorithm `None` parameters.
  - [BACnet.Protocol.NotificationParameters.BufferReady](BACnet.Protocol.NotificationParameters.BufferReady.md): Represents the BACnet event algorithm `BufferReady` notification parameters.
  - [BACnet.Protocol.NotificationParameters.ChangeOfBitstring](BACnet.Protocol.NotificationParameters.ChangeOfBitstring.md): Represents the BACnet event algorithm `ChangeOfBitstring` notification parameters.
  - [BACnet.Protocol.NotificationParameters.ChangeOfCharacterString](BACnet.Protocol.NotificationParameters.ChangeOfCharacterString.md): Represents the BACnet event algorithm `ChangeOfCharacterString` notification parameters.
  - [BACnet.Protocol.NotificationParameters.ChangeOfLifeSafety](BACnet.Protocol.NotificationParameters.ChangeOfLifeSafety.md): Represents the BACnet event algorithm `ChangeOfLifeSafety` notification parameters.
  - [BACnet.Protocol.NotificationParameters.ChangeOfReliability](BACnet.Protocol.NotificationParameters.ChangeOfReliability.md): Represents the BACnet event algorithm `ChangeOfReliability` notification parameters.
  - [BACnet.Protocol.NotificationParameters.ChangeOfState](BACnet.Protocol.NotificationParameters.ChangeOfState.md): Represents the BACnet event algorithm `ChangeOfState` notification parameters.
  - [BACnet.Protocol.NotificationParameters.ChangeOfStatusFlags](BACnet.Protocol.NotificationParameters.ChangeOfStatusFlags.md): Represents the BACnet event algorithm `ChangeOfStatusFlags` notification parameters.
  - [BACnet.Protocol.NotificationParameters.ChangeOfValue](BACnet.Protocol.NotificationParameters.ChangeOfValue.md): Represents the BACnet event algorithm `ChangeOfValue` notification parameters.
  - [BACnet.Protocol.NotificationParameters.CommandFailure](BACnet.Protocol.NotificationParameters.CommandFailure.md): Represents the BACnet event algorithm `CommandFailure` notification parameters.
  - [BACnet.Protocol.NotificationParameters.ComplexEventType](BACnet.Protocol.NotificationParameters.ComplexEventType.md): Represents the BACnet event algorithm `ComplexEventType` notification parameters.
  - [BACnet.Protocol.NotificationParameters.DoubleOutOfRange](BACnet.Protocol.NotificationParameters.DoubleOutOfRange.md): Represents the BACnet event algorithm `DoubleOutOfRange` notification parameters.
  - [BACnet.Protocol.NotificationParameters.Extended](BACnet.Protocol.NotificationParameters.Extended.md): Represents the BACnet event algorithm `Extended` notification parameters.
  - [BACnet.Protocol.NotificationParameters.FloatingLimit](BACnet.Protocol.NotificationParameters.FloatingLimit.md): Represents the BACnet event algorithm `FloatingLimit` notification parameters.
  - [BACnet.Protocol.NotificationParameters.OutOfRange](BACnet.Protocol.NotificationParameters.OutOfRange.md): Represents the BACnet event algorithm `OutOfRange` notification parameters.
  - [BACnet.Protocol.NotificationParameters.SignedOutOfRange](BACnet.Protocol.NotificationParameters.SignedOutOfRange.md): Represents the BACnet event algorithm `SignedOutOfRange` notification parameters.
  - [BACnet.Protocol.NotificationParameters.UnsignedOutOfRange](BACnet.Protocol.NotificationParameters.UnsignedOutOfRange.md): Represents the BACnet event algorithm `UnsignedOutOfRange` notification parameters.
  - [BACnet.Protocol.NotificationParameters.UnsignedRange](BACnet.Protocol.NotificationParameters.UnsignedRange.md): Represents the BACnet event algorithm `UnsignedRange` notification parameters.

- Protocol: BACnet/IP
  - [BACnet.Protocol.BroadcastDistributionTableEntry](BACnet.Protocol.BroadcastDistributionTableEntry.md)
  - [BACnet.Protocol.BvlcForwardedNPDU](BACnet.Protocol.BvlcForwardedNPDU.md)
  - [BACnet.Protocol.BvlcFunction](BACnet.Protocol.BvlcFunction.md)
  - [BACnet.Protocol.BvlcResult](BACnet.Protocol.BvlcResult.md)
  - [BACnet.Protocol.ForeignDeviceTableEntry](BACnet.Protocol.ForeignDeviceTableEntry.md)

- Stack
  - [BACnet.Stack.BBMD](BACnet.Stack.BBMD.md): The BBMD module is responsible for acting as a BACnet/IPv4 Broadcast Management Device (BBMD).
  - [BACnet.Stack.Client](BACnet.Stack.Client.md): The BACnet client is responsible for connecting the application to the BACnet transport protocol
and vice versa - it interfaces with the BACnet transport protocol, using the transport behaviour.
The client will take requests and send them to the BACnet transport protocol and ultimately listen for
frames from the BACnet transport protocol.
  - [BACnet.Stack.ClientHelper](BACnet.Stack.ClientHelper.md): BACnet stack client helper functions for executing commands/queries.

  - [BACnet.Stack.EncoderProtocol](BACnet.Stack.EncoderProtocol.md): This protocol is used inside the BACnet stack (transport modules) to encode APDU structs into binary BACnet APDUs,
which then are sent through the transport layer.

  - [BACnet.Stack.ForeignDevice](BACnet.Stack.ForeignDevice.md): The Foreign Device module is a server process that takes care of registering the application
(client/transport) as a Foreign Device in a BACnet/IPv4 Broadcast Management Device (BBMD).
  - [BACnet.Stack.LogBuffer](BACnet.Stack.LogBuffer.md): Simple log buffer implementation for event and trend logs.
The type of the item is not enforced.
  - [BACnet.Stack.LogBufferBehaviour](BACnet.Stack.LogBufferBehaviour.md): A behaviour for log buffer implementations, most notably for the `BACnet.Stack.TrendLogger` module.
  - [BACnet.Stack.Segmentator](BACnet.Stack.Segmentator.md): The Segmentator module is responsible for sending segmented requests or responses.
Incoming segments need to be handled manually or through the `BACnet.Stack.SegmentsStore` module.
  - [BACnet.Stack.SegmentsStore](BACnet.Stack.SegmentsStore.md): The Segments Store module handles incoming segments of a segmented request or response.
Outgoing segments need to be handled manually or through the `BACnet.Stack.Segmentator` module.
  - [BACnet.Stack.Telemetry](BACnet.Stack.Telemetry.md): Contains functions for easier interaction with telemetry.
  - [BACnet.Stack.TransportBehaviour](BACnet.Stack.TransportBehaviour.md): Defines the BACnet transport protocol behaviour.
  - [BACnet.Stack.TrendLogger](BACnet.Stack.TrendLogger.md): The Trend Logger module is responsible for handling event and trend logging
and keeping a log buffer.
  - [BACnet.Stack.Transport.EthernetTransport](BACnet.Stack.Transport.EthernetTransport.md): The BACnet transport for BACnet/Ethernet.
  - [BACnet.Stack.Transport.IPv4Transport](BACnet.Stack.Transport.IPv4Transport.md): The BACnet transport for BACnet/IP on IPv4.

- BACstack Internals
  - [BACnet.BeamTypes](BACnet.BeamTypes.md): Contains functions to resolve typespecs and types from BEAM bytecode
into a type declaration and functions to validate those types against values.
  - [BACnet.Protocol.ObjectsMacro](BACnet.Protocol.ObjectsMacro.md): This is an internal module for defining BACnet objects.
  - [BACnet.Protocol.Utility](BACnet.Protocol.Utility.md): Various utility functions to help with the BACnet protocol.

  - [BACnet.Protocol.Services.Behaviour](BACnet.Protocol.Services.Behaviour.md)
  - [BACnet.Protocol.Services.Common](BACnet.Protocol.Services.Common.md): This module implements the parsing for some services, which are available as both confirmed
and unconfirmed. So instead of implementing the same parsing and encoding twice, this module
is the common ground for these services.

  - [BACnet.Protocol.Services.Protocol](BACnet.Protocol.Services.Protocol.md)
  - [BACnet.Stack.BBMD.ClientRef](BACnet.Stack.BBMD.ClientRef.md): Internal module for `BACnet.Stack.BBMD`.
  - [BACnet.Stack.BBMD.Registration](BACnet.Stack.BBMD.Registration.md): Internal module for `BACnet.Stack.BBMD`.
  - [BACnet.Stack.BBMD.State](BACnet.Stack.BBMD.State.md): Internal module for `BACnet.Stack.BBMD`.
  - [BACnet.Stack.Client.ApduTimer](BACnet.Stack.Client.ApduTimer.md): Internal module for `BACnet.Stack.Client`.
  - [BACnet.Stack.Client.ReplyTimer](BACnet.Stack.Client.ReplyTimer.md): Internal module for `BACnet.Stack.Client`.
  - [BACnet.Stack.Client.State](BACnet.Stack.Client.State.md): Internal module for `BACnet.Stack.Client`.
  - [BACnet.Stack.ForeignDevice.Registration](BACnet.Stack.ForeignDevice.Registration.md): Internal module for `BACnet.Stack.ForeignDevice`.
  - [BACnet.Stack.ForeignDevice.State](BACnet.Stack.ForeignDevice.State.md): Internal module for `BACnet.Stack.ForeignDevice`.
  - [BACnet.Stack.Segmentator.Sequence](BACnet.Stack.Segmentator.Sequence.md): Internal module for `BACnet.Stack.Segmentator`.
  - [BACnet.Stack.Segmentator.State](BACnet.Stack.Segmentator.State.md): Internal module for `BACnet.Stack.Segmentator`.
  - [BACnet.Stack.SegmentsStore.Sequence](BACnet.Stack.SegmentsStore.Sequence.md): Internal module for `BACnet.Stack.SegmentsStore`.
  - [BACnet.Stack.SegmentsStore.State](BACnet.Stack.SegmentsStore.State.md): Internal module for `BACnet.Stack.SegmentsStore`.
  - [BACnet.Stack.TrendLogger.Log](BACnet.Stack.TrendLogger.Log.md): Internal module for `BACnet.Stack.TrendLogger`.
  - [BACnet.Stack.TrendLogger.State](BACnet.Stack.TrendLogger.State.md): Internal module for `BACnet.Stack.TrendLogger`.

- Exceptions
  - [BACnet.Protocol.ApplicationTags.Encoding.Error](BACnet.Protocol.ApplicationTags.Encoding.Error.md): `ApplicationTags.Encoding` errors.

  - [BACnet.Protocol.Constants.ConstantError](BACnet.Protocol.Constants.ConstantError.md): Constants exception.

