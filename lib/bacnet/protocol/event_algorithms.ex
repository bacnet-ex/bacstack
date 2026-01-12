defmodule BACnet.Protocol.EventAlgorithms do
  @moduledoc """
  BACnet has various different types of event algorithms.
  Each of them is implemented by a different module.

  The event algorithm `AccessEvent` is not supported.

  ASHRAE 135:
  > Event algorithms monitor a value and evaluate whether the condition for
  > a transition of event state exists. The result of the evaluation,
  > indicated to the Event-State-Detection process, may be a transition to
  > a new event state, a transition to the same event state, or no transition.
  > The final determination of the Event_State property value is the responsibility
  > of the Event-State- Detection process and is subject to additional conditions. See Clause 13.2.
  >
  > Each of the event algorithms defines its input parameters, the allowable normal and
  > offnormal states, the conditions for transitions between those states,
  > and the notification parameters conveyed in event notifications for the algorithm.
  > When executing an event algorithm, all conditions defined for the algorithm shall be
  > evaluated in the order as presented for the algorithm. Some algorithms specify
  > optional conditions, marked as "Optional:" Whether or not an implementation uses
  > these conditions is a local matter. If no condition evaluates to true, then no
  > transition shall be indicated to the Event-State-Detection process.
  """

  @typedoc """
  Possible BACnet event algorithms.
  """
  @type event_algorithm ::
          __MODULE__.ChangeOfBitstring.t()
          | __MODULE__.ChangeOfState.t()
          | __MODULE__.ChangeOfValue.t()
          | __MODULE__.CommandFailure.t()
          | __MODULE__.FloatingLimit.t()
          | __MODULE__.OutOfRange.t()
          | __MODULE__.ChangeOfLifeSafety.t()
          | __MODULE__.BufferReady.t()
          | __MODULE__.UnsignedRange.t()
          | __MODULE__.DoubleOutOfRange.t()
          | __MODULE__.SignedOutOfRange.t()
          | __MODULE__.UnsignedOutOfRange.t()
          | __MODULE__.ChangeOfCharacterString.t()
          | __MODULE__.ChangeOfStatusFlags.t()
end
