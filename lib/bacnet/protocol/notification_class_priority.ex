defmodule BACnet.Protocol.NotificationClassPriority do
  @moduledoc """
  The notification class priority BACnet array is used to convey the priority
  used for event notifications. A lower number indicates a higher priority.
  """

  alias BACnet.Protocol.ApplicationTags

  # TODO: Throw argument error in encode if not valid

  @typedoc """
  Represents the notification class priority array (three priorities).
  """
  @type t :: %__MODULE__{
          to_offnormal: 0..255,
          to_fault: 0..255,
          to_normal: 0..255
        }

  @fields [to_offnormal: 0, to_fault: 0, to_normal: 0]
  defstruct @fields

  @doc """
  Encodes a BACnet notification class priority (BACnetArray[3] of Unsigned) into BACnet application tags encoding.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = priority, _opts \\ []) do
    params = [
      {:unsigned_integer, priority.to_offnormal},
      {:unsigned_integer, priority.to_fault},
      {:unsigned_integer, priority.to_normal}
    ]

    {:ok, params}
  end

  @doc """
  Parses a BACnet notification class priority (BACnetArray[3] of Unsigned) from BACnet application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}}
          | {:error, term()}
  def parse(tags) when is_list(tags) do
    case tags do
      [
        {:unsigned_integer, to_offnormal},
        {:unsigned_integer, to_fault},
        {:unsigned_integer, to_normal}
        | rest
      ]
      when to_offnormal in 0..255 and to_fault in 0..255 and to_normal in 0..255 ->
        priority = %__MODULE__{
          to_offnormal: to_offnormal,
          to_fault: to_fault,
          to_normal: to_normal
        }

        {:ok, {priority, rest}}

      _else ->
        {:error, :invalid_tags}
    end
  end

  @doc """
  Validates whether the given notification class priority is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          to_offnormal: to_offnormal,
          to_fault: to_fault,
          to_normal: to_normal
        } = _t
      )
      when is_integer(to_offnormal) and to_offnormal >= 0 and to_offnormal <= 255 and
             is_integer(to_fault) and to_fault >= 0 and to_fault <= 255 and
             is_integer(to_normal) and to_normal >= 0 and to_normal <= 255,
      do: true

  def valid?(%__MODULE__{} = _t), do: false
end
