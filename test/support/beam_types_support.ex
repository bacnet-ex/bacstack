defmodule BACnet.Test.Support.Protocol.BeamTypesSupport.StructNoValidator do
  defstruct [:hello]
end

defmodule BACnet.Test.Support.Protocol.BeamTypesSupport.StructValidator do
  defstruct [:hello]

  def valid?(%__MODULE__{hello: val}), do: is_boolean(val)
  def valid?(_other), do: false
end

defmodule BACnet.Test.Support.Protocol.BeamTypesSupport.StructTypesEmpty do
  @type t :: %__MODULE__{_hello: term()}

  defstruct [:_hello]
end

defmodule BACnet.Test.Support.Protocol.BeamTypesSupport.StructTypes do
  @type t :: %__MODULE__{hello: binary()}

  defstruct [:hello]
end

defmodule BACnet.Test.Support.Protocol.BeamTypesSupport.StructTypes2 do
  @type t :: %__MODULE__{hello: binary(), sum: integer()}

  defstruct [:hello, :sum]
end

defmodule BACnet.Test.Support.Protocol.BeamTypesSupport.StructTypesWithMap do
  @type t :: %__MODULE__{internal_metadata: term(), world: map()}

  defstruct [:internal_metadata, :world]
end

defmodule BACnet.Test.Support.Protocol.BeamTypesSupport.StructTypesAnnotated do
  @type t :: %__MODULE__{world: hello :: list()}

  defstruct [:world]
end

defmodule BACnet.Test.Support.Protocol.BeamTypesSupport.StructTypesUserType do
  @type bin :: list()
  @type t :: %__MODULE__{world: bin()}

  defstruct [:world]
end

defmodule BACnet.Test.Support.Protocol.BeamTypesSupport.StructTypesLiteralNumber do
  @type t :: %__MODULE__{world: 5}

  defstruct [:world]
end

defmodule BACnet.Test.Support.Protocol.BeamTypesSupport.StructTypesLiteralNumberList do
  @type t :: %__MODULE__{world: [5]}

  defstruct [:world]
end
