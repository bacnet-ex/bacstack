defmodule BACnet.Test.Support.Protocol.ObjectsMacroTestSupport.BacObjectMinimalDocsStub do
  use BACnet.Protocol.ObjectsMacro

  # Why does Dialyzer think for this module there's a success typing error with this function?
  # The other modules are fine, just not here??? What the heck Dialyzer.
  @dialyzer {:nowarn_function, property_writable?: 2}

  @type object_opts :: nil

  bac_object :binary_input do
    services(intrinsic: true)

    field(:description, String.t())
    field(:device_type, String.t())
    field(:out_of_service, boolean(), required: true)
    field(:present_value, boolean(), required: true, default: false)
  end
end

defmodule BACnet.Test.Support.Protocol.ObjectsMacroTestSupport.BacObjectMinimalDocsStub2 do
  @moduledoc """
  Hello there.
  """

  use BACnet.Protocol.ObjectsMacro

  # Why does Dialyzer thinks for this module there's a success typing error with this function?
  # The other modules are fine, just not here??? What the heck Dialyzer.
  @dialyzer {:nowarn_function, property_writable?: 2}

  @type object_opts :: nil

  bac_object :binary_input do
    services(intrinsic: true)

    field(:description, String.t())
    field(:device_type, String.t())
    field(:out_of_service, boolean(), required: true)
    field(:present_value, boolean(), required: true, default: false)
  end
end
