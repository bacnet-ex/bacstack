defmodule BACnet.Protocol.ActionList do
  @moduledoc """
  An Action List is an ordered collection of `BACnet.Protocol.ActionCommand` entries.
  Each element of a Command object's Action array contains one such list, representing
  the sequence selected when that array index is written to the Command's `present_value`.

  The Command object type was designed to let a single object act as a
  programmable "macro" or "batch" controller. By writing different values to
  the present_value property, a client selects which pre-defined
  sequence of operations should be executed. This is used in life-safety,
  chiller plant optimization, lighting scenes and coordinated operating-mode changes.
  Execution is ordered and individual writes can fail - earlier successful writes
  are not rolled back. Updating the Action array configures a sequence - writing
  the Command's `present_value` triggers it.

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
      [{:constructed, {0, commands, _length}} | rest] when is_list(commands) ->
        with {:ok, actions} <- parse_actions(commands, []) do
          {:ok, {%__MODULE__{actions: actions}, rest}}
        end

      _term ->
        {:error, :invalid_tags}
    end
  end

  @spec parse_actions(ApplicationTags.encoding_list(), [ActionCommand.t()]) ::
          {:ok, [ActionCommand.t()]} | {:error, term()}
  defp parse_actions(tags, reversed)

  defp parse_actions([], reversed), do: {:ok, Enum.reverse(reversed)}

  defp parse_actions(tags, reversed) do
    with {:ok, {command, rest}} <- ActionCommand.parse(tags) do
      parse_actions(rest, [command | reversed])
    end
  end

  @doc """
  Validates whether the given action list is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(list)

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
