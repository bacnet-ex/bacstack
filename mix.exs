defmodule BACstack.MixProject do
  use Mix.Project

  def project do
    tracers = Code.get_compiler_option(:tracers)

    [
      app: :bacstack,
      version: "0.1.0",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [tracers: [__MODULE__ | tracers]],
      # This is the cause for unknown protocol __impl__/1 for built-in types
      consolidate_protocols: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        ignore_warnings: "dialyzer.ignore-warnings.exs",
        plt_add_apps: []
      ],
      source_url: "https://github.com/bacnet-ex/bacstack",
      docs: [
        main: "BACnet",
        source_ref: "master",
        filter_modules: ~r"^Elixir\.BACnet(?!\.Test).*$",
        groups_for_docs: [Guards: & &1[:guard]],
        groups_for_modules: [
          "Protocol: General": [
            ~r"Protocol\.APDU",
            ~r"Protocol\.NPCI"i,
            ~r"Protocol\.NPDU"i,
            BACnet.Protocol,
            BACnet.Protocol.ApplicationTags,
            BACnet.Protocol.ApplicationTags.Encoding,
            BACnet.Protocol.Constants,
            BACnet.Protocol.IncompleteAPDU,
            BACnet.Protocol.NetworkLayerProtocolMessage
          ],
          "Protocol: Data Types": [
            ~r"Protocol\.BACnet",
            BACnet.Protocol.AccessSpecification,
            BACnet.Protocol.AccessSpecification.Property,
            BACnet.Protocol.AccumulatorRecord,
            BACnet.Protocol.ActionCommand,
            BACnet.Protocol.ActionList,
            BACnet.Protocol.AddressBinding,
            BACnet.Protocol.AlarmSummary,
            BACnet.Protocol.BACnetArray,
            BACnet.Protocol.CalendarEntry,
            BACnet.Protocol.CovSubscription,
            BACnet.Protocol.DailySchedule,
            BACnet.Protocol.DateRange,
            BACnet.Protocol.DaysOfWeek,
            BACnet.Protocol.Destination,
            BACnet.Protocol.DeviceObjectRef,
            BACnet.Protocol.DeviceObjectPropertyRef,
            BACnet.Protocol.EnrollmentSummary,
            BACnet.Protocol.EventInformation,
            BACnet.Protocol.EventLogRecord,
            BACnet.Protocol.EventMessageTexts,
            BACnet.Protocol.EventTimestamps,
            BACnet.Protocol.EventTransitionBits,
            BACnet.Protocol.GroupChannelValue,
            BACnet.Protocol.LimitEnable,
            BACnet.Protocol.LogMultipleRecord,
            BACnet.Protocol.LogRecord,
            BACnet.Protocol.LogStatus,
            BACnet.Protocol.NotificationClassPriority,
            BACnet.Protocol.ObjectIdentifier,
            BACnet.Protocol.ObjectPropertyRef,
            BACnet.Protocol.Prescale,
            BACnet.Protocol.PriorityArray,
            BACnet.Protocol.PropertyRef,
            BACnet.Protocol.PropertyState,
            BACnet.Protocol.PropertyValue,
            BACnet.Protocol.ReadAccessResult,
            BACnet.Protocol.ReadAccessResult.ReadResult,
            BACnet.Protocol.Recipient,
            BACnet.Protocol.RecipientAddress,
            BACnet.Protocol.ResultFlags,
            BACnet.Protocol.SetpointReference,
            BACnet.Protocol.SpecialEvent,
            BACnet.Protocol.StatusFlags,
            BACnet.Protocol.TimeValue,
            BACnet.Protocol.WeekNDay
          ],
          "Protocol: Objects": [
            BACnet.Protocol.ObjectsUtility,
            ~r"Protocol\.ObjectTypes\..+",
            BACnet.Protocol.Device.ObjectTypesSupported,
            BACnet.Protocol.Device.ServicesSupported
          ],
          "Protocol: Services": [~r"Protocol\.Services\.(?!Behaviour|Common|Protocol)"],
          "Protocol: Alarm & Event Subscription": [
            ~r"Protocol\.EventAlgorithms",
            ~r"Protocol\.EventParameters",
            ~r"Protocol\.FaultAlgorithms",
            ~r"Protocol\.FaultParameters",
            ~r"Protocol\.NotificationParameters"
          ],
          "Protocol: BACnet/IP": [
            ~r"Protocol\.Bvlc",
            BACnet.Protocol.BroadcastDistributionTableEntry,
            BACnet.Protocol.ForeignDeviceTableEntry
          ],
          Stack: [~r"Stack\.[^.]+$", ~r"Stack\.Transport\.[^.]+$"],
          "BACstack Internals": [
            BACnet.Internal,
            BACnet.Protocol.ObjectsMacro,
            BACnet.Protocol.Services.Behaviour,
            BACnet.Protocol.Services.Common,
            BACnet.Protocol.Services.Protocol,
            BACnet.Protocol.Utility,
            BACnet.Stack.BBMD.ClientRef,
            BACnet.Stack.BBMD.Registration,
            BACnet.Stack.BBMD.State,
            BACnet.Stack.Client.ApduTimer,
            BACnet.Stack.Client.ReplyTimer,
            BACnet.Stack.Client.State,
            BACnet.Stack.ForeignDevice.Registration,
            BACnet.Stack.ForeignDevice.State,
            BACnet.Stack.Segmentator.Sequence,
            BACnet.Stack.Segmentator.State,
            BACnet.Stack.SegmentsStore.Sequence,
            BACnet.Stack.SegmentsStore.State,
            BACnet.Stack.TrendLogger.Log,
            BACnet.Stack.TrendLogger.State
          ]
        ],
        nest_modules_by_prefix: [
          BACnet.Protocol,
          BACnet.Protocol.EventAlgorithms,
          BACnet.Protocol.EventParameters,
          BACnet.Protocol.FaultAlgorithms,
          BACnet.Protocol.FaultParameters,
          BACnet.Protocol.NotificationParameters,
          BACnet.Protocol.ObjectTypes,
          BACnet.Protocol.Services,
          BACnet.Protocol.Services.Ack,
          BACnet.Protocol.Services.Error,
          BACnet.Stack,
          BACnet.Stack.Transport
        ],
        before_closing_head_tag: &docs_before_closing_head_tag/1,
        before_closing_body_tag: &docs_before_closing_body_tag/1
      ],
      test_coverage: [
        ignore_modules: [
          ~r"Inspect\..+",
          BACnet.Macro,
          ~r"BACnet\.Protocol\.Constants\..+",
          BACnet.Protocol.ObjectsUtility.Internal.ReadPropertyAckTransformOptions,
          BACnet.Protocol.Services.Protocol,
          BACnet.Stack.EncoderProtocol,
          ~r"BACnet\.Test\..+",
          # TODO: Remove me once we can test services error modules (we have payloads)
          ~r"BACnet\.Protocol\.Services\.Error\..+"
        ],
        summary: true,
        tool: if(System.get_env("CI"), do: ExCoveralls, else: Mix.Tasks.Test.Coverage)
      ]
    ]
  end

  def application do
    [
      extra_applications: [:inets, :logger]
    ]
  end

  defp deps do
    [
      {:cidr, "~> 1.1"},
      {:codepagex, "~> 0.1"},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:dialyxir, "1.4.3", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.21", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.29", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: [:test], runtime: false},
      {:junit_formatter, "~> 3.3", only: [:test], runtime: false},
      {:telemetry, "~> 1.3", optional: true}
    ]
  end

  # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs_before_closing_head_tag(:html) do
    """
    <!-- Markdown for details HTML tags -->
    <script src="https://cdnjs.cloudflare.com/ajax/libs/showdown/2.1.0/showdown.min.js"></script>

    <!-- Sortable tables -->
    <style>
      table th {
        cursor: pointer;
      }

      table th[aria-sort="ascending"] span::after {
        content: "▲";
        color: currentcolor;
        font-size: 100%;
        top: 0;
        margin-left: 5px;
      }

      table th[aria-sort="descending"] span::after {
        content: "▼";
        color: currentcolor;
        font-size: 100%;
        top: 0;
        margin-left: 5px;
      }
    </style>
    """
  end

  defp docs_before_closing_head_tag(:epub), do: ""

  defp docs_before_closing_body_tag(:html) do
    """
    <!-- Markdown for details HTML tags & sortable tables -->
    <script>
      class TableSortableColumns {
        constructor(tableNode) {
          this.tableNode = tableNode;
          this.columnHeaders = tableNode.querySelectorAll('thead th');
          this.sortColumns = [];

          for (var i = 0; i < this.columnHeaders.length; i++) {
            var ch = this.columnHeaders[i];

            if (ch) {
              ch.innerHTML += '<span aria-hidden="true"></span>';
              this.sortColumns.push(i);
              ch.setAttribute('data-column-index', i);
              ch.addEventListener('click', this.handleClick.bind(this));
            }
          }
        }

        setColumnHeaderSort(columnIndex) {
          if (typeof columnIndex === 'string') {
            columnIndex = parseInt(columnIndex);
          }

          for (var i = 0; i < this.columnHeaders.length; i++) {
            var ch = this.columnHeaders[i];

            if (i === columnIndex) {
              var value = ch.getAttribute('aria-sort');

              if (value === 'ascending') {
                ch.setAttribute('aria-sort', 'descending');
                this.sortColumn(
                  columnIndex,
                  'descending',
                  ch.classList.contains('num')
                );
              } else {
                ch.setAttribute('aria-sort', 'ascending');
                this.sortColumn(
                  columnIndex,
                  'ascending',
                  ch.classList.contains('num')
                );
              }
            } else if (ch.hasAttribute('aria-sort')) {
              ch.removeAttribute('aria-sort');
            }
          }
        }

        sortColumn(columnIndex, sortValue, isNumber) {
          function compareValues(a, b) {
            isNumber = !isNaN(parseFloat(a.value)) && !isNaN(parseFloat(b.value))

            if (sortValue === 'ascending') {
              if (a.value === b.value) {
                return 0;
              } else {
                if (isNumber) {
                  return a.value - b.value;
                } else {
                  return a.value < b.value ? -1 : 1;
                }
              }
            } else {
              if (a.value === b.value) {
                return 0;
              } else {
                if (isNumber) {
                  return b.value - a.value;
                } else {
                  return a.value > b.value ? -1 : 1;
                }
              }
            }
          }

          if (typeof isNumber !== 'boolean') {
            isNumber = false;
          }

          var tbodyNode = this.tableNode.querySelector('tbody');
          var rowNodes = [];
          var dataCells = [];

          var rowNode = tbodyNode.firstElementChild;

          var index = 0;
          while (rowNode) {
            rowNodes.push(rowNode);

            var rowCells = rowNode.querySelectorAll('th, td');
            var dataCell = rowCells[columnIndex];
            var data = {};

            data.index = index;
            data.value = dataCell.textContent.toLowerCase().trim();
            if (isNumber) {
              data.value = parseFloat(data.value);
            }

            dataCells.push(data);
            rowNode = rowNode.nextElementSibling;
            index += 1;
          }

          dataCells.sort(compareValues);

          while (tbodyNode.firstChild) {
            tbodyNode.removeChild(tbodyNode.lastChild);
          }

          for (var i = 0; i < dataCells.length; i += 1) {
            tbodyNode.appendChild(rowNodes[dataCells[i].index]);
          }
        }

        handleClick(event) {
          var target = event.currentTarget;
          this.setColumnHeaderSort(target.getAttribute('data-column-index'));
        }
      }

      document.addEventListener('DOMContentLoaded', function () {
        // This is the part where we load the <details> contents,
        // parse it using markdown and push the HTML back
        var converter = new showdown.Converter({});
        converter.setFlavor('github');

        var details = document.querySelectorAll('details');
        for (var i = 0; i < details.length; i++) {
          details[i].innerHTML = converter.makeHtml(details[i].innerHTML);
        }

        // Now apply sortable tables, because <details> could contain tables
        var tables = document.querySelectorAll('table');
        for (var i = 0; i < tables.length; i++) {
          new TableSortableColumns(tables[i]);
        }
      });
    </script>
    """
  end

  defp docs_before_closing_body_tag(:epub), do: ""

  #### Compilation tracer START ####
  # We want to be able to lookup module bytecodes for freshly compiled modules,
  # for already compiled modules we can just lookup the BEAM file as fallback,
  # so we can retrieve the types from the BEAM bytecode for our object types macro module

  @doc false
  def trace({:on_module, bytecode, _ignore}, env) do
    # TODO: Review
    :persistent_term.put(env.module, bytecode)
    # IO.inspect(:persistent_term.info())

    :ok
  end

  def trace(_event, _env) do
    :ok
  end

  #### Compilation tracer END ####
end
