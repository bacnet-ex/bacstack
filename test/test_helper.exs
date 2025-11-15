# -------------------
# Silence type warnings from Elixir v1.18+ for our test files
Code.put_compiler_option(:ignore_module_conflict, true)

defmodule Elixir.Module.Types do
  def infer(_module, _file, _all_definitions, _private, _usedprivate, _e, _checker_info),
    do: {%{}, []}

  def infer(_module, _file, _all_definitions, _private, _usedprivate, _e, _checker_info, _cache),
    do: {%{}, []}

  def warnings(_module, _file, _defs, _no_warn_undefined, _cache), do: []
  def warnings(_module, _file, _attrs, _defs, _no_warn_undefined, _cache), do: []
end

Code.put_compiler_option(:ignore_module_conflict, false)
# -------------------

ExUnit.start()
