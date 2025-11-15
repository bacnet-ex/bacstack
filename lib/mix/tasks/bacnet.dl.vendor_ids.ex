defmodule Mix.Tasks.Bacnet.Dl.Vendorids do
  @moduledoc """
  Downloads the list of the vendors from the BACnet website.

  It does so by scrapping the HTML table and extracting the ID and name,
  and puts both into a CSV file for further processing and usage.

  The data is embedded into the `BACnet.Protocol.ObjectTypes.Device` module at compile time.

  For this, both html_entities and req dependencies need to be installed.
  """

  @shortdoc "Downloads the list of the vendor IDs from the BACnet website."

  @dialyzer {:nowarn_function, run: 1, download_vendor_ids: 0}

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    case download_vendor_ids() do
      :ok ->
        Mix.shell().info("Done downloading vendor list")

      {:error, reason} ->
        Mix.shell().error("Could not download vendor list, reason: " <> reason)
    end
  end

  @spec download_vendor_ids() :: :ok | {:error, String.t()} | no_return()
  if Code.ensure_loaded?(Req) and Code.ensure_loaded?(HtmlEntities) do
    def download_vendor_ids() do
      case Application.ensure_all_started(:req) do
        {:ok, _list} ->
          path = BACstack.MixProject.get_vendor_ids_csv_file()

          path
          |> Path.dirname()
          |> File.mkdir_p!()

          "https://bacnet.org/assigned-vendor-ids/"
          |> Req.get!()
          |> then(&HtmlEntities.decode(&1.body))
          |> then(fn body ->
            Regex.scan(
              ~r"<tr><td>(\d+)<\/td><td>(?:<em>)?(.+?)(?:</em>)?<\/td>(?:<td>.*?<\/td><td>.*?<\/td>)?<\/tr>",
              body
            )
          end)
          |> Enum.map_join("\n", fn [_whole, id, name | _tl] ->
            id <> ";" <> name
          end)
          |> then(&File.write!(path, &1))

          :ok

        _other ->
          {:error, "Could not start :req application"}
      end
    end
  else
    # This is a workaround for the type violation warning with Elixir 1.18+,
    # we do not really care *at all*
    def download_vendor_ids(),
      do:
        Process.get(
          __MODULE__,
          {:error, "Missing dependencies, make sure html_entities and req are installed"}
        )
  end
end
