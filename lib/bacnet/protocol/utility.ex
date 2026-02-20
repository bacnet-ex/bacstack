defmodule BACnet.Protocol.Utility do
  @moduledoc """
  Various utility functions to help with the BACnet protocol.
  """

  alias BACnet.Protocol.ApplicationTags

  @doc """
  Helper function to extract and unfold the tag from a linked list of BACnet application tags.

  Returns `{:ok, value, rest}` if the tag was found and successfully unfolded (if needed to),
  returns `{:error, :missing_pattern}` if tag was not found and is not optional,
  returns `{:error, term}` otherwise. `value` is unwrapped and does not contain the tag tuple,
  if the tag value was unfolded. Otherwise it's the complete tag encoding tuple.

  It also allows to give an anonymous function or capture with arity 1,
  which transforms the complete tag encoding tuple (if found).
  It must return `{:ok, value}` or `{:error, term}`. In case of `:ok`,
  this will be transformed to `{:ok, value, rest}`.
  """
  @spec pattern_extract_tags(
          ApplicationTags.encoding_list(),
          any(),
          ApplicationTags.primitive_type()
          | (ApplicationTags.encoding() -> {:ok, any()} | {:error, any()})
          | nil,
          boolean()
        ) :: Macro.t()
  defmacro pattern_extract_tags(list, pattern, unfold_type, optional) do
    optional_match =
      cond do
        # Variable given
        match?({_varname, _line, _val}, optional) ->
          quote generated: true, location: :keep do
            if unquote(optional) do
              {:ok, nil, unquote(list)}
            else
              {:error, :missing_pattern}
            end
          end

        optional == true ->
          quote generated: true, location: :keep do
            {:ok, nil, unquote(list)}
          end

        true ->
          quote generated: true, location: :keep do
            {:error, :missing_pattern}
          end
      end

    fold_type2 =
      quote generated: true, location: :keep do
        case unquote(unfold_type).(value) do
          {:ok, term} -> {:ok, term, rest}
          {:error, _term} = term -> term
        end
      end

    fold_match =
      cond do
        # Function given (fn or capture operator)
        match?({:fn, _list, _term}, unfold_type) or match?({:&, _list, _term}, unfold_type) ->
          fold_type2

        # Anything else (except nil)
        unfold_type ->
          fold_type1 =
            quote generated: true, location: :keep do
              case ApplicationTags.unfold_to_type(unquote(unfold_type), value) do
                {:ok, {unquote(unfold_type), typed}} -> {:ok, typed, rest}
                {:ok, _term} -> {:error, :invalid_unfolded_value}
                term -> term
              end
            end

          if is_atom(unfold_type) do
            fold_type1
          else
            quote generated: true, location: :keep do
              if is_function(unquote(unfold_type), 1) do
                unquote(fold_type2)
              else
                unquote(fold_type1)
              end
            end
          end

        true ->
          quote generated: true, location: :keep do
            {:ok, value, rest}
          end
      end

    quote generated: true, location: :keep do
      case unquote(list) do
        [unquote(pattern) = value | rest] -> unquote(fold_match)
        _any -> unquote(optional_match)
      end
    end
  end

  def float_validator_fun(value, %{min_present_value: min, max_present_value: max})
      when not is_nil(min) and not is_nil(max) do
    min_ok =
      case min do
        :NaN -> true
        :inf -> false
        :infn -> true
        min when is_float(min) -> min <= value
      end

    max_ok =
      case max do
        :NaN -> true
        :inf -> true
        :infn -> false
        max when is_float(max) -> value <= max
      end

    min_ok and max_ok
  end

  def float_validator_fun(_value, _obj) do
    true
  end
end
