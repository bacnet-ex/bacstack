defmodule BACnet do
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("\n")
             |> tl()
             |> Enum.join("\n")
             |> String.trim()

  @external_resource "README.md"

  # TODO: Docs
end
