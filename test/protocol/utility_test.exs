defmodule BACnet.Test.Protocol.UtilityTest do
  use ExUnit.Case, async: true

  @moduletag :protocol_utility

  doctest BACnet.Protocol.Utility

  # Callers in lib expand this macro while the project compiles, before
  # coverage instrumentation, so those calls stay at 0%. Compiling a caller
  # during the test is what executes the macro body under coverage.
  test "pattern_extract_tags is covered when a caller is compiled during the test" do
    module = Module.concat(__MODULE__, "Probe#{System.unique_integer([:positive])}")

    [{^module, _bin}] =
      Code.compile_string("""
      defmodule #{inspect(module)} do
        import BACnet.Protocol.Utility

        def required(tags) do
          pattern_extract_tags(tags, {:unsigned_integer, _value}, :unsigned_integer, false)
        end

        def optional(tags) do
          pattern_extract_tags(tags, {:unsigned_integer, _value}, :unsigned_integer, true)
        end

        def raw(tags) do
          pattern_extract_tags(tags, {:unsigned_integer, _value}, nil, false)
        end

        def transformed(tags) do
          pattern_extract_tags(tags, {:unsigned_integer, _value}, fn {:unsigned_integer, value} ->
            {:ok, value}
          end, false)
        end

        def dynamic(tags, transform, optional) do
          pattern_extract_tags(tags, {:unsigned_integer, _value}, transform, optional)
        end
      end
      """)

    assert {:ok, 7, []} = module.required([{:unsigned_integer, 7}])
    assert {:error, :missing_pattern} = module.required([])
    assert {:ok, nil, []} = module.optional([])
    assert {:ok, {:unsigned_integer, 7}, []} = module.raw([{:unsigned_integer, 7}])
    assert {:ok, 7, []} = module.transformed([{:unsigned_integer, 7}])

    assert {:ok, 7, []} =
             module.dynamic(
               [{:unsigned_integer, 7}],
               fn {:unsigned_integer, value} -> {:ok, value} end,
               false
             )
  end
end
