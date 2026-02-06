# `BACnet.Protocol.FaultAlgorithms`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/fault_algorithms.ex#L1)

BACnet has various different types of fault algorithms.
Each of them is implemented by a different module.

ASHRAE 135:
> Certain object types may optionally support a fault algorithm which has
> externally visible inputs and is performed as part of the object's
> reliability-evaluation process. This clause defines the standard fault algorithms.
> To determine which algorithm is applied by which object type, see the
> object type definitions in Clause 12.
>
> Fault algorithms monitor a value and evaluate whether the condition for
transition of reliability exists. The result of the evaluation,
> indicated to the reliability-evaluation process, may be a transition
> to a new reliability, a transition to the same reliability, or no transition.
> The final determination of the Reliability property value is the responsibility
> of the reliability evaluation process and is subject to additional conditions.
> See Clause 13.2.
> Each of the fault algorithms defines its input parameters, the allowable
> reliability values, and the conditions for transitions between those values.
> When evaluating the monitored value, all conditions defined for the algorithm
> shall be evaluated in the order as presented for the algorithm.
> Some algorithms specify optional conditions, marked as "Optional:" whether
> or not an implementation uses these conditions is a local matter.
> If no condition evaluates to true, then no transition shall be indicated
> to the reliability evaluation process.

# `fault_algorithm`

```elixir
@type fault_algorithm() ::
  BACnet.Protocol.FaultAlgorithms.FaultCharacterString.t()
  | BACnet.Protocol.FaultAlgorithms.FaultLifeSafety.t()
  | BACnet.Protocol.FaultAlgorithms.FaultState.t()
  | BACnet.Protocol.FaultAlgorithms.FaultStatusFlags.t()
```

Possible BACnet fault algorithms.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
