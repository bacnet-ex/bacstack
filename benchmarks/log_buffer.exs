# Run from the project root; Mix compiles the current implementations first:
#   MIX_ENV=test mix run --no-start benchmarks/log_buffer.exs /tmp/log_buffer.csv
# Compare storage prototypes and the production tree backend.
defmodule LogBufferBenchmark do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.LogRecord
  alias BACnet.Stack.LogBuffer
  alias BACnet.Stack.LogBufferTree

  @samples 7
  @variants [
    :current,
    :before_boundary,
    :split,
    :nearest,
    :array,
    :gb_trees,
    :gb_ring,
    :map,
    :tree
  ]
  @backends [:current, :array, :gb_trees, :gb_ring, :map, :tree]

  def run(path) do
    metadata = metadata()
    IO.puts("Elixir #{System.version()}, OTP #{:erlang.system_info(:otp_release)}")
    IO.puts("#{:erlang.system_info(:schedulers_online)} schedulers; #{@samples} samples per case")
    validate!()
    File.write!(path, "kind,size,shape,position,variant,iterations,median_us,median_reductions\n")

    for size <- [1_000, 10_000, 100_000] do
      # Construction and copying fixtures into measurement workers are outside timing.
      records = Enum.map(1..size, &record/1)

      for shape <- [:balanced, :appended, :wrapped, :boundary] do
        buffer = buffer(records, shape)
        inputs = inputs(buffer)

        positions = [
          {:head_one, 0, 1},
          {:head, 0, 100},
          {:middle, div(size, 2), 100},
          {:tail, size - 100, 100},
          {:tail_one, size - 1, 1},
          {:tail_clipped, size - 1, 100},
          {:past_end, size, 100}
        ]

        for {position, offset, count} <- positions, variant <- @variants do
          input = Map.fetch!(inputs, variant)
          result = measure(fn -> read(variant, input, offset, count) end)
          row(path, [:read, size, shape, position, variant], result)
        end

        IO.puts("Read cases finished: #{size} / #{shape}")
      end

      buffer = buffer(records, :balanced)
      inputs = inputs(buffer)
      writes = Enum.map((size + 1)..(size * 3), &record/1)

      # Read across the physical end of a partially overwritten ring. The queue
      # and monotonic tree hold the same logical records without a slot wrap.
      for variant <- @backends do
        input = Map.fetch!(inputs, variant)
        input = write_batch(variant, input, Enum.take(writes, div(size, 4)))
        offset = size - div(size, 4) - 50
        result = measure(fn -> read(variant, input, offset, 100) end)
        row(path, [:read_wrap, size, :quarter_turn, :cross_physical_end, variant], result)
      end

      for variant <- @backends ++ [:before_boundary, :nearest, :list_once] do
        input = Map.fetch!(inputs, variant)

        result = measure(fn -> scan(variant, input, size) end)
        row(path, [:scan, size, :balanced, :pages_of_100, variant], result)
      end

      for {variant, module} <- [current: LogBuffer, tree: LogBufferTree] do
        input = Map.fetch!(inputs, variant)
        result = measure(fn -> module.to_list(input) end)
        row(path, [:to_list, size, :balanced, :all, variant], result)
      end

      for variant <- @backends do
        input = Map.fetch!(inputs, variant)
        # Two complete turns include queue rebalances and replace every slot
        # with distinct records. Repeating one item can favor array no-op writes.
        result = measure(fn -> write_batch(variant, input, writes) end)
        row(path, [:write_2_turns, size, :balanced, :overflow, variant], result)
        words = :erts_debug.flat_size(input)
        IO.puts("Unshared term words (not allocation): #{size} / #{variant}: #{words}")
      end

      for {backend, module} <- [current: LogBuffer, tree: LogBufferTree] do
        {:ok, server} = LogBufferBenchmark.Server.start({module, Map.fetch!(inputs, backend)})

        try do
          methods =
            if backend == :current,
              do: [:snapshot_then_read, :page_current, :page_nearest],
              else: [:snapshot_then_read, :page_current]

          for method <- methods do
            result = measure(fn -> remote_read(server, method) end)
            row(path, [:message, size, backend, :head, method], result)
          end
        after
          GenServer.stop(server)
        end
      end
    end

    metadata =
      Map.merge(metadata, %{
        finished_at: DateTime.to_iso8601(DateTime.utc_now()),
        result_sha256: hash_file(path)
      })

    File.write!(
      path <> ".metadata.exs",
      inspect(metadata, pretty: true, limit: :infinity) <> "\n"
    )

    IO.puts("Wrote #{path}")
    IO.puts("Wrote #{path}.metadata.exs")
  end

  # Select the nearer end using the public queue API. Avoid dropping after the
  # final requested item: that alone can unnecessarily rebalance the queue.
  def read(:nearest, %{size: size}, offset, _count) when offset >= size, do: []

  def read(:nearest, buffer, offset, count) do
    count = min(count, buffer.size - offset)
    rear_offset = buffer.size - offset - count

    if offset <= rear_offset do
      buffer.items |> skip(offset, :front) |> take(count, :front, []) |> Enum.reverse()
    else
      buffer.items |> skip(rear_offset, :rear) |> take(count, :rear, [])
    end
  end

  def read(:split, %{size: size}, offset, _count) when offset >= size, do: []

  def read(:split, buffer, offset, count) do
    {_before, rest} = :queue.split(offset, buffer.items)
    {page, _after} = :queue.split(min(count, buffer.size - offset), rest)
    :queue.to_list(page)
  end

  def read(:current, buffer, offset, count), do: LogBuffer.read_range(buffer, offset, count)
  def read(:tree, buffer, offset, count), do: LogBufferTree.read_range(buffer, offset, count)

  # Historical algorithm, measured alongside the current code on the same input.
  def read(:before_boundary, buffer, offset, count) do
    Enum.slice(:queue.to_list(buffer.items), offset, count)
  end

  def read(:array, {_items, _head, size}, offset, _count) when offset >= size, do: []

  def read(:array, {items, head, size}, offset, count) do
    for index <- offset..(min(size, offset + count) - 1) do
      :array.get(rem(head + index, size), items)
    end
  end

  def read(variant, {_items, _head, size}, offset, _count)
      when variant in [:gb_trees, :gb_ring, :map] and offset >= size,
      do: []

  # Dense internal keys make a positional offset a key calculation. A generic
  # tree with arbitrary keys does not provide an efficient nth-entry operation.
  def read(:gb_trees, {tree, oldest, size}, offset, count) do
    tree
    |> then(&:gb_trees.iterator_from(oldest + offset, &1))
    |> tree_take(min(count, size - offset), [])
    |> Enum.reverse()
  end

  # Fixed physical slots avoid delete+insert on every bounded append. A page
  # crossing the physical end requires a second iterator starting at slot zero.
  def read(:gb_ring, {tree, head, size}, offset, count) do
    start = rem(head + offset, size)
    count = min(count, size - offset)
    first_count = min(count, size - start)
    acc = tree_take(:gb_trees.iterator_from(start, tree), first_count, [])

    if count > first_count do
      tree |> :gb_trees.iterator() |> tree_take(count - first_count, acc) |> Enum.reverse()
    else
      Enum.reverse(acc)
    end
  end

  def read(:map, {items, head, size}, offset, count) do
    for index <- offset..(min(size, offset + count) - 1) do
      Map.fetch!(items, rem(head + index, size))
    end
  end

  defp tree_take(_iterator, 0, acc), do: acc

  defp tree_take(iterator, count, acc) do
    {_key, value, next} = :gb_trees.next(iterator)
    tree_take(next, count - 1, [value | acc])
  end

  defp skip(queue, 0, _end), do: queue
  defp skip(queue, count, :front), do: skip(:queue.drop(queue), count - 1, :front)
  defp skip(queue, count, :rear), do: skip(:queue.drop_r(queue), count - 1, :rear)

  defp take(queue, 1, :front, acc), do: [:queue.get(queue) | acc]
  defp take(queue, 1, :rear, acc), do: [:queue.get_r(queue) | acc]

  defp take(queue, count, :front, acc) do
    take(:queue.drop(queue), count - 1, :front, [:queue.get(queue) | acc])
  end

  defp take(queue, count, :rear, acc) do
    take(:queue.drop_r(queue), count - 1, :rear, [:queue.get_r(queue) | acc])
  end

  defp inputs(buffer) do
    records = LogBuffer.to_list(buffer)
    pairs = Enum.with_index(records, fn record, index -> {index, record} end)
    tree = :gb_trees.from_orddict(pairs)

    %{
      current: buffer,
      before_boundary: buffer,
      split: buffer,
      nearest: buffer,
      list_once: buffer,
      array: {:array.from_list(records), 0, buffer.size},
      gb_trees: {tree, 0, buffer.size},
      gb_ring: {tree, 0, buffer.size},
      map: {Map.new(pairs), 0, buffer.size},
      tree: LogBufferTree.from_list(records, buffer.max_size)
    }
  end

  defp write(:current, buffer, item), do: LogBuffer.checkin(buffer, item)
  defp write(:tree, buffer, item), do: LogBufferTree.checkin(buffer, item)

  defp write(:array, {items, head, size}, item) do
    {:array.set(head, item, items), rem(head + 1, size), size}
  end

  defp write(:gb_trees, {tree, oldest, size}, item) do
    tree = :gb_trees.delete(oldest, tree)
    tree = :gb_trees.insert(oldest + size, item, tree)
    {tree, oldest + 1, size}
  end

  defp write(:gb_ring, {tree, head, size}, item) do
    {:gb_trees.update(head, item, tree), rem(head + 1, size), size}
  end

  defp write(:map, {items, head, size}, item) do
    {Map.put(items, head, item), rem(head + 1, size), size}
  end

  defp write_batch(_variant, input, []), do: input

  defp write_batch(variant, input, [item | rest]) do
    write_batch(variant, write(variant, input, item), rest)
  end

  defp scan(:list_once, buffer, _size), do: consume_pages(LogBuffer.to_list(buffer), 0)

  defp scan(variant, input, size) do
    # Consume each page without retaining the whole export in memory.
    Enum.reduce(0..(div(size, 100) - 1), 0, fn page, count ->
      count + length(read(variant, input, page * 100, 100))
    end)
  end

  defp consume_pages([], count), do: count

  defp consume_pages(items, count) do
    {page, rest} = Enum.split(items, 100)
    consume_pages(rest, count + length(page))
  end

  defp remote_read(server, :snapshot_then_read) do
    {:ok, {_sequence, module, buffer}} = GenServer.call(server, :snapshot)
    module.read_range(buffer, 0, 100)
  end

  defp remote_read(server, variant), do: GenServer.call(server, variant)

  defp buffer(records, :balanced), do: LogBuffer.from_list(records, length(records))

  defp buffer(records, :appended) do
    Enum.reduce(records, LogBuffer.new(length(records)), &LogBuffer.checkin(&2, &1))
  end

  defp buffer(records, :wrapped) do
    Enum.reduce(Enum.take(records, div(length(records), 4)), buffer(records, :balanced), fn
      item, acc -> LogBuffer.checkin(acc, item)
    end)
  end

  defp buffer(records, :boundary) do
    Enum.reduce(Enum.take(records, div(length(records), 2) - 1), buffer(records, :balanced), fn
      item, acc -> LogBuffer.checkin(acc, item)
    end)
  end

  defp record(index) do
    %LogRecord{
      timestamp: %BACnetDateTime{
        date: %BACnetDate{
          year: 2026,
          month: 1,
          day: 1 + rem(div(index, 86_400), 28),
          weekday: 1 + rem(3 + rem(div(index, 86_400), 28), 7)
        },
        time: %BACnetTime{
          hour: rem(div(index, 3_600), 24),
          minute: rem(div(index, 60), 60),
          second: rem(index, 60),
          hundredth: 0
        }
      },
      log_datum: %Encoding{encoding: :primitive, type: :real, value: index / 10, extras: []},
      status_flags: nil
    }
  end

  defp validate!() do
    # Check queue shapes, clipped ranges, empty/singleton buffers and overflow.
    for size <- [2, 3, 10, 101], shape <- [:balanced, :appended, :wrapped, :boundary] do
      buffer = buffer(Enum.to_list(1..size), shape)
      inputs = inputs(buffer)

      for offset <- 0..(size + 1), count <- [1, 2, 9, size, size + 1], variant <- @variants do
        input = Map.fetch!(inputs, variant)
        expected = Enum.slice(LogBuffer.to_list(buffer), offset, count)
        ^expected = read(variant, input, offset, count)
      end

      Enum.reduce((size + 1)..(size * 3), inputs, fn item, acc ->
        updated =
          Map.new(@backends, fn variant -> {variant, write(variant, acc[variant], item)} end)

        expected = LogBuffer.to_list(updated.current)

        for variant <- @backends do
          input = Map.fetch!(updated, variant)
          ^expected = read(variant, input, 0, size)

          # Validate clipped pages at every physical wrap position too.
          for offset <- [0, div(size, 2), size - 1], count <- [1, 2, size + 1] do
            page = Enum.slice(expected, offset, count)
            ^page = read(variant, input, offset, count)
          end

          # Writing must leave the original snapshot readable.
          original = LogBuffer.to_list(buffer)
          ^original = read(variant, inputs[variant], 0, size)
        end

        updated
      end)
    end

    for records <- [[], [:only]], variant <- @variants do
      buffer = LogBuffer.from_list(records)
      input = Map.fetch!(inputs(buffer), variant)
      ^records = read(variant, input, 0, 10)
      [] = read(variant, input, length(records), 1)
    end

    IO.puts("Backend correctness checks passed")
  end

  defp metadata() do
    revision =
      case System.cmd("git", ["rev-parse", "HEAD"], stderr_to_stdout: true) do
        {revision, 0} -> String.trim(revision)
        {_output, _status} -> nil
      end

    sources = [
      "benchmarks/log_buffer.exs",
      "lib/bacnet/stack/log_buffer.ex",
      "lib/bacnet/stack/log_buffer_tree.ex",
      "lib/bacnet/stack/log_buffer_behaviour.ex",
      "lib/bacnet/stack/trend_logger.ex"
    ]

    cpu_model =
      if File.exists?("/proc/cpuinfo") do
        case Regex.run(~r/^model name\s*:\s*(.+)$/m, File.read!("/proc/cpuinfo"),
               capture: :all_but_first
             ) do
          [model] -> model
          nil -> nil
        end
      end

    %{
      started_at: DateTime.to_iso8601(DateTime.utc_now()),
      git_revision: revision,
      source_sha256: Map.new(sources, &{&1, hash_file(&1)}),
      elixir: System.version(),
      otp: to_string(:erlang.system_info(:otp_release)),
      erts: to_string(:erlang.system_info(:version)),
      architecture: to_string(:erlang.system_info(:system_architecture)),
      word_size: :erlang.system_info(:wordsize),
      schedulers: :erlang.system_info(:schedulers_online),
      cpu_model: cpu_model,
      samples: @samples,
      sizes: [1_000, 10_000, 100_000],
      variants: @variants,
      backends: @backends
    }
  end

  defp hash_file(path) do
    :sha256 |> :crypto.hash(File.read!(path)) |> Base.encode16(case: :lower)
  end

  defp measure(fun) do
    parent = self()
    reference = make_ref()

    {pid, monitor} =
      spawn_monitor(fn ->
        repeat(fun, 3)
        {warmup_us, _result} = :timer.tc(fn -> repeat(fun, 3) end)
        iterations = max(1, min(2_000, div(15_000, max(1, div(warmup_us, 3)))))

        samples =
          for _sample <- 1..@samples do
            :erlang.garbage_collect()
            {:reductions, before_reductions} = Process.info(self(), :reductions)
            {elapsed, _result} = :timer.tc(fn -> repeat(fun, iterations) end)
            {:reductions, after_reductions} = Process.info(self(), :reductions)
            {elapsed / iterations, (after_reductions - before_reductions) / iterations}
          end

        send(parent, {reference, {iterations, median(samples, 0), median(samples, 1)}})
      end)

    receive do
      {^reference, result} ->
        Process.demonitor(monitor, [:flush])
        result

      {:DOWN, ^monitor, :process, ^pid, reason} ->
        raise "Measurement worker failed: #{inspect(reason)}"
    after
      60_000 -> raise "Measurement worker timed out"
    end
  end

  defp repeat(_fun, 0), do: :ok

  defp repeat(fun, count) do
    fun.()
    repeat(fun, count - 1)
  end

  defp median(samples, index) do
    samples |> Enum.map(&elem(&1, index)) |> Enum.sort() |> Enum.at(div(@samples, 2))
  end

  defp row(path, labels, {iterations, time, reductions}) do
    values = labels ++ [iterations, Float.round(time, 3), Float.round(reductions, 1)]
    File.write!(path, Enum.join(values, ",") <> "\n", [:append])
  end
end

# Isolate the full-snapshot message cost from TrendLogger's other processing.
# This is a synthetic server with the same full-buffer reply shape, not an
# end-to-end TrendLogger or BACnet service benchmark.
defmodule LogBufferBenchmark.Server do
  use GenServer

  def start(state), do: GenServer.start(__MODULE__, state)

  @impl GenServer
  def init(state), do: {:ok, state}

  @impl GenServer
  def handle_call(:snapshot, _from, {module, buffer} = state) do
    {:reply, {:ok, {1, module, buffer}}, state}
  end

  def handle_call(:page_current, _from, {module, buffer} = state) do
    {:reply, {:ok, {1, module.read_range(buffer, 0, 100)}}, state}
  end

  def handle_call(:page_nearest, _from, {_module, buffer} = state) do
    {:reply, {:ok, {1, LogBufferBenchmark.read(:nearest, buffer, 0, 100)}}, state}
  end
end

LogBufferBenchmark.run(List.first(System.argv()) || "/tmp/log_buffer.csv")
