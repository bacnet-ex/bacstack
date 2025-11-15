defmodule BACnet.Internal do
  @moduledoc false

  # TODO: Docs

  require Logger

  @compile {:inline, intify: 1}

  @in_library Mix.Project.get() == BACstack.MixProject and Mix.env() in [:dev, :test]

  @doc """
  Checks whether the given argument is `Process.dest()`.
  """
  @spec is_dest(term()) :: Macro.t()
  defguard is_dest(dest)
           when is_pid(dest) or is_port(dest) or is_atom(dest) or
                  (is_tuple(dest) and tuple_size(dest) == 2 and is_atom(elem(dest, 0)) and
                     is_atom(elem(dest, 1)))

  @doc """
  Checks whether the given argument is `GenServer.server()`,
  it also includes the `{:via, mod, term}` format,
  as `GenServer.call/3` uses `GenServer.whereis/1` to resolve the server argument.
  """
  @spec is_server(term()) :: Macro.t()
  defguard is_server(server)
           when is_pid(server) or is_atom(server) or
                  (is_tuple(server) and tuple_size(server) == 2 and is_atom(elem(server, 0)) and
                     is_atom(elem(server, 1))) or
                  (is_tuple(server) and tuple_size(server) == 3 and elem(server, 0) == :via and
                     is_atom(elem(server, 1)))

  # Enable debug logging (through this module) if
  # - this library is the app [OR]
  # - Logger.level() = :debug and :debug = true

  @doc false
  if @in_library or
       (Logger.level() == :debug and Application.compile_env(:bacstack, :debug, false)) do
    defmacro log_debug(message_or_fun) do
      quote do
        Logger.debug(unquote(message_or_fun), source: __MODULE__)
      end
    end
  else
    defmacro log_debug(message_or_fun) do
      # We still need to inject the message_or_fun into the AST
      # to avoid getting unused warnings from the compiler
      # (wrap into an anonymous function, just like Logger)
      quote generated: true do
        _unused = fn -> unquote(message_or_fun) end
        :ok
      end
    end
  end

  # Generate function clause with head pattern matching
  # For tuples with size 2-64 (step: 1 elements), use pattern matching
  # For all other tuples, use the fallback with Enum.reduce/3
  # credo:disable-for-lines:20 Credo.Check.Warning.UnsafeToAtom
  for len <- 2..64//1 do
    tuple =
      1..len
      |> Enum.map(fn val -> Macro.var(String.to_atom("v#{val}"), __MODULE__) end)
      |> then(&{:{}, [], &1})

    block =
      1..len//1
      |> Stream.with_index()
      |> Enum.map(fn {val, index} ->
        quote do
          Bitwise.bsl(
            intify(unquote(Macro.var(String.to_atom("v#{val}"), __MODULE__))),
            unquote(abs(index))
          )
        end
      end)
      |> Enum.reduce(nil, fn
        calc, nil ->
          calc

        calc, acc ->
          quote do
            unquote(calc) + unquote(acc)
          end
      end)

    def tuple_to_int(unquote(tuple)) do
      unquote(block)
    end
  end

  @doc """
  Calculates the integer bitmask of a tuple of booleans.
  """
  @spec tuple_to_int(tuple()) :: non_neg_integer()
  def tuple_to_int(tuple) when is_tuple(tuple) and tuple_size(tuple) > 0 do
    Enum.reduce(0..(tuple_size(tuple) - 1)//1, 0, fn index, acc ->
      Bitwise.bsl(intify(elem(tuple, index)), index) + acc
    end)
  end

  @spec intify(boolean()) :: 0 | 1
  defp intify(true), do: 1
  defp intify(false), do: 0
  defp intify(_term), do: raise(ArgumentError, "Element is not a boolean")

  @doc """
  Prints a compile-time warning.

  This macro uses `:elixir_errors.print_warning/3` (Elixir internal API) behind the scene
  and allows easy function swapping in the future.
  """
  @spec print_compile_warning(String.t()) :: Macro.t()
  defmacro print_compile_warning(message) do
    quote bind_quoted: [file: __CALLER__.file, line: __CALLER__.line, message: message] do
      :elixir_errors.print_warning(line, file, message)
    end
  end
end
