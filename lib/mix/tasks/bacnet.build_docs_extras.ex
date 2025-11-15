defmodule Mix.Tasks.Bacnet.BuildDocsExtras do
  @moduledoc """
  Prepares and builds all ex_doc extras for inclusion.

  The following extras get generated:
  - Example:
    - WhoIs
  - Constants Table:
    - Engineering Unit
    - Object Type
    - Property Identifier

  The following rules exist for ex_docs extras:
  - First line must be `<!--t: <title> -->` - Title for the extra
  - Second line can be `<!--s: <source filepath> -->` - Source file for the extra

  Following options are supported:
  - `--clean-extras` - Removes the whole directory contents.
  - `--clean-generated-extras` - Removes all generated directory contents (files starting with `gen_`).
  """

  @shortdoc "Prepares and builds all ex_doc extras."

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    main_dir = Path.dirname(Mix.ProjectStack.project_file())
    extras_dir = Path.join(main_dir, "extras")

    if "--clean-extras" in args do
      File.rm_rf!(extras_dir)
    end

    if "--clean-generated-extras" in args and File.exists?(extras_dir) do
      extras_dir
      |> File.ls!()
      |> Enum.filter(&String.starts_with?(&1, "gen_"))
      |> Enum.map(&File.rm!(Path.join(extras_dir, &1)))
    end

    if not File.exists?(extras_dir) do
      File.mkdir!(extras_dir)
    end

    build_constants(:engineering_unit, BACnet.Protocol.Constants.EngineeringUnit)
    build_constants(:object_type, BACnet.Protocol.Constants.Object)
    build_constants(:property_identifier, BACnet.Protocol.Constants.PropertyIdentifier)

    build_example("who_is")

    Mix.shell().info("Done building extras")
  end

  # defp build_constants(type, const_mod \\ BACnet.Protocol.Constants)
  defp build_constants(type, const_mod) when is_atom(type) and is_atom(const_mod) do
    main_dir = Path.dirname(Mix.ProjectStack.project_file())
    extras_dir = Path.join(main_dir, "extras")

    source_file =
      case const_mod.__info__(:compile)[:source] do
        str when is_list(str) ->
          str
          |> :binary.list_to_bin()
          |> Path.relative_to(Path.join([__DIR__, "..", "..", ".."]))

        _other ->
          Mix.shell().error(
            "Module #{String.replace("#{const_mod}", "Elixir.", "")} has no source annotation, " <>
              "can not determine source file"
          )

          "nil"
      end

    md =
      const_mod.get_constants_docs()
      |> Keyword.fetch!(type)
      |> then(
        &Regex.replace(~r"^[#]+(.+)", &1, "<!--t: \\1 -->" <> "\n<!--s: #{source_file} -->")
      )

    File.write!(Path.join(extras_dir, "gen_#{type}.md"), md)
  end

  defp build_example(filename) do
    main_dir = Path.dirname(Mix.ProjectStack.project_file())
    extras_dir = Path.join(main_dir, "extras")
    example_dir = Path.join(main_dir, "examples")
    source_path = Path.join([example_dir, filename <> ".exs"])

    {explanation, code} =
      source_path
      |> File.read!()
      |> String.split("\n")
      |> Enum.split_while(&String.starts_with?(&1, "#"))
      |> then(fn {a, b} ->
        a =
          a
          |> Enum.join("\n")
          |> String.trim()
          |> String.replace("# ", "")

        {a, String.trim(Enum.join(b, "\n"))}
      end)

    title =
      filename
      |> String.split("_")
      |> Enum.map_join(" ", &String.capitalize/1)

    md = """
    <!--t: Example: #{title} -->
    <!--s: examples/#{filename}.exs -->

    #{explanation}

    Code (taken from file `examples/#{filename}.exs`):

    ```elixir
    #{code}
    ```

    This example can be run:
    - if installed as dependency: `mix run deps/bacstack/examples/#{filename}.exs`
    - if working on bacstack: `mix run examples/#{filename}.exs`
    """

    File.write!(Path.join(extras_dir, "gen_#{filename}.md"), md)
  end
end
