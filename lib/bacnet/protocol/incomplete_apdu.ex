defmodule BACnet.Protocol.IncompleteAPDU do
  @moduledoc """
  This module is used to represent a segmented incomplete APDU.

  The given struct is to be fed to the `BACnet.Stack.SegmentsStore`, which will handle the segmentation.
  """

  @typedoc """
  Represents an incomplete APDU.
  """
  @type t :: %__MODULE__{}

  @fields [
    :header,
    :server,
    :invoke_id,
    :sequence_number,
    :window_size,
    :more_follows,
    :data
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Set the window size field to the given number.
  """
  @spec set_window_size(t(), 1..127) :: t()
  def set_window_size(%__MODULE__{} = incomplete, window_size) when window_size in 1..127 do
    %{incomplete | window_size: window_size}
  end
end
