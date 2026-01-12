defmodule BACnet.BeamTypes do
  @moduledoc """
  Contains functions to resolve typespecs and types from BEAM bytecode
  into a type declaration and functions to validate those types against values.

  During compilation, it uses a compilation tracer (as configured in the bacstack Mix Project)
  to track fresh compiled modules and stores them in persistent term for lookup later.

  The types are mostly used for BACnet object type declarations, where those types are
  at compile-time resolved, so compilation tracing is a huge need for development.
  Modules that have not changed and are not compiled, are read from the BEAM file.

  The module `BACnet.Protocol.ObjectsMacro` and `BACnet.Protocol.ObjectsUtility` use this
  module to resolve and validate types accurately to the need of ASHRAE 135 BACnet specification.
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.Constants

  @typedoc """
  Valid type checker types. This is mostly used for BACnet object properties.

  Following types are supported:
  - `nil` - `nil`
  - `:any` - `any()`/`term()`
  - `:boolean` - `boolean()`
  - `:string` - `String.t()`
  - `:octet_string` - `binary()`
  - `:signed_integer` - `integer()`
  - `:unsigned_integer` - `non_neg_integer()`
  - `:real` - `float()`, also allowing `:NaN`, `:inf`, `:infn`
  - `:double` - value check same as `:real` (for `bac_object/2`, this type must be explicitely specified)
  - `:bitstring` - tuple of booleans
  - `{:array, subtype}` (validates a `BACnetArray` and every value of it being of `subtype`)
  - `{:array, subtype, fixed_size}` (validates a `BACnetArray` with fixed size of `fixed_size` and every value of it being of `subtype`)
  - `{:constant, type}` - `Constants.type()`
  - `{:in_list, values}`
  - `{:in_range, low, high}` - `x..y`
  - `{:list, type}` - `[type()]`
  - `{:literal, value_check}` (checks if `value` equals to `value_check` using the match `===/2` operator)
  - `{:struct, module}` (calls the module's `valid?/1` function, if exported)
  - `{:tuple, [type]}` (checks in sequence if the tuple element matches to the type in the same index)
  - `{:type_list, [type]}` - `type_a()|type_b()` (checks if the value passes one of the type checks in `types` list)
  - `{:with_validator, type, (term() -> boolean())}` - First checks the type and then calls the validator function.
  - `{:with_validator, type, validator_function_ast}` - First checks the type and then calls the validator function,
     which is AST that gets first evaluated and then called with the value. The AST must evaluate to a single arity function.
  """
  @type typechecker_types ::
          nil
          | :any
          | :boolean
          | :string
          | :octet_string
          | :signed_integer
          | :unsigned_integer
          | :real
          | :double
          | :bitstring
          | {:array, typechecker_types()}
          | {:array, typechecker_types(), pos_integer()}
          | {:constant, atom()}
          | {:in_list, term()}
          | {:in_range, integer(), integer()}
          | {:list, typechecker_types()}
          | {:literal, term()}
          | {:struct, module()}
          | {:tuple, [typechecker_types()]}
          | {:type_list, [typechecker_types()]}
          | {:with_validator, typechecker_types(), (term() -> boolean())}
          | {:with_validator, typechecker_types(), Macro.t()}

  @doc """
  Checks the type of value and verifies more complex type it is of the same type as the given type.
  """
  @spec check_type(typechecker_types(), term()) :: boolean()
  def check_type(type, value)

  def check_type(nil, nil), do: true
  def check_type(nil, _value), do: false

  def check_type(:any, _value), do: true

  def check_type(:boolean, value) when is_boolean(value), do: true
  def check_type(:boolean, _value), do: false

  def check_type(:string, value) when is_binary(value), do: true
  def check_type(:string, _value), do: false

  def check_type(:octet_string, value) when is_binary(value), do: true
  def check_type(:octet_string, _value), do: false

  def check_type(:signed_integer, value) when is_integer(value), do: true
  def check_type(:signed_integer, _value), do: false

  def check_type(:unsigned_integer, value)
      when is_integer(value) and value >= 0,
      do: true

  def check_type(:unsigned_integer, _value), do: false

  def check_type(:real, value) when is_float(value), do: true
  def check_type(:real, value) when value in [:NaN, :inf, :infn], do: true
  def check_type(:real, _value), do: false

  def check_type(:double, value) when is_float(value), do: true
  def check_type(:double, value) when value in [:NaN, :inf, :infn], do: true
  def check_type(:double, _value), do: false

  def check_type(:bitstring, value) when is_tuple(value) do
    value
    |> Tuple.to_list()
    |> Enum.all?(&is_boolean/1)
  end

  def check_type(:bitstring, _value), do: false

  def check_type({:array, subtype}, value) do
    if is_struct(value, BACnetArray) do
      subtype == :any or
        BACnetArray.reduce_while(value, true, fn item, _acc ->
          if check_type(subtype, item) do
            {:cont, true}
          else
            {:halt, false}
          end
        end)
    else
      false
    end
  end

  def check_type(
        {:array, subtype, fixed_size},
        %BACnetArray{fixed_size: fixed_size2} = value
      )
      when is_integer(fixed_size) and fixed_size >= 1 and fixed_size == fixed_size2 do
    check_type({:array, subtype}, value)
  end

  def check_type({:array, _subtype, fixed_size}, _value)
      when is_integer(fixed_size) and fixed_size >= 1,
      do: false

  def check_type({:constant, type}, value) when is_atom(value),
    do: Constants.has_by_name(type, value)

  def check_type({:in_list, values}, value) when is_list(values) do
    value in values
  end

  def check_type({:in_range, low, high}, value) do
    is_integer(value) and value >= low and value <= high
  end

  def check_type({:list, _type}, []), do: true

  def check_type({:list, type}, value) when is_list(value) do
    if Enumerable.impl_for(value) do
      Enum.all?(value, &check_type(type, &1))
    else
      false
    end
  end

  def check_type({:list, _type}, _value), do: false

  def check_type({:literal, eq}, value), do: value === eq

  def check_type({:tuple, subtypes}, value) when is_tuple(value) do
    if length(subtypes) == tuple_size(value) do
      subtypes
      |> Enum.with_index()
      |> Enum.all?(fn {spec, index} ->
        check_type(spec, elem(value, index))
      end)
    else
      false
    end
  end

  def check_type({:tuple, _subtypes}, _value), do: false

  def check_type({:struct, type}, value) when is_struct(value, type) do
    if function_exported?(type, :valid?, 1) do
      type.valid?(value)
    else
      true
    end
  end

  def check_type({:struct, _type}, _value), do: false

  def check_type({:type_list, types}, value) when is_list(types) do
    Enum.any?(types, &check_type(&1, value))
  end

  def check_type({:with_validator, type, validator}, value) when is_function(validator, 1) do
    if check_type(type, value) do
      validator.(value)
    else
      false
    end
  end

  def check_type({:with_validator, type, validator_ast}, value) do
    {validator, _bind} = Code.eval_quoted(validator_ast, [], __ENV__)
    check_type({:with_validator, type, validator}, value)
  end

  def check_type(type, _value), do: raise("Unknown type: #{inspect(type)}")

  @doc """
  Generates `valid?/1` clause body based on the given module's `:t` typespec,
  it must reference a struct.
  """
  @spec generate_valid_clause(module(), Macro.Env.t()) :: Macro.t()
  def generate_valid_clause(module, env) when is_atom(module) do
    validation = resolve_struct_type(module, :t, env)

    if map_size(validation) == 0 do
      quote do
        true
      end
    else
      var = Macro.var(:t, env.module)

      validation
      |> Enum.map(fn {field, type} ->
        quote do
          unquote(__MODULE__).check_type(unquote(Macro.escape(type)), unquote(var).unquote(field))
        end
      end)
      |> Enum.reduce(fn expr1, acc ->
        quote do
          unquote(acc) and unquote(expr1)
        end
      end)
    end
  end

  @doc """
  Resolves an AST type to something `check_type/2` works with.
  """
  @spec resolve_type(Macro.t(), Macro.Env.t()) :: term()
  def resolve_type(type, env) do
    field_typespec_to_bactype(type, env, %{})
  end

  @doc """
  Resolves a type (struct) to a map of fields to typespecs (`resolve_type/2`-like).

  This function only works with BACnet data structures and not with types, such as
  exposed by the module `ApplicationTags`. Since `tuples` are used in that module to
  structure data together, `tuples` are used in BACnet data structures as bitstrings
  (as seen in `ApplicationTags` bitstrings).
  As such wrong typespecs will be generated and cannot be used for validation.

  For structs that do not define any fields, an empty map will be returned.

  Tuple types such as `{binary(), integer()}` will be resolved to `{:tuple, [:octet_string, :integer]}`.

  ```elixir
  iex(1)> resolve_struct_type(BACnet.Protocol.EventParameters.ChangeOfBitstring, :t, __ENV__)
  %{
    alarm_values: {:list, :bitstring},
    bitmask: :bitstring,
    time_delay: :unsigned_integer,
    time_delay_normal: {:type_list, [:unsigned_integer, {:literal, nil}]}
  }
  ```

  Available options:
  - `ignore_underlined_keys: boolean()` - Ignores/skips keys starting with `_`, as such the
    resolved types will exclude types for underline-prefixed keys.
  """
  @spec resolve_struct_type(module(), atom(), Macro.Env.t(), Keyword.t()) :: map()
  def resolve_struct_type(module, type, env, opts \\ []) do
    Code.ensure_compiled!(module)
    beam = get_beam_entity_for_module(module, env)

    # Add spec_module, so we may be able to get it in some non-BEAM specific function
    opts_map =
      opts
      |> Map.new()
      |> Map.put(:spec_module, module)

    ignore_underlined_keys = opts_map[:ignore_underlined_keys] == true

    result =
      case parse_beam_module_for_typespec(module, type, beam, env) do
        {:type, _line, :map, fields} ->
          fields
          |> Map.new(fn
            {:type, _line, :map_field_exact, [{:atom, 0, :__struct__}, {:atom, 0, ^module}]} ->
              {:__drop__, nil}

            {:type, _line, :map_field_exact, [{:atom, 0, key}, spec]} ->
              if ignore_underlined_keys and String.starts_with?(Atom.to_string(key), "_") do
                {:__drop__, nil}
              else
                {key, map_beam_typespec_data(spec, env, module, opts_map)}
              end

            _else ->
              {:__drop__, nil}
          end)
          |> Map.delete(:__drop__)

        _term ->
          raise CompileError,
            description: "Type #{module}.#{type} does not export the type as struct",
            file: env.file,
            line: env.line
      end

    result
  end

  # List of something (i.e. primitive type, struct)
  defp field_typespec_to_bactype(
         [ast],
         env,
         opts
       ) do
    {:list, field_typespec_to_bactype(ast, env, opts)}
  end

  # No type checking - this is an internal struct field
  defp field_typespec_to_bactype({:internal_metadata, _list, []}, _env, _opts) do
    nil
  end

  defp field_typespec_to_bactype(type, _env, _opts) when is_atom(type) do
    type
  end

  # Catch unsupported generic types (those we know so far)
  defp field_typespec_to_bactype({type, _any, []}, env, _opts) when type in [:map] do
    raise CompileError,
      description: "Type #{type} is not supported",
      file: env.file,
      line: env.line
  end

  # Special handling for some types
  defp field_typespec_to_bactype({:integer, _any, []}, _env, _opts) do
    :signed_integer
  end

  defp field_typespec_to_bactype({:pos_integer, _any, []}, _env, _opts) do
    # pos_integer means non_neg_integer but starting from 1
    # so we need a validator (in AST form)
    validator =
      quote do
        &(is_integer(&1) and &1 >= 1)
      end

    {:with_validator, :unsigned_integer, validator}
  end

  defp field_typespec_to_bactype({:non_neg_integer, _any, []}, _env, _opts) do
    :unsigned_integer
  end

  defp field_typespec_to_bactype({:float, _any, []}, _env, _opts) do
    :real
  end

  # defp field_typespec_to_bactype({:boolean, _any, []}, _env, _opts) do
  #   # bac_type for boolean in a context-specified tag
  #   # is enumerated, not boolean
  #   :enumerated
  # end

  # Special handling for :binary (which is :octet_string)
  # String.t() gets mapped to :string (= character_string)
  defp field_typespec_to_bactype({:binary, _any, []}, _env, _opts) do
    :octet_string
  end

  # Map term() to any()
  defp field_typespec_to_bactype({:term, _any, []}, _env, _opts) do
    :any
  end

  # Map tuple() to bitstring()
  defp field_typespec_to_bactype({:tuple, _any, []}, _env, _opts) do
    :bitstring
  end

  defp field_typespec_to_bactype({type, _any, []}, _env, _opts) when is_atom(type) do
    type
  end

  # Range expression x..y
  defp field_typespec_to_bactype({:.., _list, [value1, value2]}, _env, _opts) do
    {:in_range, value1, value2}
  end

  # Range expression x..y//z
  defp field_typespec_to_bactype({:.., _list, [value1, value2, step]}, _env, _opts) do
    {:in_list, Enum.to_list(value1..value2//step)}
  end

  # OR expression (i.e. "String.t() | nil")
  defp field_typespec_to_bactype({:|, _list, values}, env, opts) when is_list(values) do
    {:type_list, Enum.map(values, &field_typespec_to_bactype(&1, env, opts))}
  end

  # Special handling for String.t() (which is :string)
  defp field_typespec_to_bactype(
         {{:., _any3, [{:__aliases__, _alias, [:String]}, :t]}, _any, _any2},
         _env,
         _opts
       ) do
    :string
  end

  # Remote type (such as Date.t), resolve it based on type
  defp field_typespec_to_bactype(
         {{:., _any3, [ast, type]}, _any, params},
         env,
         opts
       )
       when is_atom(type) do
    module = Macro.expand(ast, env)
    Code.ensure_compiled!(module)

    # Decide the code path
    cond do
      # Application Tags encoding - ApplicationTags.encoding()
      module == ApplicationTags and type == :encoding ->
        :any

      # IEEE754 floats - ApplicationTags.ieee_float()
      module == ApplicationTags and type == :ieee_float ->
        :real

      # Unsigned 8bit - ApplicationTags.unsigned8()
      module == ApplicationTags and type == :unsigned8 ->
        validator =
          quote do
            &(is_integer(&1) and &1 >= 0 and &1 <= 255)
          end

        {:with_validator, :unsigned_integer, validator}

      # Unsigned 16bit - ApplicationTags.unsigned16()
      module == ApplicationTags and type == :unsigned16 ->
        validator =
          quote do
            &(is_integer(&1) and &1 >= 0 and &1 <= 65_535)
          end

        {:with_validator, :unsigned_integer, validator}

      # Unsigned 32bit - ApplicationTags.unsigned32()
      module == ApplicationTags and type == :unsigned32 ->
        validator =
          quote do
            &(is_integer(&1) and &1 >= 0 and &1 <= 4_294_967_295)
          end

        {:with_validator, :unsigned_integer, validator}

      # BACnet Array
      module == BACnetArray and type == :t ->
        case params do
          # BACnetArray.t() - Error as no subtype (we require a subtype)
          [] ->
            raise CompileError,
              description: "BACnetArray must have a subtype",
              file: env.file,
              line: env.line

          # BACnet.Array.t(subtype)
          [subtype] ->
            {:array, field_typespec_to_bactype(subtype, env, opts)}

          # BACnet.Array.t(subtype, fixed_size)
          [subtype, fixed_size] when is_integer(fixed_size) ->
            {:array, field_typespec_to_bactype(subtype, env, opts), fixed_size}

          # BACnet.Array.t(subtype, fixed_size) - ignore size if not integer (may be a subtype)
          [subtype, _size] ->
            {:array, field_typespec_to_bactype(subtype, env, opts)}

          # BACnet.Array.t(...) - Error as more than a single parameter (subtype)
          _term ->
            raise CompileError,
              description: "BACnetArray must have a single parameter",
              file: env.file,
              line: env.line
        end

      # Constants.type() (BACnet constants)
      module == Constants ->
        {:constant, type}

      # Remote type (such as Date.t), fetch the type and transform it
      true ->
        beam = get_beam_entity_for_module(module, env)
        parse_beam_module_for_types(module, type, beam, env, opts)
    end
  end

  # Catch BEAM typespecs as they may fall through from map_beam_typespec_data/4

  defp field_typespec_to_bactype({:remote_type, _line, _spec} = spec, env, opts) do
    map_beam_typespec_data(spec, env, opts[:spec_module], opts)
  end

  defp field_typespec_to_bactype({:type, _line, _type, _args} = spec, env, opts) do
    map_beam_typespec_data(spec, env, opts[:spec_module], opts)
  end

  defp field_typespec_to_bactype({:user_type, _line, _name, _spec} = spec, env, opts) do
    map_beam_typespec_data(spec, env, opts[:spec_module], opts)
  end

  defp parse_beam_module_for_types(module, type, beam, env, opts) do
    module
    |> parse_beam_module_for_typespec(type, beam, env)
    |> map_beam_typespec_data(env, module, opts)
  end

  defp parse_beam_module_for_typespec(module, type, beam, env) do
    with {:ok, {_module, [{:abstract_code, {:raw_abstract_v1, attributes}}]}} <-
           :beam_lib.chunks(beam, [:abstract_code]),
         raw_types =
           attributes
           |> Enum.filter(fn
             {:attribute, _any, :type, _types} -> true
             _attribute -> false
           end)
           |> Enum.map(fn {:attribute, _any, :type, types} -> types end),
         typespec when is_tuple(typespec) <-
           Enum.find_value(raw_types, fn
             {^type, value, _any} -> value
             _term -> false
           end) do
      typespec
    else
      _term ->
        raise CompileError,
          description: "Unable to resolve type \"#{inspect(module)}.#{type}\"",
          file: env.file,
          line: env.line
    end
  end

  # Annotated remote type (such as rest :: String.t())
  defp map_beam_typespec_data(
         {:ann_type, _line, [{:var, _line2, _name}, {:remote_type, _line3, _type} = spec]},
         env,
         spec_module,
         opts
       ) do
    map_beam_typespec_data(
      spec,
      env,
      spec_module,
      opts
    )
  end

  # Annotated generic type (such as rest :: list())
  defp map_beam_typespec_data(
         {:ann_type, _line, [{:var, _line2, _name}, {:type, _line3, _type, _args} = spec]},
         env,
         spec_module,
         opts
       ) do
    map_beam_typespec_data(
      spec,
      env,
      spec_module,
      opts
    )
  end

  # Remote type (such as String.t)
  defp map_beam_typespec_data(
         {:remote_type, _line, [{:atom, 0, module}, {:atom, 0, type}, args]},
         env,
         _spec_module,
         opts
       ) do
    field_typespec_to_bactype(
      {{:., [], [module, type]}, [], args},
      env,
      opts
    )
  end

  # OR expression
  defp map_beam_typespec_data({:type, _line, :union, union}, env, spec_module, opts) do
    types =
      Enum.map(union, fn
        {:ann_type, _line, [{:var, _line2, _name}, {:remote_type, _line3, _type} = spec]} ->
          map_beam_typespec_data(spec, env, spec_module, opts)

        {:ann_type, _line, [{:var, _line2, _name}, {:type, _line3, _type, _args} = spec]} ->
          map_beam_typespec_data(spec, env, spec_module, opts)

        {:atom, 0, atom_name} ->
          {:literal, atom_name}

        {:remote_type, _line, [{:atom, 0, module}, {:atom, 0, type}, args]} ->
          field_typespec_to_bactype(
            {{:., [], [module, type]}, [], args},
            env,
            opts
          )

        {:type, _line, _type, _spec} = type ->
          map_beam_typespec_data(type, env, spec_module, opts)

        {:user_type, _line, type, args} ->
          field_typespec_to_bactype(
            {{:., [], [spec_module, type]}, [], args},
            env,
            opts
          )

        # Variables, may be anything
        {:var, _line, _name} ->
          :any

        term ->
          raise "Unknown how to handle BEAM typespec (from union: #{inspect(union)}, from module: #{inspect(spec_module)}): #{inspect(term)}"
      end)

    {:type_list, types}
  end

  # Map typespec (structs count as this)
  defp map_beam_typespec_data({:type, _line, :map, definition}, env, _spec_module, _opts) do
    # Check if it's a struct, if so, return the module name
    module =
      Enum.find_value(definition, fn
        {:type, _line, :map_field_exact, [{:atom, 0, :__struct__}, {:atom, 0, module}]} -> module
        _term -> false
      end)

    if module do
      {:struct, module}
    else
      raise CompileError,
        description: "Only structs are allowed as typespec, plain maps are not supported",
        file: env.file,
        line: env.line
    end
  end

  # List type (i.e. [tuple()])
  defp map_beam_typespec_data({:type, _line, :list, [type]}, env, spec_module, opts) do
    {:list, map_beam_typespec_data(type, env, spec_module, opts)}
  end

  # Generic type (such as boolean, integer, float, etc.)
  defp map_beam_typespec_data({:type, _line, subtype, subtypes}, env, _spec_module, opts)
       when subtypes == [] or subtypes == :any do
    field_typespec_to_bactype({subtype, [], []}, env, opts)
  end

  # Ranges x..y (where did these spawn from in BEAM?)
  defp map_beam_typespec_data(
         {:type, _line, :range, [{:integer, _any, min}, {:integer, _any2, max}]},
         _env,
         _spec_module,
         _opts
       ) do
    {:in_range, min, max}
  end

  defp map_beam_typespec_data({:type, _line, subtype, subtypes}, env, spec_module, opts)
       when is_list(subtypes) do
    subtypes =
      Enum.map(subtypes, fn
        {:ann_type, _num, [_var, spec]} -> map_beam_typespec_data(spec, env, spec_module, opts)
        {:atom, _num, name} -> {:literal, name}
        {:integer, _num, number} -> {:literal, number}
        spec -> map_beam_typespec_data(spec, env, spec_module, opts)
      end)

    {subtype, subtypes}
  end

  # Custom local types
  defp map_beam_typespec_data(
         {:user_type, _line, type, args},
         env,
         module,
         opts
       ) do
    field_typespec_to_bactype(
      {{:., [], [module, type]}, [], args},
      env,
      opts
    )
  end

  defp get_beam_entity_for_module(module, env) do
    # Find the bytecode in our compilation tracer, if not available,
    # check if the BEAM file exists and use it instead

    case :persistent_term.get(module, nil) do
      nil ->
        # If we don't have it "cached", try to get it through
        # :code.get_object_code/1, if it fails,
        # fallback to finding the BEAM file (which fails for cover compiled)
        case :code.get_object_code(module) do
          {_module, binary, _filename} ->
            binary

          :error ->
            beam_path =
              case :code.which(module) do
                :cover_compiled ->
                  nil

                :non_existing ->
                  nil

                beam_path ->
                  if File.exists?(beam_path) do
                    beam_path
                  end
              end

            if beam_path do
              beam_path
            else
              raise CompileError,
                description:
                  "Missing bytecode for module #{inspect(module)}, unable to lookup types",
                file: env.file,
                line: env.line
            end
        end

      bytecode ->
        bytecode
    end
  end
end
