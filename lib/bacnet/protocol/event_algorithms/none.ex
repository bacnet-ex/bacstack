defmodule BACnet.Protocol.EventAlgorithms.None do
  @moduledoc """
  Implements the BACnet event algorithm `None`.

  This event algorithm has no parameters, no conditions,
  and does not indicate any transitions of event state.
  The NONE algorithm is used when only fault detection
  is in use by an object.

  This module has NO implementation.
  """

  @typedoc """
  Representative type for the event algorithm.
  """
  @opaque t :: %__MODULE__{}

  defstruct []
end
