# Log-buffer performance and OTP storage options

Refreshed on 2026-11-01 against the current working tree. The
[benchmark](log_buffer.exs) measures both implemented buffers and experimental
alternatives. The [current results](log_buffer_results.csv) contain **840 cases**;
the [run metadata](log_buffer_results.csv.metadata.exs) records the runtime,
hardware, timestamps, Git revision, source hashes and result hash.

The run recorded revision `4ded527c041f117989fd734729553a6024d411f9`.
Source hashes identify the exact measured files, including local changes that
may not yet be committed. All tables below use this refreshed run; the recorded
source hashes also match the current implementations.

## Current implementation and recommendation

Two improvements from the original investigation are implemented:

- `LogBuffer.read_range/3` returns immediately for offsets outside the buffer,
  uses `peek/1` for one oldest record, and uses `peek_r/1` at the newest record.
  The last-record fast path also handles an oversized count clipped to one
  available record. Argument validation is preserved.
- `BACnet.Stack.LogBufferTree` implements the complete `LogBufferBehaviour`
  using monotonic integer keys. It supports bounded and unbounded buffers,
  FIFO checkout/drop, peeking, clipped range reads, ordered conversion,
  truncation and immutable snapshots. Both buffers provide `get_max_size/1`.
  The logger supports full-buffer notifications with either implementation.

For the chosen emphasis on indexed reads and paginated scans, use the tree
backend through the existing logger option:

```elixir
log_buffer_module: BACnet.Stack.LogBufferTree
```

The default remains `LogBuffer`. Its fast paths are effective for boundary
reads, and it remains faster for a single conversion of the entire buffer to a
list. There is no universal full-scan advantage for the tree: repeatedly reading
pages and converting once are different workloads.

For complete exports from a queue snapshot, convert once and consume successive
portions of the remaining list. Repeatedly calling
`Enum.slice(list, increasing_offset, count)` still revisits earlier records.
The convert-once approach allocates a complete list; it is not a bounded-memory
streaming interface. Retaining the original immutable snapshot preserves its
contents if logging continues during the export.

A page-reading logger API remains a separate possible improvement. Changing
storage alone does not remove the whole-buffer message sent by `get_buffer/2`
or the buffer included in notifications.

## Current measurements

Unless otherwise specified, capacity is **100,000 records**, a page contains
**100 records**, and times are medians per operation. Small-operation figures
show the fast paths, not portable nanosecond guarantees.

### Queue boundary fast paths

`before_boundary` reproduces the original `queue.to_list` plus `Enum.slice`
algorithm on the same inputs in the same run. It is explicitly historical code
in the benchmark, rather than a label for the current production implementation.

| Request | Before fast paths, us | Current queue, us | Implemented tree, us |
| --- | ---: | ---: | ---: |
| First record | 441.7 | 0.024 | 0.111 |
| Last record | 554.7 | 0.031 | 0.061 |
| Last record with count 100 | 463.0 | 0.026 | 0.061 |
| Offset at the end of the buffer | 586.0 | 0.015 | 0.015 |

These cases avoid whole-buffer conversion in the current queue implementation.
Other positional reads still use that conversion. The early size check and the
peek matches rely on the invariant that the stored size equals the queue length;
the buffer API maintains it, and immutable values cannot change between those
operations. Empty buffers, singleton buffers, overflow, clipped counts, `nil`,
`false` and invalid arguments are covered by the normal tests.

### Indexed pages, scans and writes

`tree` is the actual `LogBufferTree` module. `gb_trees`, `gb_ring`, `array` and
`map` are storage prototypes implementing only the operations needed for this
comparison, not the full buffer behavior.

| Store | Middle page, us | Page across physical end, us | Paginated scan, ms | Append, us/record |
| --- | ---: | ---: | ---: | ---: |
| Current queue | 507.8 | 422.7 | 322.06 | 0.190 |
| Implemented monotonic tree | 4.08 | 3.82 | 2.94 | 0.696 |
| Monotonic-tree prototype | 4.18 | 4.16 | 2.22 | 0.661 |
| Fixed-slot-tree prototype | 4.06 | 3.92 | 2.19 | 0.198 |
| Array-ring prototype | 4.86 | 4.82 | 2.67 | 0.179 |
| Map-ring prototype | 1.67 | 1.84 | 4.22 | 0.330 |

The current tree closely tracks the monotonic-key prototype. The map's hot
middle-page reads are fast, but its complete scan and overwrite workload have
different costs. Repeated reads of one small page do not predict access to an
entire large working set. The fixed-slot tree avoids deletion and insertion on
each overwrite, but that write optimization is not the selected implementation.

Append figures divide a batch replacing every slot twice by 200,000. Distinct
replacement records are prepared outside the timer. The batch includes queue
rebalances and two complete wraps; it does not measure individual insertion
tail latency or concurrent throughput.

A single full `to_list/1` conversion took **0.396 ms for the queue** and
**1.82 ms for the tree**. Converting the queue once and consuming successive
list pages took **1.96 ms**, versus **322.1 ms** for repeated current
queue page reads (about 164 times longer).

The paginated queue scan is approximately O(n² / page_size), because ordinary
pages still convert the whole queue and then traverse to their offsets. Its
new boundary cases do not change that general cost. Tree page reads seek by
key and iterate the requested records. A full conversion with `to_list/1` is
O(n) for both implementations, with different constant costs.

The scale of the buffer also matters:

| Capacity | Current middle page, us | Tree middle page, us |
| --- | ---: | ---: |
| 1,000 | 1.98 | 1.83 |
| 10,000 | 35.2 | 1.83 |
| 100,000 | 507.8 | 4.08 |

Small buffers alone do not justify replacing the default queue. These results
support selecting the tree where repeated indexed reads are important.

### Queue traversal alternatives and queue history

The `nearest` prototype skips from whichever end is closer and collects only
the requested records. It avoids dropping the final requested item from its
temporary queue, which could trigger an unnecessary rebalance. The `split`
prototype uses two queue splits and converts only the resulting page.

| Request / queue history | Current queue, us | Two splits, us | Nearer-end traversal, us |
| --- | ---: | ---: | ---: |
| First page / balanced | 545.3 | 67.0 | 3.64 |
| First page / near rebalance | 665.0 | 981.0 | 985.0 |
| Middle page / balanced | 507.8 | 945.5 | 553.5 |

The queue's end-operation costs are amortized. Traversing a temporary queue may
rebalance it, and reading the same original snapshot again repeats that work.
`queue.split/2` also computes list lengths internally. Neither alternative
guarantees work proportional only to the page size. The queue representation
is opaque and should not be unpacked by a buffer optimization.
[OTP queue source](https://github.com/erlang/otp/blob/OTP-27.3.4.17/lib/stdlib/src/queue.erl).

The benchmark covers balanced, append-built, partially overwritten and
near-rebalance histories. Indexed backends in the ordinary read matrix are
rebuilt from each queue snapshot. A separate `read_wrap` case overwrites one
quarter of the capacity and reads across the physical end of slot-based rings;
all backends return the same logical records. Correctness checks also exercise
repeated overwrites and clipped reads through the wrap positions.

### Process boundary

`TrendLogger.get_buffer/2` returns
`{:ok, {sequence_number, module, buffer}}`, so callers reading a small page first
receive the whole buffer. Notifications to a configured receiver likewise
include a full buffer. Repeated full-buffer notifications can make retained
mailboxes costly; that workload needs separate application profiling.

The following is an isolated GenServer experiment using the same snapshot reply
shape, not an end-to-end TrendLogger or BACnet service benchmark:

| Server store | Read approach | Time, ms |
| --- | --- | ---: |
| Queue | Send full snapshot, read page in caller | 27.6660 |
| Queue | Read in server, send page | 0.3157 |
| Queue | Prototype end traversal in server, send page | 0.0094 |
| Tree | Send full snapshot, read page in caller | 12.0180 |
| Tree | Read in server, send page | 0.0097 |

Both representations still pay for whole-snapshot messaging. The experiment
does not include logger contention, debug logging, transport encoding or network
latency. Computing a page in the logger also occupies its processing time;
responsiveness under concurrent logging requires separate validation.

## OTP datatype choices

| Datatype | Representation for a buffer | Main tradeoff |
| --- | --- | --- |
| `:queue` | Current double-ended queue | Cheap amortized appends/removals and fast boundary reads; general indexed pages still require traversal. |
| `:array` | Integer slots with head, live size and capacity | Immutable indexed storage; page reads use one lookup per record. Removed slots need resetting, and shrinking is explicit. |
| `:gb_trees` | Dense internal sequence keys or fixed physical slot keys | Immutable ordered storage with a seekable iterator; writes copy tree paths. |
| Map / `:maps` | Integer slots with head, live size and capacity | Fast keyed lookup; logical ordering comes from metadata, not map enumeration. |
| `:ets` | Shared `:set` or `:ordered_set` | Shared access avoids sending the entire buffer term, but ownership, lifetime and mutable-read consistency differ from immutable snapshots. |
| Flat tuple | One record per element | Direct indexed reads, but persistent updates generally copy the large tuple. Chunking would require a custom structure. |

The official [map guide](https://www.erlang.org/docs/27/system/maps.html) identifies
trees as an alternative for ordered conversion and arrays for non-negative
integer keys. The [array documentation](https://www.erlang.org/docs/27/apps/stdlib/array.html)
describes resetting entries and explicit shrinking. The
[ETS documentation](https://www.erlang.org/docs/27/apps/stdlib/ets.html) explains
ownership and record copying; returning a table handle would not provide the
current immutable snapshot semantics.

`dict` offers no ordered-page mechanism or clear design advantage over maps
here. Ordered lists/`orddict` retain linear positional access. Sets require
additional keys to preserve duplicate log values, with no clear advantage over
a tree of key/value entries. DETS, `disk_log`, databases and custom chunked
storage were not benchmarked, and no performance claim is made for them.

### Monotonic tree keys

`LogBufferTree` inserts at `next_key`. Retained records have dense keys, so a
positional offset maps to `next_key - size + offset`. A full-buffer append
deletes the oldest key before inserting the new one. Checkout, drop and
truncation retain the next key; `from_list/2` creates a new tree with new keys.

`iterator_from/2` seeks to the first key greater than or equal to its argument;
successive `next/1` calls collect the requested page without building a complete
list. For a balanced tree, this algorithm takes O(log n + page_size) work.
`to_list/1` calls `gb_trees.values/1` directly.
[Tree iterator documentation](https://www.erlang.org/docs/27/apps/stdlib/gb_trees.html#iterator_from/2).

A generic tree does not provide an efficient nth-entry operation through its
public API. Dense keys and FIFO removal let this buffer calculate the key
instead. Keys are independent of timestamps and wrapping BACnet sequence
numbers: duplicate values remain distinct records, and clock corrections do
not reorder them.

The alternative fixed-slot tree updates the head key and advances modulo
capacity. A page crossing the physical end uses a second iterator from zero.
Only that prototype uses physical slot reuse; the implemented tree uses the
chosen monotonic-key strategy, which also accommodates unbounded buffers.

Tree deletion does not automatically rebalance. Significant pruning may warrant
balancing or rebuilding if its remaining lookup performance requires it; no
automatic pruning heuristic was added.
[Tree balance documentation](https://www.erlang.org/docs/27/apps/stdlib/gb_trees.html#balance/1).

## Remaining improvements and limits

- A page-reading logger API could call the configured buffer's `read_range/3`
  and return a sequence number with the records. Successive offsets into a live
  ring do not provide a stable export snapshot: define sequence checks or cursor
  consistency and lifetime rules before adding that API. Keep `get_buffer/2`
  for consumers needing a full immutable snapshot.
- An optional lightweight notification carrying log identity and sequence
  information could let consumers request records. Preserve the existing
  full-buffer notification contract for consumers relying on it.
- Resizing currently transfers records through `to_list/1` and `from_list/2`.
  It is a whole-buffer operation, but was not benchmarked and is a lower-priority
  target unless resizing is frequent.
- Before changing the default backend, profile actual retention of older
  snapshots, partial fills, bulk pruning, concurrent logging and target hardware.
  The tree behavior is implemented and tested; the storage prototypes are not
  complete substitutes.

There are no internal calls to `read_range/3` in `lib` beyond its definitions.
The direct-read measurements concern consumers of the public buffer API, not
an existing automatic BACnet ReadRange handler inside `TrendLogger`.

## Reproduce and interpret

Run from the project root; Mix compiles the current source before loading it:

```sh
MIX_ENV=test mix run --no-start benchmarks/log_buffer.exs /tmp/log_buffer.csv
```

To refresh the checked-in result artifact, use
`benchmarks/log_buffer_results.csv` as the output path. The script writes a
companion `<output>.metadata.exs` file. The `current` CSV variant always calls
the actual `LogBuffer` module; `tree` calls `LogBufferTree`. The
`before_boundary` variant reproduces only the older read algorithm.

Environment for the saved run: Elixir 1.19.6; OTP 27 / ERTS 15.2.7.11; 64-bit JIT;
24 online schedulers; AMD Ryzen 9 7900X3D. Measurements were taken on a shared
workstation without CPU pinning or an exclusive machine reservation.

Records are actual `LogRecord` structs with timestamps and distinct real-value
encodings, at capacities 1,000, 10,000 and 100,000. Each case warms up and chooses
a bounded batch size, then reports the median of seven batches with a GC before
each batch. Natural GC within a timed batch is included; fixture construction,
worker startup and initial fixture copying are excluded. Repeated runs confirm
the large differences, but small timing differences can reflect cache, GC and
machine-load effects. Benchmark medians are not concurrency or tail-latency
guarantees.

CSV units are microseconds per invocation. `scan`, `to_list` and `write_2_turns`
describe a complete scan, full conversion and two-wrap batch respectively;
`read`/`read_wrap` describe one requested range. For `message`, `shape` identifies
the queue (`current`) or tree server. Reduction counts describe the measurement
worker only; message cases exclude server reductions. Reductions do not directly
measure CPU time across BIFs and Erlang implementations.

The script prints `:erts_debug.flat_size/1` probes for each backend, including
payloads. These are an unshared term-size model, not measurements of retained
process memory, allocation, GC pressure or peak memory. No substantial
application-memory improvement is established here.

Before timing, 22,320 history/offset/count/implementation combinations are checked
against list slicing, followed by empty/singleton cases, repeated overwrites,
clipped reads and preservation of original snapshots. The normal test suite
covers the complete implemented buffer behaviors and logger integration.
The focused buffer/logger run passed **108 tests**, and the benchmark script
passed its formatter check. Both full benchmark runs completed their correctness
checks; the saved CSV and all measured source files match the metadata hashes.

## Historical data

These earlier CSVs are retained as historical evidence. They predate the queue
boundary fast paths and should not be read as current queue measurements:

- [OTP prototype comparison](log_buffer_otp_results.csv): 480 cases.
- [Initial tree implementation comparison](log_buffer_tree_results.csv): 555 cases.

The current tables use neither historical file. The merged report supersedes
the earlier separate OTP comparison document and its implementation follow-up.
