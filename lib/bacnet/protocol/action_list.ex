defmodule BACnet.Protocol.ActionList do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ActionCommand

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
    with {:ok, cmds} <-
           Enum.reduce_while(list.actions, {:ok, []}, fn
             cmd, {:ok, acc} ->
               case ActionCommand.encode(cmd, opts) do
                 {:ok, encoded} -> {:cont, {:ok, [encoded | acc]}}
                 {:error, _err} = err -> {:halt, err}
               end
           end) do
      cmdlist =
        cmds
        |> Enum.reverse()
        |> List.flatten()

      {:ok, [{:constructed, {0, cmdlist, 0}}]}
    else
      {:error, _err} = err -> err
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
        with {:ok, {actions, _rest}} <-
               Enum.reduce_while(1..100_000//1, {:ok, {[], tags}}, fn
                 _ind, {:ok, {acc, []}} ->
                   {:halt, {:ok, {acc, []}}}

                 _ind, {:ok, {acc, tags}} ->
                   case ActionCommand.parse(tags) do
                     {:ok, {cmd, rest}} -> {:cont, {:ok, {[cmd | acc], rest}}}
                     {:error, _err} = err -> {:halt, err}
                   end
               end) do
          list = %__MODULE__{
            actions: Enum.reverse(actions)
          }

          {:ok, {list, rest}}
        else
          {:error, _err} = err -> err
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
