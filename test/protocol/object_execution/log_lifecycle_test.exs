defmodule BACnet.Test.Protocol.ObjectExecution.LogLifecycleTest do
  use ExUnit.Case, async: true

  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.LogLifecycle

  test "resolves supported server references from the context" do
    assert {:error, {:unsupported_operation, :trend_logger}} =
             LogLifecycle.get_logger(Context.new(:initialization))

    assert {:error, {:invalid_execution_option, :trend_logger}} =
             LogLifecycle.get_logger(Context.new(:initialization, options: [trend_logger: "log"]))

    for server <- [self(), :logger, {:logger, node()}, {:global, :log}, {:via, Registry, :log}] do
      assert {:ok, ^server} =
               LogLifecycle.get_logger(
                 Context.new(:initialization, options: [trend_logger: server])
               )
    end
  end
end
