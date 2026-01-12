defmodule BACnet.Protocol.ApplicationTags.Encoding do
  @moduledoc """
  This module should help dealing with application tags encodings in user code, as
  application tags encoding can be more easily dealt with as the values can be accessed directly.
  """

  alias BACnet.Protocol.ApplicationTags

  defmodule Error do
    @moduledoc """
    `ApplicationTags.Encoding` errors.
    """

    defexception [:error, :input, :message]

    def message(%__MODULE__{} = exception) do
      "#{exception.message}, error: #{exception.error}, got: #{inspect(exception.input)}"
    end
  end

  @typedoc """
  Represents application tags encoding with a slightly more enjoyable structure.

  For tagged and constructed encodings, the extras contains `:tag_number`.
  Extras may also contain `:context` and `:encoder`, if passed to `create/2`.
  """
  @type t :: %__MODULE__{
          encoding: :primitive | :tagged | :constructed,
          extras: Keyword.t(),
          type: ApplicationTags.primitive_type() | nil,
          value: term()
        }

  @fields [
    :encoding,
    :extras,
    :type,
    :value
  ]
  @enforce_keys @fields
  defstruct @fields

  @valid_primitive_types [
    :null,
    :boolean,
    :enumerated,
    :unsigned_integer,
    :signed_integer,
    :real,
    :double,
    :date,
    :time,
    :octet_string,
    :character_string,
    :bitstring,
    :object_identifier
  ]

  @typedoc """
  Valid create options. For a description on each option, see `create/2`.
  """
  @type create_option ::
          {:cast_type, ApplicationTags.primitive_type()}
          | {:context, any()}
          | {:encoder, (any() -> {:ok, any()} | {:error, any()} | any())}

  @typedoc """
  List of create options.
  """
  @type create_options :: [create_option()]

  @doc """
  Creates a struct from the application tags encoding.

  Tagged encodings can be optionally casted to primitive types.

  Available options:
  - `cast_type: ApplicationTags.primitive_type()` - Optional. Casts the tagged encoding to the primitive type.
  - `context: any()` - Optional. A user-defined value for matching by the user, untouched by the module.
  - `encoder: (any() -> {:ok, any()} | {:error, any()} | any())`- Optional. An encoder function to use on the value,
    before creating the application tags encoding.
  """
  @spec create(ApplicationTags.encoding(), create_options) :: {:ok, t()} | {:error, term()}
  def create(encoding, opts \\ [])

  def create({type, value}, opts) when type in @valid_primitive_types do
    struc = %__MODULE__{
      encoding: :primitive,
      extras: put_extras([], opts),
      type: type,
      value: value
    }

    {:ok, struc}
  end

  def create({:tagged, {tag_num, value, _len}} = tag, opts) do
    cast_type = Keyword.get(opts, :cast_type)

    with {:ok, {type, new_value}} <-
           (if cast_type do
              ApplicationTags.unfold_to_type(cast_type, tag)
            else
              {:ok, {nil, value}}
            end) do
      struc = %__MODULE__{
        encoding: :tagged,
        extras: put_extras([tag_number: tag_num], opts),
        type: type,
        value: new_value
      }

      {:ok, struc}
    end
  end

  def create({:constructed, {tag_num, {type, value}, 0}}, opts)
      when type in @valid_primitive_types do
    struc = %__MODULE__{
      encoding: :constructed,
      extras: put_extras([tag_number: tag_num], opts),
      type: type,
      value: value
    }

    {:ok, struc}
  end

  def create({:constructed, {tag_num, value, _len}}, opts) do
    struc = %__MODULE__{
      encoding: :constructed,
      extras: put_extras([tag_number: tag_num], opts),
      type: nil,
      value: value
    }

    {:ok, struc}
  end

  def create(_tag, _opts) do
    {:error, :invalid_encoding}
  end

  @doc """
  Bang version of `create/2`.
  """
  @spec create!(ApplicationTags.encoding(), create_options) :: t() | no_return()
  def create!(encoding, opts \\ []) do
    case create(encoding, opts) do
      {:ok, t} ->
        t

      {:error, err} ->
        raise Error, error: err, input: encoding, message: "Failed to create encoding struct"
    end
  end

  @doc """
  Reverses the process and brings it back to its raw form.
  """
  @spec to_encoding(t()) :: {:ok, ApplicationTags.encoding()} | {:error, term()}
  def to_encoding(%__MODULE__{} = t) do
    case Keyword.fetch(t.extras, :encoder) do
      {:ok, encoder} -> run_encoder(t, encoder)
      :error -> do_encoding(t)
    end
  end

  @doc """
  Bang version of `to_encoding/1`.
  """
  @spec to_encoding!(t()) :: ApplicationTags.encoding() | no_return()
  def to_encoding!(t) do
    case to_encoding(t) do
      {:ok, t} ->
        t

      {:error, err} ->
        raise Error, input: t, message: "Failed to transform encoding struct, error: #{err}"
    end
  end

  @spec put_extras(Keyword.t(), Keyword.t()) :: Keyword.t()
  defp put_extras(extras, opts)

  defp put_extras(extras, opts) do
    extras
    |> put_if(opts, :context)
    |> put_if(opts, :encoder)
  end

  defp put_if(extras, opts, key) do
    case Keyword.fetch(opts, key) do
      # Ignore nil values
      {:ok, nil} ->
        extras

      {:ok, value} ->
        # Validate certain key-value pairs
        # credo:disable-for-next-line Credo.Check.Refactor.CondStatements
        cond do
          key == :encoder ->
            unless is_function(value, 1) do
              raise ArgumentError, "Invalid encoder/1 function given, got: #{inspect(value)}"
            end

          true ->
            :ok
        end

        Keyword.put(extras, key, value)

      :error ->
        extras
    end
  end

  @spec run_encoder(t(), (any() -> any())) ::
          {:ok, ApplicationTags.encoding()} | {:error, term()}
  defp run_encoder(t, encoder) do
    with {:ok, new_value} <-
           (case encoder.(t.value) do
              {:ok, val} -> {:ok, val}
              {:error, _err} = err -> err
              val -> {:ok, val}
            end),
         do: do_encoding(%{t | value: new_value, extras: Keyword.drop(t.extras, [:encoder])})
  end

  @spec do_encoding(t()) :: {:ok, ApplicationTags.encoding()} | {:error, term()}
  defp do_encoding(t)

  defp do_encoding(%__MODULE__{encoding: :primitive} = t) do
    {:ok, {t.type, t.value}}
  end

  defp do_encoding(%__MODULE__{encoding: :tagged, type: nil, value: value} = t)
       when is_binary(value) do
    {:ok, {:tagged, {Keyword.fetch!(t.extras, :tag_number), value, byte_size(value)}}}
  end

  defp do_encoding(%__MODULE__{encoding: :tagged, type: nil} = _t) do
    {:error, :invalid_tagged_value}
  end

  defp do_encoding(%__MODULE__{encoding: :tagged} = t) do
    ApplicationTags.create_tag_encoding(Keyword.fetch!(t.extras, :tag_number), t.type, t.value)
  end

  defp do_encoding(%__MODULE__{encoding: :constructed, type: nil, value: value} = t)
       when is_binary(value) do
    {:ok, {:constructed, {Keyword.fetch!(t.extras, :tag_number), value, byte_size(value)}}}
  end

  defp do_encoding(%__MODULE__{encoding: :constructed, type: nil} = t) do
    {:ok, {:constructed, {Keyword.fetch!(t.extras, :tag_number), t.value, 0}}}
  end

  defp do_encoding(%__MODULE__{encoding: :constructed} = t) do
    {:ok, {:constructed, {Keyword.fetch!(t.extras, :tag_number), {t.type, t.value}, 0}}}
  end

  defp do_encoding(%__MODULE__{} = _t) do
    {:error, :invalid_value}
  end
end
