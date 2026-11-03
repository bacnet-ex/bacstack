defmodule BACnet.InternalTest do
  alias BACnet.Internal

  use ExUnit.Case, async: true

  import ExUnit.CaptureIO
  import ExUnit.CaptureLog

  @moduletag :internal

  doctest Internal

  # Callers in lib expand these macros while the project compiles, before
  # coverage instrumentation, so those calls stay at 0%. Compiling a caller
  # during the test is what executes the macro body under coverage.
  # The dependency-only bodies of do_if_in_library/1, do_if_in_library_or_debugging/1,
  # and log_debug/1 are not part of this project's BEAM.

  test_data = [
    {"bitstring F", {false}, 0},
    {"bitstring T", {true}, 1},
    {"bitstring FTT", {false, true, true}, 6},
    {"bitstring TTF", {true, true, false}, 3},
    {"bitstring FFFT", {false, false, false, true}, 8},
    {"bitstring FTFT", {false, true, false, true}, 10},
    {"bitstring FFFFFFFF", {false, false, false, false, false, false, false, false}, 0},
    {"bitstring FTFFTFFT", {false, true, false, false, true, false, false, true}, 146}
  ]

  for {description, encode_data, decode_data} <- test_data do
    test "tuple to int #{description}" do
      assert unquote(decode_data) == Internal.tuple_to_int(unquote(Macro.escape(encode_data)))
    end
  end

  test "tuple_to_int/1 bitmasks sizes 1 through 65" do
    for size <- 1..65 do
      mixed = Enum.map(0..(size - 1), &(rem(&1, 3) != 0))
      mixed_tuple = List.to_tuple(mixed)
      mixed_actual = Internal.tuple_to_int(mixed_tuple)

      assert mixed_actual == bitmask(mixed),
             "size #{size} mixed got #{mixed_actual}"

      high = List.duplicate(false, size - 1) ++ [true]
      high_actual = Internal.tuple_to_int(List.to_tuple(high))

      assert high_actual == Bitwise.bsl(1, size - 1),
             "size #{size} high bit got #{high_actual}"

      zeros = List.to_tuple(List.duplicate(false, size))
      assert Internal.tuple_to_int(zeros) == 0
    end
  end

  test "tuple_to_int/1 rejects an empty tuple and values that are not tuples" do
    assert_raise FunctionClauseError, fn -> Internal.tuple_to_int({}) end
    assert_raise FunctionClauseError, fn -> Internal.tuple_to_int(true) end
    assert_raise FunctionClauseError, fn -> Internal.tuple_to_int([true, false]) end
  end

  test "tuple_to_int/1 raises when an element is not a boolean" do
    assert_raise ArgumentError, "Element is not a boolean", fn ->
      Internal.tuple_to_int({nil})
    end

    assert_raise ArgumentError, "Element is not a boolean", fn ->
      Internal.tuple_to_int({true, false, 1})
    end

    oversized = List.to_tuple(List.duplicate(true, 64) ++ [:no])

    assert_raise ArgumentError, "Element is not a boolean", fn ->
      Internal.tuple_to_int(oversized)
    end
  end

  test "is_dest/1 matches Process.dest and is_server/1 matches GenServer.server" do
    {probe, _source, _stderr} = compile_probe!(guard_source())
    port = open_port!()
    pid = self()

    accepted_dest = [
      pid,
      port,
      :registered_name,
      nil,
      {:name, :node},
      {:via, Registry},
      {true, false}
    ]

    rejected_dest = [
      {:via, Registry, :key},
      {:name, "node"},
      {"name", :node},
      {:only_name},
      {:name, :node, :extra},
      1,
      "registered_name",
      [:registered_name],
      %{name: :node},
      make_ref(),
      fn -> :ok end
    ]

    for term <- accepted_dest do
      assert probe.dest?(term), "expected dest: #{inspect(term)}"
    end

    for term <- rejected_dest do
      refute probe.dest?(term), "expected not dest: #{inspect(term)}"
    end

    accepted_server = [
      pid,
      :registered_name,
      nil,
      {:name, :node},
      {:via, Registry},
      {true, false},
      {:via, Registry, {Registry, "key"}},
      {:via, :mod, 1}
    ]

    rejected_server = [
      port,
      {:via, "mod", :term},
      {:via, 1, :term},
      {:not_via, Registry, :term},
      {:name, "node"},
      {"name", :node},
      {:only_name},
      {:name, :node, :extra},
      {:name, :node, :extra, :more},
      1,
      "server",
      [],
      %{},
      make_ref()
    ]

    for term <- accepted_server do
      assert probe.server?(term), "expected server: #{inspect(term)}"
    end

    for term <- rejected_server do
      refute probe.server?(term), "expected not server: #{inspect(term)}"
    end
  end

  test "library macros keep their do block when this project is compiled" do
    {probe, _source, _stderr} = compile_probe!(conditional_source())

    assert probe.in_library() == :library
    assert probe.in_library_or_debugging() == :library_or_debugging
  end

  test "is_env/2 and unless_env/2 follow the current Mix environment" do
    {probe, _source, _stderr} = compile_probe!(conditional_source())

    assert probe.included_env() == :included
    assert probe.excluded_env() == nil
    assert probe.unless_current() == nil
    assert probe.unless_other() == :included
  end

  test "log_debug/1 logs a message or a lazy function with the caller as source" do
    {probe, _source, _stderr} = compile_probe!(conditional_source())

    {_ok, log} =
      with_log([metadata: [:source]], fn ->
        assert :ok = probe.debug_string()
        assert :ok = probe.debug_fun()
      end)

    assert log =~ "internal debug string"
    assert log =~ "internal debug fun"
    assert log =~ "source=#{inspect(probe)}"
  end

  test "print_compile_warning/1 prints the message at the caller file and line" do
    {_probe, source, stderr} =
      compile_probe!("""
      require BACnet.Internal
      BACnet.Internal.print_compile_warning("internal coverage warning")
      """)

    {_text, line} =
      source
      |> String.split("\n")
      |> Enum.with_index(1)
      |> Enum.find(fn {text, _line} -> String.contains?(text, "print_compile_warning") end)

    assert stderr =~ "warning:"
    assert stderr =~ "internal coverage warning"
    assert stderr =~ "internal_coverage_probe.ex:#{line}"
  end

  defp bitmask(values) do
    Enum.reduce(Enum.with_index(values), 0, fn
      {true, index}, acc -> acc + Bitwise.bsl(1, index)
      {false, _index}, acc -> acc
    end)
  end

  defp guard_source() do
    """
    import BACnet.Internal, only: [is_dest: 1, is_server: 1]

    def dest?(term) when is_dest(term), do: true
    def dest?(_term), do: false

    def server?(term) when is_server(term), do: true
    def server?(_term), do: false
    """
  end

  defp conditional_source() do
    """
    require Logger
    require BACnet.Internal

    def in_library do
      BACnet.Internal.do_if_in_library do
        :library
      end
    end

    def in_library_or_debugging do
      BACnet.Internal.do_if_in_library_or_debugging do
        :library_or_debugging
      end
    end

    def included_env do
      BACnet.Internal.is_env(:test) do
        :included
      end
    end

    def excluded_env do
      BACnet.Internal.is_env(:dev) do
        :excluded
      end
    end

    def unless_current do
      BACnet.Internal.unless_env(:test) do
        :excluded
      end
    end

    def unless_other do
      BACnet.Internal.unless_env(:dev) do
        :included
      end
    end

    def debug_string do
      BACnet.Internal.log_debug("internal debug string")
      :ok
    end

    def debug_fun do
      BACnet.Internal.log_debug(fn -> "internal" <> " debug fun" end)
      :ok
    end
    """
  end

  defp compile_probe!(body) do
    module = Module.concat(__MODULE__, "Probe#{System.unique_integer([:positive])}")

    source = """
    defmodule #{inspect(module)} do
      @moduledoc false
      #{body}
    end
    """

    parent = self()

    stderr =
      capture_io(:stderr, fn ->
        compiled = Code.compile_string(source, "internal_coverage_probe.ex")
        send(parent, {:internal_probe_compiled, compiled})
      end)

    assert_received {:internal_probe_compiled, [{^module, _bin}]}

    on_exit(fn ->
      :code.purge(module)
      :code.delete(module)
    end)

    {module, source, stderr}
  end

  defp open_port!() do
    executable = System.find_executable("cat")
    port = Port.open({:spawn_executable, executable}, [:binary, args: []])

    on_exit(fn ->
      if Port.info(port), do: Port.close(port)
    end)

    port
  end
end
