defmodule BACnet.Protocol.EventAlgorithms.ComplexEventType do
  @moduledoc """
  Implements the BACnet event algorithm `ComplexEventType`.

  The `ComplexEventType` algorithm is introduced to allow the addition of proprietary
  event algorithms whose event algorithms are not necessarily network-visible.

  This module has NO implementation.
  """

  @typedoc """
  Representative type for the event algorithm.
  """
  @opaque t :: %__MODULE__{
            data: term()
          }

  defstruct data: nil
end
