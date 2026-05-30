defmodule BACnet.Protocol.ActionList do
  @moduledoc """
  An Action List is an ordered collection of Action Command structures. It is
  the executable content of a Command object. Each element of the list (accessed
  by array index) represents one complete sequence that the Command object can
  perform when it is triggered at that index.

  The Command object type was designed to let a single object act as a
  programmable "macro" or "batch" controller. By writing different values to
  the Present_Value property (or by using Write Property to individual array
  elements of the Action property), a client can select which pre-defined
  sequence of operations should be executed. This is heavily used in
  life-safety, chiller plant optimization, lighting scenes, and any situation
  where a coordinated set of actions must be performed atomically from the
  viewpoint of the operator.

  Because the list can contain dozens of individual Action Commands and each
  command can target a different object and property, the encoding of an
  Action List is one of the more complex constructed data types in the
  protocol.
  """

  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ActionCommand
  alias BACnet.Protocol.ApplicationTags

  @typedoc """
  Represents an ordered list of actions to be executed by a Command object.
  """
  @type t :: %__MODULE__{
          actions: [ActionCommand.t()]
        }

  @fields [:actions]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encode a BACnet action list into application tag-encoded.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = list, opts \\ []) do
    case Enum.reduce_while(list.actions, {:ok, []}, fn
           cmd, {:ok, acc} ->
             case ActionCommand.encode(cmd, opts) do
               {:ok, encoded} -> {:cont, {:ok, [encoded | acc]}}
               {:error, _err} = err -> {:halt, err}
             end
         end) do
      {:ok, cmds} ->
        cmdlist =
          cmds
          |> Enum.reverse()
          |> List.flatten()

        {:ok, [{:constructed, {0, cmdlist, 0}}]}

      {:error, _err} = err ->
        err
    end
  end

  @doc """
  Parse a BACnet action list from application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}}
          | {:error, term()}
  def parse(tags) when is_list(tags) do
    case tags do
      [{:constructed, {0, tags, _len}} | rest] ->
        case Enum.reduce_while(1..100_000//1, {:ok, {[], tags}}, fn
               _ind, {:ok, {acc, []}} ->
                 {:halt, {:ok, {acc, []}}}

               _ind, {:ok, {acc, tags}} ->
                 case ActionCommand.parse(tags) do
                   {:ok, {cmd, rest}} -> {:cont, {:ok, {[cmd | acc], rest}}}
                   {:error, _err} = err -> {:halt, err}
                 end
             end) do
          {:ok, {actions, _rest}} ->
            list = %__MODULE__{
              actions: Enum.reverse(actions)
            }

            {:ok, {list, rest}}

          {:error, _err} = err ->
            err
        end

      _term ->
        {:error, :invalid_tags}
    end
  end

  @doc """
  Validates whether the given action list is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          actions: actions
        } = _t
      )
      when is_list(actions) do
    Enum.all?(actions, fn
      %ActionCommand{} = cmd -> ActionCommand.valid?(cmd)
      _else -> false
    end)
  end

  def valid?(%__MODULE__{} = _t), do: false
end
