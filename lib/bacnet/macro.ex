defmodule BACnet.Macro do
  @module_doc """
  This module provides convenience macros.

  This module provides macros to define constants, which get compiled into functions.
  To use this feature, this module must be included into the module using `use/2`.

  `use/2` will then compile a few things into the module:
    - A list of constants (only available at compile time, to get it at runtime, you need to
    add a function to retrieve the `:constants` attribute)
    - Constants docs chunks from `defconstforward/2` included modules
    - Generate module docs with all constants, rendered as table by type,
      in the module when giving the option `generate_docs: true`, if the module already contains
      module docs, the constants docs will be appended to it

  Constants can be annotated with the `constdoc` attribute to provide a documentation string for the constant type.

  The following functions and macros are created to work with the constants:
    - Function `assert_name/2` - Asserts that the constant exists (returns the name) as success tuple
    - Function `assert_name!/2` - Asserts that the constant exists (returns the name)
    - Function `by_name/2` - Returns the constant value by type and name as success tuple
    - Function `by_name!/2` - Returns the constant value by type and name
    - Function `by_value/2` - Returns the constant name by type and value as success tuple
    - Function `by_value!/2` - Returns the constant name by type and value
    - Function `has_by_name/2` - Checks whether the constant identified by type and name exists
    - Function `has_by_value/2` - Checks whether the constant identified by type and value exists
    - Macro `macro_assert_name/2` - Same as `assert_name!/2` but as macro
    - Macro `macro_by_name/2` - Same as `by_name!/2` but as macro
    - Macro `macro_by_value/2` - Same as `by_value!/2` but as macro

  All bang functions will fail with `RuntimeError` (overridable with `:exception`),
  if the constant does not exist. Likewise for macros.

  This module also provides typed structs, that will generate a struct with type `t`, based on the given arguments.

  Such as this module
  ```elixir
  defmodule Report do
    @type report_type :: :refactoring | :warning | :consistency

    @type t :: %__MODULE__{
      type: report_type,
      description: String.t,
      message: String.t | nil
    }
    @enforce_keys [:type, :description]
    defstruct [:description, :message, type: :refactoring]
  end
  ```

  can be rewritten to
  ```elixir
  defmodule Report do
    @type report_type :: :refactoring | :warning | :consistency

    # required? is by default true
    typedstruct do
      field :type, report_type, default: :refactoring
      field :description, String.t
      field :message, String.t, required: false
    end
  end
  ```
  """

  # Do not generate module docs meanwhile (and do not generate a warning)
  @moduledoc !@module_doc

  @doc false
  defmacro __using__(opts) do
    exception = Keyword.get(opts, :exception, RuntimeError)

    quote do
      require unquote(exception)
      @constants_exception unquote(exception)

      if unquote(opts)[:generate_docs] == true do
        @constants_moduledoc true
      else
        @constants_moduledoc false
      end

      if unquote(opts)[:generate_types_value] == true do
        @constants_typespecs_values true
      else
        @constants_typespecs_values false
      end

      if unquote(opts)[:copy_doc_to_type] == true do
        @constants_typedoc_copy true
      else
        @constants_typedoc_copy false
      end

      if unquote(opts)[:no_types] == true do
        @constants_no_types true
      else
        @constants_no_types false
      end

      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)

      # Contains all local registered constants (excluding defconstforward/2)
      Module.register_attribute(__MODULE__, :constants, accumulate: true)

      # Contains all constants (docs chunk) from defconstforward/2 included modules
      Module.register_attribute(__MODULE__, :constants_docs_chunk, accumulate: true)

      # Contains all names of defconstforward/2 included modules to de-duplicate chunks
      Module.register_attribute(__MODULE__, :docs_chunk_modules, accumulate: true)
    end
  end

  # credo:disable-for-lines:10 Credo.Check.Refactor.CyclomaticComplexity
  @doc false
  defmacro __before_compile__(env) do
    const_cases =
      for {type, name, value, _docs, _cdocs} <- Module.get_attribute(env.module, :constants) do
        quote do
          {unquote(type), unquote(name), nil} ->
            {:ok, {unquote(type), unquote(name), unquote(value)}}

          {unquote(type), nil, unquote(value)} ->
            {:ok, {unquote(type), unquote(name), unquote(value)}}
        end
      end

    catch_case =
      quote do
        term -> :error
      end

    cases = List.flatten([const_cases, catch_case])

    generated_const_call =
      quote do
        defp const_call(type, name, value) do
          case {type, name, value} do
            unquote(cases)
          end
        end
      end

    generated_rest =
      quote location: :keep, unquote: false do
        # Protects against no constants defined - do not generate anything
        if Module.get_attribute(__MODULE__, :constants, []) != [] do
          # defp const_call(_type, _name, _value), do: throw(:const_not_found)

          # IMPORTANT NOTICE: If you add new functions here, add them to defconstforward/2 too!

          @doc """
          Retrieve the value of a constant, identified by `type` and `name`. If found,
          the value will be returned, otherwise the default will be returned.
          """
          @spec by_name_safe(atom(), atom(), term()) :: term()
          def by_name_safe(type, name, default) when is_atom(type) do
            case const_call(type, name, nil) do
              {:ok, {_type, _name, value}} -> value
              :error -> default
            end
          end

          @doc """
          Retrieve the value of a constant, identified by `type` and `value`. If found,
          the name will be returned, otherwise the default will be returned.
          """
          @spec by_value_safe(atom(), term(), term()) :: term()
          def by_value_safe(type, value, default) when is_atom(type) do
            case const_call(type, nil, value) do
              {:ok, {_type, name, _value}} -> name
              :error -> default
            end
          end

          @doc """
          Checks if the constant exists, identified by `type` and `name`.
          """
          @spec has_by_name(atom(), atom()) :: bool()
          def has_by_name(type, name) when is_atom(type) do
            match?({:ok, _val}, const_call(type, name, nil))
          end

          @doc """
          Checks if the constant exists, identified by `type` and `value`.
          """
          @spec has_by_value(atom(), term()) :: bool()
          def has_by_value(type, value) when is_atom(type) do
            match?({:ok, _val}, const_call(type, nil, value))
          end

          @doc """
          Assert that the given constant is defined. This function returns the name of the constant.
          """
          @spec assert_name(atom(), atom()) :: {:ok, atom()} | :error
          def assert_name(type, name) when is_atom(type) do
            case const_call(type, name, nil) do
              {:ok, {_type, cname, _value}} -> {:ok, cname}
              :error -> :error
            end
          end

          @doc """
          Retrieve the value of a constant, identified by `type` and `name`.
          """
          @spec by_name(atom(), atom()) :: {:ok, term()} | :error
          def by_name(type, name) when is_atom(type) do
            case const_call(type, name, nil) do
              {:ok, {_type, _name, value}} -> {:ok, value}
              :error -> :error
            end
          end

          @doc """
          Retrieve the name of a constant, identified by `type` and `value`.
          """
          @spec by_value(atom(), term()) :: {:ok, atom()} | :error
          def by_value(type, value) when is_atom(type) do
            case const_call(type, nil, value) do
              {:ok, {_type, name, _value}} -> {:ok, name}
              :error -> :error
            end
          end

          @doc """
          Assert that the given constant is defined. This function returns the name of the constant.
          If the constant does not exist, the call will raise.
          """
          @spec assert_name!(atom(), atom()) :: atom()
          def assert_name!(type, name) when is_atom(type) do
            case const_call(type, name, nil) do
              {:ok, {_type, cname, _value}} ->
                cname

              :error ->
                raise @constants_exception,
                      "Unknown constant for: type \"#{type}\", name \"#{inspect(name)}\""
            end
          end

          @doc """
          Retrieve the value of a constant, identified by `type` and `name`.
          If the constant does not exist, the call will raise.
          """
          @spec by_name!(atom(), atom()) :: term()
          def by_name!(type, name) when is_atom(type) do
            case const_call(type, name, nil) do
              {:ok, {_type, _name, value}} ->
                value

              :error ->
                raise @constants_exception,
                      "Unknown constant for: type \"#{type}\", name \"#{inspect(name)}\""
            end
          end

          @doc """
          Retrieve the name of a constant, identified by `type` and `value`.
          If the constant does not exist, the call will raise.
          """
          @spec by_value!(atom(), term()) :: atom()
          def by_value!(type, value) when is_atom(type) do
            case const_call(type, nil, value) do
              {:ok, {_type, name, _value}} ->
                name

              :error ->
                raise @constants_exception,
                      "Unknown constant for: type \"#{type}\", value \"#{inspect(value)}\""
            end
          end

          @doc """
          Same as `assert_name!/2`, but as compile-time macro.

          As this is a macro, this can be used to compile the constant name into the resulting BEAM,
          asserting the constant exists.
          """
          defmacro macro_assert_name(type, name) do
            cname = assert_name!(type, name)

            quote do
              unquote(cname)
            end
          end

          @doc """
          Same as `by_name!/2`, but as compile-time macro.

          As this is a macro, this can be used to compile the constant value into the resulting BEAM.
          """
          defmacro macro_by_name(type, name) do
            value = by_name!(type, name)

            quote do
              unquote(value)
            end
          end

          @doc """
          Same as `by_value!/2`, but as compile-time macro.

          As this is a macro, this can be used to compile the constant name into the resulting BEAM.
          """
          defmacro macro_by_value(type, value) do
            name = by_value!(type, value)

            quote do
              unquote(name)
            end
          end

          constant_generate_docs()
        end
      end

    [generated_const_call, generated_rest]
  end

  @doc """
  Define a constant by type, name and value.
  """
  @spec defconstant(atom(), atom(), term()) :: Macro.t()
  defmacro defconstant(type, name, value) when is_atom(type) and is_atom(name) do
    quote do
      if Module.get_attribute(__MODULE__, :constants_typedoc_copy) and
           not Module.has_attribute?(__MODULE__, :ctypedoc) do
        Module.put_attribute(__MODULE__, :ctypedoc, Module.get_attribute(__MODULE__, :constdoc))
      end

      @constants {unquote(type), unquote(name), unquote(value),
                  Module.get_attribute(__MODULE__, :constdoc),
                  Module.get_attribute(__MODULE__, :ctypedoc)}

      Module.delete_attribute(__MODULE__, :constdoc)
      Module.delete_attribute(__MODULE__, :ctypedoc)
    end
  end

  @doc """
  Define a constant forward to constants defined in another module.

  This will allow to use the functions and macros in this module to
  access the constants in the other module.
  """
  @spec defconstforward(module(), atom()) :: Macro.t()
  defmacro defconstforward(module, type) do
    short_module = Macro.expand(module, __CALLER__)

    actual_module =
      case Code.ensure_compiled(short_module) do
        {:module, _mod} ->
          short_module

        {:error, _term} ->
          # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
          full_module = Module.concat([__CALLER__.module, short_module])

          Code.ensure_compiled!(full_module)
          full_module
      end

    actual_type = Macro.expand(type, __CALLER__)

    unless is_atom(actual_type) do
      raise ArgumentError, "Type must be an atom, got: #{inspect(actual_type)}"
    end

    unless function_exported?(actual_module, :get_constants_docs, 0) do
      raise ArgumentError,
            "Module #{actual_module} does not export function get_constants_docs/0, " <>
              "make sure the module does use the module #{__MODULE__}"
    end

    constants_table = actual_module.get_constants_docs()

    quote location: :keep do
      # _safe means the function does not raise, but returns default value
      @doc false
      def by_name_safe(unquote(type), name, default) when is_atom(name) do
        unquote(actual_module).by_name_safe(unquote(type), name, default)
      end

      # _safe means the function does not raise, but returns default value
      @doc false
      def by_value_safe(unquote(type), value, default) do
        unquote(actual_module).by_value_safe(unquote(type), value, default)
      end

      @doc false
      def has_by_name(unquote(type), name) do
        unquote(actual_module).has_by_name(unquote(type), name)
      end

      @doc false
      def has_by_value(unquote(type), value) do
        unquote(actual_module).has_by_value(unquote(type), value)
      end

      @doc false
      def assert_name(unquote(type), name) when is_atom(name) do
        unquote(actual_module).assert_name(unquote(type), name)
      end

      @doc false
      def by_name(unquote(type), name) when is_atom(name) do
        unquote(actual_module).by_name(unquote(type), name)
      end

      @doc false
      def by_value(unquote(type), value) do
        unquote(actual_module).by_value(unquote(type), value)
      end

      @doc false
      def assert_name!(unquote(type), name) when is_atom(name) do
        unquote(actual_module).assert_name!(unquote(type), name)
      end

      @doc false
      def by_name!(unquote(type), name) when is_atom(name) do
        unquote(actual_module).by_name!(unquote(type), name)
      end

      @doc false
      def by_value!(unquote(type), value) do
        unquote(actual_module).by_value!(unquote(type), value)
      end

      @doc false
      defmacro macro_assert_name(unquote(type), name) do
        res = unquote(actual_module).assert_name!(unquote(type), Macro.expand(name, __CALLER__))

        quote do
          unquote(res)
        end
      end

      @doc false
      defmacro macro_by_name(unquote(type), name) do
        res = unquote(actual_module).by_name!(unquote(type), Macro.expand(name, __CALLER__))

        quote do
          unquote(res)
        end
      end

      @doc false
      defmacro macro_by_value(unquote(type), value) do
        res = unquote(actual_module).by_value!(unquote(type), Macro.expand(value, __CALLER__))

        quote do
          unquote(res)
        end
      end

      if not Enum.member?(@docs_chunk_modules, unquote(actual_module)) do
        @constants_docs_chunk unquote(constants_table)
        @docs_chunk_modules unquote(actual_module)
      end
    end
  end

  @doc false
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defmacro constant_generate_docs() do
    caller = __CALLER__.module
    constants = Module.get_attribute(caller, :constants)

    needs_grouping = calculate_needs_grouping(constants, nil)
    moduledoc = Module.get_attribute(caller, :constants_moduledoc)
    no_types = Module.get_attribute(caller, :constants_no_types, false)

    grouped_constants =
      if needs_grouping do
        Enum.group_by(constants, fn {type, _name, _value, _cdoc, _tdoc} -> type end)
      else
        case constants do
          [{type, _name, _value, _cdoc, _tdoc} | _tl] -> %{type => constants}
          _term -> %{}
        end
      end

    {local_typespecs, constants_table_own} =
      grouped_constants
      |> Task.async_stream(
        fn {type, group} ->
          name =
            type
            |> Atom.to_string()
            |> String.split("_")
            |> Enum.map_join(" ", &String.capitalize/1)

          # true = no docs (no constant and no type)
          constant_description =
            Enum.find_value(group, fn
              {_type, _name, _value, false, _tdoc} -> true
              {_type, _name, _value, cdoc, _tdoc} when not is_nil(cdoc) -> "\n\n" <> cdoc
              _else -> false
            end) || ""

          # true = no docs (no type)
          type_description =
            Enum.find_value(group, fn
              {_type, _name, _value, _cdoc, false} -> true
              {_type, _name, _value, _cdoc, tdoc} when not is_nil(tdoc) -> tdoc
              _else -> false
            end)

          if constant_description == true do
            nil
          else
            header = """
            ### Constants: #{name} #{constant_description}

            Type: `:#{type}`

            | Name                         | Value     | Value Bin | Value Hex |
            |------------------------------|-----------|-----------|-----------|
            """

            {table, specs} =
              group
              |> Enum.sort_by(fn {_type, name, _value, _cdoc, _tdoc} -> name end)
              |> Enum.reduce({"", %{}}, fn {_type, name, value, _cdoc, _tdoc}, {tab, specs} ->
                {binary_val, hex_val} =
                  if is_integer(value) do
                    binary = Integer.to_string(value, 2)
                    hex = Integer.to_string(value, 16)
                    {"`0b#{binary}`", "`0x#{hex}`"}
                  else
                    {"-", "-"}
                  end

                new_tab = tab <> "| #{name} | #{value} | #{binary_val} | #{hex_val} |\n"

                type =
                  if type_description != false and type_description != true and not no_types do
                    default = {[name], [value], type_description}

                    Map.update(specs, type, default, fn {old_name, old_value, doc} ->
                      {[name | old_name], [value | old_value], doc}
                    end)
                  else
                    specs
                  end

                {new_tab, type}
              end)

            {specs, {type, header <> String.trim_trailing(table)}}
          end
        end,
        ordered: false,
        timeout: 30_000
      )
      |> Enum.reduce({%{}, []}, fn
        {:ok, nil}, acc -> acc
        {:ok, {specs, table}}, {mapacc, listacc} -> {Map.merge(mapacc, specs), [table | listacc]}
      end)

    typespecs =
      caller
      |> Module.get_attribute(:docs_chunk_modules, [])
      |> Enum.reduce(local_typespecs, fn module, acc ->
        Map.merge(acc, module.get_typespecs())
      end)

    typespecs_types =
      if not no_types do
        generate_types(typespecs, Module.get_attribute(caller, :constants_typespecs_values))
      end

    quote location: :keep do
      if unquote(moduledoc) do
        docs_chunks = Module.get_attribute(__MODULE__, :constants_docs_chunk)

        constants_table =
          (unquote(constants_table_own) ++ docs_chunks)
          |> List.flatten()
          |> Enum.sort_by(fn {type, _doc} -> type end)
          |> Enum.map_join("\n\n", fn {_type, doc} -> doc end)

        if Module.get_attribute(__MODULE__, :moduledoc, nil) do
          old_doc = @moduledoc

          @moduledoc """
          #{old_doc}

          #{constants_table}
          """
        else
          @moduledoc constants_table
        end
      end

      @doc false
      def get_constants_docs(), do: unquote(constants_table_own)

      @doc false
      def get_typespecs(), do: unquote(Macro.escape(typespecs))

      if unquote(moduledoc) and not unquote(no_types) do
        unquote(typespecs_types)
      end
    end
  end

  defp generate_types(typespecs, generate_values_type) do
    Enum.map(typespecs, fn {typename, {specs_name, specs_value, typedoc}} ->
      # credo:disable-for-lines:3 Credo.Check.Warning.UnsafeToAtom
      type_name = :"#{typename}"
      type_value = :"#{typename}_value"

      typespecs_name =
        specs_name
        |> Enum.sort(:desc)
        |> Enum.reduce(nil, fn
          name, nil -> name
          name, acc -> {:|, [], [name, acc]}
        end)

      typespecs_value =
        specs_value
        |> Enum.sort(:desc)
        |> Enum.reduce(nil, fn
          value, nil -> value
          value, acc -> {:|, [], [value, acc]}
        end)

      if generate_values_type do
        quote do
          if unquote(typedoc) != nil and unquote(typedoc) != "" do
            @typedoc unquote(typedoc)
          end

          @type unquote({type_name, [], nil}) :: unquote(typespecs_name)

          if unquote(typedoc) != nil and unquote(typedoc) != "" do
            @typedoc unquote(typedoc)
          end

          @type unquote({type_value, [], nil}) :: unquote(typespecs_value)
        end
      else
        quote do
          if unquote(typedoc) != nil and unquote(typedoc) != "" do
            @typedoc unquote(typedoc)
          end

          @type unquote({type_name, [], nil}) :: unquote(typespecs_name)
        end
      end
    end)
  end

  # The typedstruct macro has been copied and slightly adjusted
  # Original author: https://dorgan.ar/posts/2021/04/the_elixir_ast_typedstruct/

  @doc """
  Generate a typed struct. It defines `defstruct`, `@enforce_keys` and `@type t`.

  Example:
  ```elixir
  defmodule Report do
    @type report_type :: :refactoring | :warning | :consistency

    # required? is by default true
    typedstruct do
      field :type, report_type, default: :refactoring
      field :description, String.t
      field :message, String.t, required: false
    end
  end
  ```
  """
  defmacro typedstruct(do_block)

  defmacro typedstruct(do: ast) do
    fields_ast =
      case ast do
        {:__block__, _meta, fields} -> fields
        field -> [field]
      end

    fields_data = Enum.map(fields_ast, &get_field_data/1)

    enforced_fields =
      for field <- fields_data, field.required do
        field.name
      end

    typespecs =
      Enum.map(fields_data, fn
        %{name: name, typespec: typespec, required: true} ->
          {name, typespec}

        %{name: name, typespec: typespec} ->
          {
            name,
            {:|, [], [typespec, nil]}
          }
      end)

    fields =
      for %{name: name, default: default} <- fields_data do
        {name, default}
      end

    quote generated: true, location: :keep do
      @type t :: %__MODULE__{unquote_splicing(typespecs)}
      @enforce_keys unquote(enforced_fields)
      defstruct unquote(fields)
    end
  end

  @doc """
  Same as `typedstruct/1`, but `@opaque` gets generated.
  """
  defmacro opaquedstruct(do_block)

  defmacro opaquedstruct(do: ast) do
    fields_ast =
      case ast do
        {:__block__, _meta, fields} -> fields
        field -> [field]
      end

    fields_data = Enum.map(fields_ast, &get_field_data/1)

    enforced_fields =
      for field <- fields_data, field.required do
        field.name
      end

    typespecs =
      Enum.map(fields_data, fn
        %{name: name, typespec: typespec, required: true} ->
          {name, typespec}

        %{name: name, typespec: typespec} ->
          {
            name,
            {:|, [], [typespec, nil]}
          }
      end)

    fields =
      for %{name: name, default: default} <- fields_data do
        {name, default}
      end

    quote generated: true, location: :keep do
      @opaque t :: %__MODULE__{unquote_splicing(typespecs)}
      @enforce_keys unquote(enforced_fields)
      defstruct unquote(fields)
    end
  end

  defp get_field_data({:field, _meta, [name, typespec]}) do
    get_field_data({:field, [], [name, typespec, []]})
  end

  defp get_field_data({:field, _meta, [name, typespec, opts]}) do
    default = Keyword.get(opts, :default)
    required = Keyword.get(opts, :required, false)

    %{
      name: name,
      typespec: typespec,
      default: default,
      required: required
    }
  end

  defp calculate_needs_grouping([], _type), do: false

  defp calculate_needs_grouping([{type, _name, _value, _doc} | tail], nil) do
    calculate_needs_grouping(tail, type)
  end

  defp calculate_needs_grouping([{type, _name, _value, _doc} | tail], type) do
    calculate_needs_grouping(tail, type)
  end

  defp calculate_needs_grouping(_list, _type) do
    true
  end
end
