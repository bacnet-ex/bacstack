defmodule BACnet.Test.Protocol.ObjectTypes.BasicTest do
  alias BACnet.Protocol.ObjectsUtility

  import BACnet.Test.Support.Protocol.ObjectsUtilityTestHelper

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object

  for {obj_type, module} <- ObjectsUtility.get_object_type_mappings() do
    doctest module

    test_list = generate_object_tests(obj_type, module)
    mod_name = Module.concat([__MODULE__, String.to_atom(Macro.camelize("#{obj_type}")), :Basic])

    defmodule mod_name do
      use ExUnit.Case, async: true

      @moduletag :object_utility
      @moduletag String.to_atom("bacnet_object")
      @moduletag String.to_atom("bacnet_object_basic")
      @moduletag String.to_atom("bacnet_object_#{obj_type}")

      for {description, code_call, pattern_match, appendum_code} <- test_list do
        test "basic object test #{obj_type} #{description}" do
          # assert nil = nil will result in failure due to falsey value
          if unquote(pattern_match) do
            assert unquote(pattern_match) = unquote(code_call)
          else
            assert unquote(pattern_match) == unquote(code_call)
          end

          unquote(appendum_code)
        end
      end
    end
  end
end
