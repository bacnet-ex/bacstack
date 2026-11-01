defmodule BACnet.Test.Stack.Case do
  @moduledoc false

  defmacro __using__(opts) do
    quote do
      use ExUnit.Case, unquote(opts)

      import ExUnit.Assertions, except: [assert_receive: 1]
      import BACnet.Test.Stack.Case, only: [assert_receive: 1]
    end
  end

  # Stack tests cross process, socket and UART boundaries. Keep the default
  # positive wait independent of ExUnit's 100 ms default, including under cover.
  # Explicit waits and negative assertions retain their own timing semantics.
  defmacro assert_receive(pattern) do
    quote do
      ExUnit.Assertions.assert_receive(unquote(pattern), 1_000)
    end
  end
end
