defmodule BACnet.Stack.ClientHelper do
  @moduledoc """
  BACnet stack client helper functions for executing commands/queries.
  """

  alias BACnet.Protocol.AccessSpecification
  alias BACnet.Protocol.APDU
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.PropertyRef
  alias BACnet.Protocol.ReadAccessResult
  alias BACnet.Protocol.Services
  alias BACnet.Stack.Client

  import BACnet.Internal, only: [log_debug: 1]

  require Constants
  require Logger

  @doc """
  Sends an I-Am service request to the destination, or optionally using
  `:broadcast` (or the real broadcast address) as local broadcast.

  See also `BACnet.Protocol.Services.IAm`.

  The `Client.send/4` options are available.
  """
  @spec i_am(
          GenServer.server(),
          term() | :broadcast,
          ObjectIdentifier.t(),
          non_neg_integer(),
          Keyword.t()
        ) ::
          :ok | {:error, term()}
  def i_am(
        server,
        destination,
        %ObjectIdentifier{type: :device} = device,
        vendor_id,
        opts \\ []
      )
      when is_integer(vendor_id) and vendor_id >= 0 and is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "i_am/5 expected opts to be a keyword list, " <>
              "got: #{inspect(opts)}"
    end

    with {:ok, addr} <- get_address(server, destination),
         {trans_mod, _transport, _portal} <- Client.get_transport(server),
         {:ok, req} <-
           Services.IAm.to_apdu(
             %Services.IAm{
               device: device,
               max_apdu: trans_mod.max_apdu_length(),
               segmentation_supported:
                 Constants.macro_assert_name(:segmentation, :segmented_both),
               vendor_id: vendor_id
             },
             []
           ) do
      Client.send(server, addr, req, opts)
    end
  end

  @doc """
  Read a BACnet object from a remote BACnet device and transform it into an object.

  The required properties are always as a bare minimum read, only more properties can be read, never less.

  The value is casted through the `BACnet.Protocol.ObjectsUtility` module based on the object modules.
  As such object types or properties that are not supported, will fail.

  If you want to read a device object and don't know the proper device instance number,
  you can use `4_194_303` as instance number. By the BACnet specification that instance number will be
  treated by the remote BACnet device as if the instance number was locally correctly matched.

  The following options are available:
  - All options from `BACnet.Stack.Client.send/4`.
  - All options from `BACnet.Protocol.Services.ReadPropertyMultiple.to_apdu/2`.
  - All options from `BACnet.Protocol.ObjectsUtility.cast_read_properties_ack/3`.
  - All options from `BACnet.Protocol.ObjectsUtility.cast_properties_to_object/3`.
  - `properties: [:all | :required | Constants.property_identifier()]` - Optional. Select the properties to read.
  - `read_level: :all | :required` - Optional. Select how many properties should be read (defaults to `:all`).

  `properties` and `read_level` are mutually excluse. If both are given, `properties` takes precedence.
  """
  @spec read_object(
          GenServer.server(),
          term(),
          ObjectIdentifier.t(),
          Keyword.t()
        ) ::
          {:ok, ObjectsUtility.bacnet_object()}
          | {:error, BACnet.Protocol.apdu()}
          | {:error, term()}
  def read_object(
        server,
        destination,
        %ObjectIdentifier{} = object,
        opts \\ []
      )
      when is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "read_object/4 expected opts to be a keyword list, " <>
              "got: #{inspect(opts)}"
    end

    properties =
      case Keyword.get(opts, :properties, nil) do
        nil ->
          read_level = Keyword.get(opts, :read_level, :all)

          unless read_level == :all or read_level == :required do
            raise ArgumentError,
                  "read_object/4 expected read_level to be :all or :required, " <>
                    "got: #{inspect(read_level)}"
          end

          [read_level]

        props when is_list(props) ->
          props
          |> Enum.map(&make_access_property_from_identifier/1)
          |> then(fn list ->
            # Assert we have the required properties covered
            if Enum.any?(list, &(&1 == :all or &1 == :required)) do
              list
            else
              [:required | list]
            end
          end)

        term ->
          raise ArgumentError,
                "read_object/4 expected properties to be a list, " <>
                  "got: #{inspect(term)}"
      end

    with {:ok, req} <-
           Services.ReadPropertyMultiple.to_apdu(
             %Services.ReadPropertyMultiple{
               list: [
                 %AccessSpecification{
                   object_identifier: object,
                   properties: properties
                 }
               ]
             },
             opts
           ),
         {:ok, %APDU.ComplexACK{} = resp} <- Client.send(server, destination, req, opts),
         {:ok, ack} <- Services.Ack.ReadPropertyMultipleAck.from_apdu(resp),
         # When using 4_194_303 as device ID, fetch the correct ID from the first result
         cast_object_id =
           (case object do
              %{type: :device, instance: 4_194_303} when ack.results != [] ->
                hd(ack.results).object_identifier

              _else ->
                object
            end),
         {:ok, values} <- ObjectsUtility.cast_read_properties_ack(cast_object_id, [ack], opts) do
      ObjectsUtility.cast_properties_to_object(cast_object_id, values, opts)
    else
      {:ok, apdu} -> {:error, apdu}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Read a single property from a remote BACnet object and transform the value.

  The value is casted through the `BACnet.Protocol.ObjectsUtility` module based on the object modules.
  As such object types or properties that are not supported, will fail, unless you specify
  the `raw` options, which will give you the `Encoding` struct (or list of) to handle yourself.
  Array indexes of 0 will return the array size as `{:ok, non_neg_integer()}`, if successfully read.

  If you want to read a device object's property without needing to know before hand which instance number,
  you can use `4_194_303` as instance number. By the BACnet specification that instance number will be
  treated by the remote BACnet device as if the instance number was locally correctly matched.

  The following options are available:
  - All options from `BACnet.Stack.Client.send/4`.
  - All options from `BACnet.Protocol.Services.ReadProperty.to_apdu/2`.
  - `raw: boolean()` - Optional. Returns the `t:Encoding.t/0` (or list of) instead of trying to transform the value.
  """
  @spec read_property(
          GenServer.server(),
          term(),
          ObjectIdentifier.t(),
          Constants.property_identifier() | non_neg_integer(),
          non_neg_integer() | nil,
          Keyword.t()
        ) ::
          {:ok, term()}
          | {:ok, Encoding.t() | [Encoding.t()]}
          | {:error, BACnet.Protocol.apdu()}
          | {:error, term()}
  def read_property(
        server,
        destination,
        %ObjectIdentifier{} = object,
        property,
        array_index \\ nil,
        opts \\ []
      )
      when ((is_atom(property) and property not in [:all, :required, :optional]) or
              (is_integer(property) and property >= 0)) and
             (is_nil(array_index) or (is_integer(array_index) and array_index >= 0)) and
             is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "read_property/6 expected opts to be a keyword list, " <>
              "got: #{inspect(opts)}"
    end

    with {:ok, req} <-
           Services.ReadProperty.to_apdu(
             %Services.ReadProperty{
               object_identifier: object,
               property_identifier: property,
               property_array_index: array_index
             },
             opts
           ),
         {:ok, %APDU.ComplexACK{} = resp} <- Client.send(server, destination, req, opts),
         {:ok, ack} <- Services.Ack.ReadPropertyAck.from_apdu(resp),
         {:ok, value} <-
           (case opts[:raw] do
              true ->
                {:ok, ack.property_value}

              _else ->
                if array_index == 0 and is_integer(ack.property_value.value) do
                  {:ok, ack.property_value.value}
                else
                  ObjectsUtility.cast_property_to_value(
                    object,
                    ack.property_identifier,
                    ack.property_value,
                    allow_partial: array_index != nil
                  )
                end
            end) do
      {:ok, value}
    else
      {:ok, apdu} -> {:error, apdu}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Read multiple properties from a remote BACnet object at once and transform each value.

  The values are casted through the `BACnet.Protocol.ObjectsUtility` module based on the object modules.
  As such object types or properties that are not supported, will fail, unless you specify
  the `raw` options, which will give you a list of `ReadAccessResult`s to handle yourself.

  The following options are available:
  - All options from `BACnet.Stack.Client.send/4`.
  - All options from `BACnet.Protocol.Services.ReadPropertyMultiple.to_apdu/2`.
  - `raw: boolean()` - Optional. Returns the results instead of trying to transform each value.
  """
  @spec read_property_multiple(
          GenServer.server(),
          term(),
          ObjectIdentifier.t(),
          [
            AccessSpecification.Property.t()
            | Constants.property_identifier()
            | :all
            | :required
            | :optional
          ],
          Keyword.t()
        ) ::
          {:ok, %{optional(Constants.property_identifier()) => term()}}
          | {:ok, [ReadAccessResult.t()]}
          | {:error, BACnet.Protocol.apdu()}
          | {:error, term()}
  def read_property_multiple(
        server,
        destination,
        %ObjectIdentifier{} = object,
        properties,
        opts \\ []
      )
      when is_list(properties) and is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "read_property_multiple/5 expected opts to be a keyword list, " <>
              "got: #{inspect(opts)}"
    end

    with {:ok, req} <-
           Services.ReadPropertyMultiple.to_apdu(
             %Services.ReadPropertyMultiple{
               list: [
                 %AccessSpecification{
                   object_identifier: object,
                   properties: Enum.map(properties, &make_access_property_from_identifier/1)
                 }
               ]
             },
             opts
           ),
         {:ok, %APDU.ComplexACK{} = resp} <- Client.send(server, destination, req, opts),
         {:ok, ack} <- Services.Ack.ReadPropertyMultipleAck.from_apdu(resp),
         {:ok, values} <-
           (case opts[:raw] do
              true ->
                {:ok, ack.results}

              _else ->
                ObjectsUtility.cast_read_properties_ack(object, [ack], opts)
            end) do
      {:ok, values}
    else
      {:ok, apdu} -> {:error, apdu}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Send a Reinitialize-Device service request to a remote BACnet device.

  Password must be an ASCII string between 1 to 20 characters, inclusive, or nil.

  The following options are available:
  - All options from `BACnet.Stack.Client.send/4`.
  - All options from `BACnet.Protocol.Services.ReinitializeDevice.to_apdu/2`.
  """
  @spec reinitialize_device(
          GenServer.server(),
          term(),
          Constants.reinitialized_state(),
          String.t() | nil,
          Keyword.t()
        ) :: :ok | {:error, BACnet.Protocol.apdu()} | {:error, term()}
  def reinitialize_device(
        server,
        destination,
        state \\ Constants.macro_assert_name(:reinitialized_state, :warmstart),
        password \\ nil,
        opts \\ []
      ) do
    with {:ok, req} <-
           Services.ReinitializeDevice.to_apdu(
             %Services.ReinitializeDevice{
               reinitialized_state: state,
               password: password
             },
             opts
           ) do
      Client.send(server, destination, req, opts)
    end
  end

  @doc """
  Scan the given device for available objects and read all objects. A map of objects will be returned on success.

  If you don't know the device object identifier of the BACnet device in question, but you know the
  BACnet network address (i.e. the IP address and port for BACnet/IP), you can use the Who-Is service
  with the destination address being the device's network address, to discover the object identifier.
  You can also use `read_property/6` to read the `:object_identifier` property.

  The scan process is parallelized through `Task.async_stream/3` and thus the `invoke_id` is
  automatically being set. Since this implementation simply uses `invoke_id` in the range of `0..max_concurrency-1`,
  it would be safest when the `BACnet.Stack.Client` implementation manages and overrides the `invoke_id`,
  so that an user does not have to care about possible collisions.
  The current "default" implementation of `BACnet.Stack.Client` does manage `invoke_id`s,
  but it can be deactivated, so care must be exercised if it done.
  You need to be aware to not invoke/have parallel other requests to the same destination,
  as the `invoke_id` could be duplicated.

  The values are casted through the `BACnet.Protocol.ObjectsUtility` module based on the object modules.
  As such object types or properties that are not supported, will fail the operation.

  The following options are available:
  - All options from `read_object/4`.
  - All options from `BACnet.Stack.Client.send/4`.
  - All options from `BACnet.Protocol.Services.ReadPropertyMultiple.to_apdu/2`, except `invoke_id`.
  - All options from `BACnet.Protocol.ObjectsUtility.cast_read_properties_ack/3`.
  - All options from `BACnet.Protocol.ObjectsUtility.cast_properties_to_object/3`.
  - `exit_on_error: boolean()` - Optional. Whether to exit the process on first error.
  - `ignore_errors: boolean()` - Optional. Whether to ignore errors and continue with the rest.
  - `ignore_unsupported_object_types: boolean()` - Optional. Whether to ignore unknown/unsupported object types.
  - `task_max_concurrency: pos_integer()` - Optional. The maximum task concurrency to use (limited to 255).
  - `task_supervisor: Supervisor.supervisor()` - Optional. The task supervisor to use for spawning tasks.
  - `task_timeout: timeout()` - Optional. The timeout to use for the task async stream (defaults to `30_000`).

  `exit_on_error` and `ignore_errors` are mutually excluse. `ignore_errors` takes precedence, if set to `true`.
  """
  @spec scan_device(GenServer.server(), term(), ObjectIdentifier.t(), Keyword.t()) ::
          {:ok,
           %{
             optional(Constants.object_type()) => %{
               optional(non_neg_integer()) => ObjectsUtility.bacnet_object()
             }
           }}
          | {:error, {term(), ObjectIdentifier.t()}}
          | {:error, term()}
  def scan_device(server, destination, %ObjectIdentifier{type: :device} = device, opts \\ []) do
    exit_on_error = Keyword.get(opts, :exit_on_error, false)
    ignore_errors = Keyword.get(opts, :ignore_errors, false)
    ignore_unsupported_object_types = Keyword.get(opts, :ignore_unsupported_object_types, false)
    task_supervisor = Keyword.get(opts, :task_supervisor, nil)

    max_concurrency =
      min(255, Keyword.get_lazy(opts, :task_max_concurrency, &System.schedulers_online/0))

    task_spawn =
      if task_supervisor do
        &Task.Supervisor.async_stream(task_supervisor, &1, &2, &3)
      else
        &Task.async_stream/3
      end

    with {:ok, objects_list} <-
           read_property(
             server,
             destination,
             device,
             Constants.macro_assert_name(:property_identifier, :object_list),
             nil,
             raw: true
           ) do
      len = length(objects_list)
      pre_new_opts = Keyword.put(opts, :remote_device_id, device.instance)

      objects_stream =
        objects_list
        |> Stream.map(fn
          %Encoding{value: val} -> val
          term -> term
        end)
        # Do chunks by count chunks as max_concurrency (we only want max_concurrency chunks)
        |> Stream.chunk_every(trunc(Float.ceil(len / max_concurrency)))
        |> Stream.with_index()
        |> task_spawn.(
          # Make sure index/invoke_id is always in range 0..255
          fn {object_ids, index} when index >= 0 and index <= 255 ->
            Enum.reduce_while(object_ids, {:ok, []}, fn
              %ObjectIdentifier{} = object_id, {:ok, acc} ->
                new_opts = Keyword.put(pre_new_opts, :invoke_id, index)

                case read_object(server, destination, object_id, new_opts) do
                  {:ok, %{} = obj} ->
                    {:cont, {:ok, [{object_id, obj} | acc]}}

                  {:error, :unsupported_object_type} when ignore_unsupported_object_types ->
                    {:cont, {:ok, acc}}

                  {:error, err} ->
                    cond do
                      ignore_errors -> {:cont, {:ok, acc}}
                      exit_on_error -> exit({:error, {err, object_id}})
                      true -> {:halt, {:error, {err, object_id}}}
                    end
                end

              term, acc ->
                cond do
                  ignore_errors -> {:cont, acc}
                  exit_on_error -> exit({:error, {:invalid_object_identifier, term}})
                  true -> {:halt, {:error, {:invalid_object_identifier, term}}}
                end
            end)
          end,
          max_concurrency: max_concurrency,
          on_timeout: :kill_task,
          ordered: false,
          timeout: Keyword.get(opts, :task_timeout, 30_000)
        )
        |> Enum.map(fn
          {:exit, reason} when exit_on_error -> exit(reason)
          {:ok, {:ok, _val} = val} -> val
          {:ok, {:error, _err} = err} -> err
          term -> term
        end)

      # Find the first error to return, if not ignoring errors
      find_error =
        unless ignore_errors do
          Enum.find(
            objects_stream,
            &(match?({:exit, _reason}, &1) or match?({:error, _err}, &1))
          )
        end

      case find_error do
        {:error, _err} = err ->
          err

        {:exit, reason} ->
          {:error, reason}

        _else ->
          objects =
            objects_stream
            |> Stream.filter(&match?({:ok, _val}, &1))
            |> Stream.flat_map(fn {:ok, objects} -> objects end)
            |> Enum.group_by(fn {%{type: type}, _obj} -> type end)
            |> Map.new(fn {type, chunk} ->
              objs =
                Map.new(chunk, fn {%{instance: instance}, obj} ->
                  {instance, obj}
                end)

              {type, objs}
            end)

          # There is currently NO value in parallization of this process,
          # however we will keep it here for future usage (if the need arises)
          #
          # |> task_spawn.(
          #   fn [{%{type: type}, _obj} | _tl] = chunk ->
          #     objs = Map.new(chunk, fn {%{instance: instance}, obj} ->
          #       {instance, obj}
          #     end)

          #     {type, objs}
          #   end,
          #   ordered: false,
          #   timeout: Keyword.get(opts, :task_timeout, 30_000)
          # )
          # |> Stream.map(fn
          #   {:exit, reason} when exit_on_error -> exit(reason)
          #   term -> term
          # end)
          # |> Stream.filter(&match?({:ok, _val}, &1))
          # |> Map.new(fn {:ok, term} -> term end)

          {:ok, objects}
      end
    end
  end

  @doc """
  Send a (UTC) Time Synchronization service APDU to the destination.

  `:broadcast` will be resolved to the local broadcast address.

  The following options are available:
  - All options from `BACnet.Stack.Client.send/4`.
  - All options from `BACnet.Protocol.Services.TimeSynchronziation.to_apdu/2` respectively
    `BACnet.Protocol.Services.UtcTimeSynchronziation.to_apdu/2`.
  - `datetime: DateTime.t()` - Optional. The timestamp to use for synchronization.
    It will be automatically shifted to UTC, if necessary.
    If omitted, `DateTime.now!/1` will be used with Time Synchronization -
    if the default timezone is "Etc/UTC", then UTC Time Synchronization will be used.
    The `utc` option overrides the behaviour of the default timezone -
    you may use a non-UTC timezone and still be able to use UTC.
  - `utc: boolean()` - Optional. Whether to use UTC Time Synchronization.
  """
  @spec send_time_synchronization(
          GenServer.server(),
          term(),
          Keyword.t()
        ) :: :ok | {:error, term()}
  def send_time_synchronization(server, destination \\ :broadcast, opts \\ [])

  def send_time_synchronization(server, destination, opts) when is_list(opts) do
    {new_utc, dt} =
      case Keyword.fetch(opts, :datetime) do
        {:ok, dt} ->
          if Keyword.get(opts, :utc, false) do
            {true, DateTime.shift_zone(dt, "Etc/UTC")}
          else
            {false, dt}
          end

        :error ->
          if Keyword.get(opts, :utc, false) do
            {true, DateTime.now!("Etc/UTC")}
          else
            tz = Application.get_env(:bacstack, :default_timezone, "Etc/UTC")
            {tz == "Etc/UTC", DateTime.now!(tz)}
          end
      end

    sync_apdu =
      if new_utc do
        Services.UtcTimeSynchronization.to_apdu(
          %Services.UtcTimeSynchronization{
            date: BACnetDate.from_date(DateTime.to_date(dt)),
            time: BACnetTime.from_time(DateTime.to_time(dt))
          },
          opts
        )
      else
        Services.TimeSynchronization.to_apdu(
          %Services.TimeSynchronization{
            date: BACnetDate.from_date(DateTime.to_date(dt)),
            time: BACnetTime.from_time(DateTime.to_time(dt))
          },
          opts
        )
      end

    with {:ok, apdu} <- sync_apdu,
         {:ok, addr} <- get_address(server, destination) do
      Client.send(server, addr, apdu, Keyword.drop(opts, [:datetime, :utc]))
    end
  end

  @doc """
  Subscribes for COV notification for a remote BACnet object property.

  When using confirmed COV notifications, the remote BACnet device requires
  you to send confirmations of the reception (`BACnet.Protocol.Services.SimpleACK`) -
  this is not done automatically.

  The following options are available:
  - All options from `BACnet.Stack.Client.send/4`.
  - All options from `BACnet.Protocol.Services.SubscribeCovProperty.to_apdu/2`.
  - `confirmed: boolean()` - Optional. Request confirmed COV notifications.
    By default, COV notifications are requested to be unconfirmed.
  - `cov_increment: float()` - Optional. The COV increment to use for float properties.
  - `lifetime: non_neg_integer() | nil` - Optional. The COV subscription lifetime to use
    in seconds (defaults to 3600). To unsubscribe, use `nil`.
  - `pid: non_neg_integer()` - Optional. The process identifier to use. By default,
    this will be calculated from the caller PID (`node bits 0-3 << 28 + pid_number << 13 + pid_serial`).
  """
  @spec subscribe_cov_property(
          GenServer.server(),
          term(),
          ObjectIdentifier.t(),
          Constants.property_identifier(),
          Keyword.t()
        ) ::
          :ok
          | {:error, BACnet.Protocol.apdu()}
          | {:error, term()}
  def subscribe_cov_property(
        server,
        destination,
        %ObjectIdentifier{} = object,
        property,
        opts \\ []
      )
      when ((is_atom(property) and property not in [:all, :required, :optional]) or
              (is_integer(property) and property >= 0)) and
             is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "subscribe_cov_property/5 expected opts to be a keyword list, " <>
              "got: #{inspect(opts)}"
    end

    confirmed = Keyword.get(opts, :confirmed, false)
    lifetime = Keyword.get(opts, :lifetime, 3600)
    cov_increment = if lifetime, do: Keyword.get(opts, :cov_increment), else: nil

    pid =
      Keyword.get_lazy(opts, :pid, fn ->
        [node, pid, pid2] =
          self()
          |> :erlang.pid_to_list()
          |> :binary.list_to_bin()
          |> then(&Regex.scan(~r/<(\d+)\.(\d+)\.(\d+)>/, &1))
          # Get the first match list in the list
          |> hd()
          # Remove the full match from the list
          |> tl()
          |> Enum.map(&String.to_integer/1)

        Bitwise.bsl(Bitwise.band(node, 0x0F), 28) + Bitwise.bsl(pid, 13) + pid2
      end)

    with {:ok, req} <-
           Services.SubscribeCovProperty.to_apdu(
             %Services.SubscribeCovProperty{
               process_identifier: pid,
               monitored_object: object,
               issue_confirmed_notifications: confirmed,
               lifetime: lifetime,
               monitored_property: %PropertyRef{
                 property_identifier: property,
                 property_array_index: opts[:array_index]
               },
               cov_increment: cov_increment
             },
             opts
           ),
         {:ok, %APDU.SimpleACK{} = _apdu} <- Client.send(server, destination, req, opts) do
      :ok
    else
      {:ok, apdu} -> {:error, apdu}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Sends a Who-Is service request to the network (local broadcast).
  The I-Am responses will be collected and returned.

  See also `BACnet.Protocol.Services.WhoIs`.

  By default, it will collect all responses received until `timeout`.
  By using `max` opts, one can tell the function how many to receive
  and then stop prematurely. Either `max` or `timeout` will stop
  the collecting. Timeout must be minimum `10`ms.

  This function will by default spawn a new task and subscribe for
  BACnet notification messages and afterwards unsubscribe.
  This behaviour can be disabled through `no_subscribe` opts.

  The following options are available, in addition the `Client.send/4` options:
  - `apdu_destination: term()` - Optional. Overrides the APDU destination address.
  - `high_limit: pos_integer()` - Optional. The maximum BACnet device ID for the Who-Is query.
  - `low_limit: pos_integer()` - Optional. The minimum BACnet device ID for the Who-Is query.
  - `max: pos_integer()` - Optional. The maximum amount of IAm responses to collect.
  - `no_subscribe: boolean()` - Optional. Whether to spawn a new task.
  """
  @spec who_is(GenServer.server(), pos_integer(), Keyword.t()) ::
          {:ok, [{source_address :: term(), Services.IAm.t()}]} | {:error, term()}
  def who_is(server, timeout \\ 5000, opts \\ [])
      when is_integer(timeout) and timeout >= 10 and is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "who_is/3 expected opts to be a keyword list, " <>
              "got: #{inspect(opts)}"
    end

    who_is = %Services.WhoIs{
      device_id_low_limit: opts[:low_limit],
      device_id_high_limit: opts[:high_limit]
    }

    dest =
      case Keyword.fetch(opts, :apdu_destination) do
        {:ok, _val} = val -> val
        _else -> GenServer.call(server, :get_broadcast_address)
      end

    with {:ok, broadcast} <- dest,
         req_opts =
           Keyword.drop(opts, [:high_limit, :low_limit, :no_subscribe, :apdu_destination]),
         {:ok, req} <- Services.WhoIs.to_apdu(who_is, []) do
      if opts[:no_subscribe] do
        do_who_is(server, timeout, req, broadcast, req_opts, opts)
      else
        task = Task.async(fn -> do_who_is(server, timeout, req, broadcast, req_opts, opts) end)
        Task.await(task, trunc(timeout * 1.5))
      end
    end
  end

  @doc """
  Write to a single property of a remote BACnet object.

  Either the actual value of the property can be given and then the value will
  be automatically encoded through `BACnet.Protocol.ObjectsUtility`.
  Or an `Encoding` struct (or list of) can be given, which will be used
  directly without validation.

  The following options are available:
  - All options from `BACnet.Stack.Client.send/4`.
  - All options from `BACnet.Protocol.Services.WriteProperty.to_apdu/2`.
  - `array_index: non_neg_integer() | nil` - Optional. The property array index to write to.
  - `priority: 1..16 | nil` - Optional. The BACnet priority to write to.
  """
  @spec write_property(
          GenServer.server(),
          term(),
          ObjectIdentifier.t(),
          Constants.property_identifier() | non_neg_integer(),
          term() | Encoding.t() | [Encoding.t()],
          Keyword.t()
        ) ::
          :ok
          | {:error, BACnet.Protocol.apdu()}
          | {:error, term()}
  def write_property(server, destination, object, property, value, opts \\ [])

  def write_property(
        server,
        destination,
        %ObjectIdentifier{} = object,
        property,
        %Encoding{} = value,
        opts
      )
      when ((is_atom(property) and property not in [:all, :required, :optional]) or
              (is_integer(property) and property >= 0)) and
             is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "write_property/6 expected opts to be a keyword list, " <>
              "got: #{inspect(opts)}"
    end

    do_write_property(server, destination, object, property, value, opts)
  end

  def write_property(
        server,
        destination,
        %ObjectIdentifier{} = object,
        property,
        value,
        opts
      )
      when ((is_atom(property) and property not in [:all, :required, :optional]) or
              (is_integer(property) and property >= 0)) and
             is_list(value) and
             is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "write_property/6 expected opts to be a keyword list, " <>
              "got: #{inspect(opts)}"
    end

    if Enum.all?(value, &is_struct(&1, Encoding)) do
      do_write_property(server, destination, object, property, value, opts)
    else
      cast_opts =
        if property == :present_value and opts[:priority] do
          Keyword.put(opts, :allow_nil, true)
        else
          opts
        end

      cast_opts = Keyword.put(cast_opts, :allow_partial, opts[:array_index] != nil)

      with {:ok, result} <-
             ObjectsUtility.cast_value_to_property(object, property, value, cast_opts) do
        do_write_property(server, destination, object, property, result, opts)
      end
    end
  end

  def write_property(
        server,
        destination,
        %ObjectIdentifier{} = object,
        property,
        value,
        opts
      )
      when is_atom(property) and property not in [:all, :required, :optional] and
             is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "write_property/6 expected opts to be a keyword list, " <>
              "got: #{inspect(opts)}"
    end

    cast_opts =
      if property == :present_value and opts[:priority] do
        Keyword.put(opts, :allow_nil, true)
      else
        opts
      end

    cast_opts = Keyword.put(cast_opts, :allow_partial, opts[:array_index] != nil)

    with {:ok, result} <-
           ObjectsUtility.cast_value_to_property(object, property, value, cast_opts) do
      do_write_property(server, destination, object, property, result, opts)
    end
  end

  @doc """
  Write to multiple properties of a remote BACnet object.

  Either the actual value of the property can be given and then the value will
  be automatically encoded through `BACnet.Protocol.ObjectsUtility`.
  Or an `Encoding` struct (or list of) can be given, which will be used
  directly without validation.

  Prioritized property access is not possible with this function.
  Use `write_property/6` instead if you need to write to a specific priority.
  You can however write to specific array indexes.

  The following options are available:
  - All options from `BACnet.Stack.Client.send/4`.
  - All options from `BACnet.Protocol.Services.WritePropertyMultiple.to_apdu/2`.
  """
  @spec write_property_multiple(
          GenServer.server(),
          term(),
          ObjectIdentifier.t(),
          %{
            optional(property_identifier) => value | {array_index :: non_neg_integer(), value}
          }
          | [
              {property_identifier, value | {array_index :: non_neg_integer(), value}}
              | {property_identifier, array_index :: non_neg_integer(), value}
              | AccessSpecification.Property.t()
            ],
          Keyword.t()
        ) ::
          :ok
          | {:error, Services.Error.WritePropertyMultipleError.t()}
          | {:error, BACnet.Protocol.apdu()}
          | {:error, term()}
        when property_identifier: Constants.property_identifier() | non_neg_integer(),
             value: term() | Encoding.t() | [term() | Encoding.t()]
  def write_property_multiple(server, destination, object, properties, opts \\ [])

  def write_property_multiple(server, destination, %ObjectIdentifier{} = object, properties, opts)
      when (is_map(properties) or is_list(properties)) and is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "write_property_multiple/5 expected opts to be a keyword list, " <>
              "got: #{inspect(opts)}"
    end

    with {:ok, {properties, _opts}} <-
           Enum.reduce_while(
             properties,
             {:ok, {[], opts}},
             &validate_write_property_multiple_prop(&1, &2, object)
           ),
         {:ok, req} <-
           Services.WritePropertyMultiple.to_apdu(
             %Services.WritePropertyMultiple{
               list: [
                 %AccessSpecification{
                   object_identifier: object,
                   properties: Enum.reverse(properties)
                 }
               ]
             },
             opts
           ),
         {:ok, %APDU.SimpleACK{}} <- Client.send(server, destination, req, opts) do
      :ok
    else
      {:ok, %APDU.Error{service: :write_property_multiple} = error} ->
        case Services.Error.WritePropertyMultipleError.from_apdu(error) do
          {:ok, error} -> error
          _other -> {:error, error}
        end

      {:ok, apdu} ->
        {:error, apdu}

      {:error, _err} = err ->
        err
    end
  end

  defp do_write_property(
         server,
         destination,
         %ObjectIdentifier{} = object,
         property,
         value,
         opts
       ) do
    with {:ok, req} <-
           Services.WriteProperty.to_apdu(
             %Services.WriteProperty{
               object_identifier: object,
               property_identifier: property,
               property_array_index: opts[:array_index],
               property_value: value,
               priority: opts[:priority]
             },
             opts
           ),
         {:ok, %APDU.SimpleACK{}} <- Client.send(server, destination, req, opts) do
      :ok
    else
      {:ok, apdu} -> {:error, apdu}
      {:error, _err} = err -> err
    end
  end

  @spec validate_write_property_multiple_prop(
          {non_neg_integer() | atom(), non_neg_integer() | nil,
           term() | Encoding.t() | [term() | Encoding.t()]}
          | {non_neg_integer() | atom(), term() | Encoding.t() | [term() | Encoding.t()]}
          | AccessSpecification.Property.t(),
          {:ok, term()},
          ObjectIdentifier.t()
        ) :: {:cont, term()} | {:halt, term()}
  defp validate_write_property_multiple_prop(property, acc, object)

  defp validate_write_property_multiple_prop(
         %AccessSpecification.Property{} = property,
         {:ok, {acc, opts}},
         _object
       ) do
    {:cont,
     {:ok,
      {[
         property
         | acc
       ], opts}}}
  end

  # Map form: %{key => {index, value}}
  defp validate_write_property_multiple_prop({key, {index, value}}, acc, object)
       when (is_integer(index) and index >= 0) or is_nil(index) do
    validate_write_property_multiple_prop({key, index, value}, acc, object)
  end

  defp validate_write_property_multiple_prop(
         {property_identifier, index, %Encoding{} = value},
         acc,
         object
       )
       when is_atom(property_identifier) do
    case Constants.by_name(:property_identifier, property_identifier) do
      {:ok, identifier} ->
        validate_write_property_multiple_prop({identifier, index, value}, acc, object)

      :error ->
        {:halt, {:error, {:invalid_property, property_identifier}}}
    end
  end

  defp validate_write_property_multiple_prop(
         {property_identifier, index, %Encoding{} = value},
         {:ok, {acc, opts}},
         _object
       )
       when is_integer(property_identifier) and
              property_identifier >= 0 and
              ((is_integer(index) and index >= 0) or is_nil(index)) do
    {:cont,
     {:ok,
      {[
         %AccessSpecification.Property{
           property_identifier: property_identifier,
           property_array_index: index,
           property_value: value
         }
         | acc
       ], opts}}}
  end

  defp validate_write_property_multiple_prop(
         {property_identifier, index, value},
         {:ok, {acc, opts}},
         object
       )
       when is_list(value) and ((is_integer(index) and index >= 0) or is_nil(index)) do
    with :ok <-
           (cond do
              is_atom(property_identifier) and
                  Constants.has_by_name(:property_identifier, property_identifier) ->
                :ok

              is_integer(property_identifier) and property_identifier >= 0 ->
                :ok

              true ->
                {:halt, {:error, {:invalid_property, property_identifier}}}
            end),
         {:ok, list} <-
           Enum.reduce_while(value, {:ok, []}, fn
             %Encoding{} = val, {:ok, acc} ->
               {:cont, {:ok, [val | acc]}}

             val, {:ok, acc} ->
               if is_atom(property_identifier) do
                 case ObjectsUtility.cast_value_to_property(
                        object,
                        property_identifier,
                        val,
                        opts
                      ) do
                   {:ok, new_val} -> {:cont, {:ok, [new_val | acc]}}
                   {:error, err} -> {:halt, {:halt, {:error, {:convert_failure, err}}}}
                 end
               else
                 {:halt, {:error, {:unable_to_convert, property_identifier}}}
               end
           end) do
      {:ok,
       {[
          %AccessSpecification.Property{
            property_identifier: property_identifier,
            property_array_index: index,
            property_value: Enum.reverse(list)
          }
          | acc
        ], opts}}
    end
  end

  defp validate_write_property_multiple_prop(
         {property_identifier, index, value},
         {:ok, {acc, opts}},
         object
       )
       when not is_struct(value, Encoding) and
              ((is_integer(index) and index >= 0) or is_nil(index)) do
    with :ok <-
           (if is_atom(property_identifier) and
                 Constants.has_by_name(:property_identifier, property_identifier) do
              :ok
            else
              {:halt, {:error, {:invalid_property, property_identifier}}}
            end),
         {:ok, val} <-
           ObjectsUtility.cast_value_to_property(
             object,
             property_identifier,
             value,
             opts
           ) do
      {:cont,
       {:ok,
        {[
           %AccessSpecification.Property{
             property_identifier: property_identifier,
             property_array_index: index,
             property_value: val
           }
           | acc
         ], opts}}}
    end
  end

  defp validate_write_property_multiple_prop({property_identifier, value}, acc, object) do
    validate_write_property_multiple_prop({property_identifier, nil, value}, acc, object)
  end

  defp validate_write_property_multiple_prop(tupval, _acc, _object) do
    {:halt, {:error, {:invalid_tuple_or_index, tupval}}}
  end

  defp get_address(server, :broadcast), do: GenServer.call(server, :get_broadcast_address)
  defp get_address(_server, addr), do: {:ok, addr}

  @spec make_access_property_from_identifier(
          AccessSpecification.Property.t()
          | Constants.property_identifier()
          | non_neg_integer()
          | term()
        ) :: AccessSpecification.Property.t() | no_return()
  defp make_access_property_from_identifier(%AccessSpecification.Property{} = identifier),
    do: identifier

  defp make_access_property_from_identifier(identifier)
       when identifier in [:all, :required, :optional],
       do: identifier

  defp make_access_property_from_identifier(identifier)
       when is_atom(identifier) or (is_integer(identifier) and identifier >= 0) do
    %AccessSpecification.Property{
      property_identifier: identifier,
      property_array_index: nil,
      property_value: nil
    }
  end

  defp make_access_property_from_identifier(identifier) do
    raise ArgumentError, "Invalid property identifier, got: #{inspect(identifier)}"
  end

  defp do_who_is(server, timeout, req, broadcast, req_opts, opts) do
    no_subscribe = opts[:no_subscribe]

    with :ok <-
           if(no_subscribe,
             do: :ok,
             else: Client.subscribe(server, self())
           ),
         :ok <- Client.send(server, broadcast, req, req_opts) do
      ref = make_ref()
      timer = Process.send_after(self(), {__MODULE__, :stop_who_is, ref}, timeout)

      max_items = opts[:max]

      iams =
        Enum.reduce_while(1..10_000_000, [], fn _index, acc ->
          if max_items > 0 and length(acc) >= max_items do
            {:halt, acc}
          else
            receive do
              {:bacnet_client, _ref,
               %APDU.UnconfirmedServiceRequest{
                 service: Constants.macro_assert_name(:unconfirmed_service_choice, :i_am)
               } = apdu, {source_addr, _bvlc, _npci}, _pid} ->
                case Services.IAm.from_apdu(apdu) do
                  {:ok, service} ->
                    {:cont, [{source_addr, service} | acc]}

                  {:error, err} ->
                    log_debug(fn ->
                      "ClientHelper.who_is/3 encountered an error during " <>
                        "APDU to service transformation, error: #{inspect(err)}"
                    end)

                    {:cont, acc}
                end

              {__MODULE__, :stop_who_is, ^ref} ->
                {:halt, acc}
            end
          end
        end)

      # Cleanup subscription (if done)
      unless no_subscribe do
        Client.unsubscribe(server, self())
      end

      # Cleanup timer
      Process.cancel_timer(timer)

      # Receive timer in case it was sent before cancellation (and after reduce)
      receive do
        {__MODULE__, :stop_who_is, ^ref} -> :ok
      after
        0 -> :ok
      end

      {:ok, iams}
    end
  end
end
