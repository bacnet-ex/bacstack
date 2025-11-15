defmodule BACnet.Stack.TransportBehaviour do
  @moduledoc """
  Defines the BACnet transport protocol behaviour.

  It ensures all implemented transport layer can be easily integrated
  into the Elixir BACnet client, indepedently of the underlying
  physical transport layer (IP, MS/TP, etc.).
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.NPCI
  alias BACnet.Protocol.NpciTarget
  alias BACnet.Stack.EncoderProtocol

  require Constants

  @typedoc """
  Represents a transport module portal.
  """
  @type portal :: pid() | port() | :socket.socket() | term()

  @typedoc """
  Represents a transport module reference.
  """
  @type transport :: pid() | port() | GenServer.server() | :socket.socket() | term()

  @typedoc """
  Transport callback.

  Callback may be a Module-Function-Arity tuple, a PID (where the data is sent to as a message)
  or an anonymous function.
  The MFA has the same arguments as the anonymous function. As such, the arity needs to be 3.
  The return value is ignored.
  """
  @type transport_callback ::
          mfa()
          | Process.dest()
          | (source_address :: term(), frame :: transport_cb_frame(), portal :: portal() ->
               any())

  @typedoc """
  Transport Callback Frames. The callback may ignore any non-APDU frames, if they do not
  wish to handle them.

  The APDU is uninterpreted binary data and needs to be decoded first, through the `BACnet.Protocol` module.
  """
  @type transport_cb_frame ::
          {:bvlc, bvlc :: Protocol.bvlc()}
          | {:network, bvlc :: Protocol.bvlc(), npci :: NPCI.t() | nil,
             nsdu :: Protocol.NetworkLayerProtocolMessage.t()}
          | {:apdu, bvlc :: Protocol.bvlc(), npci :: NPCI.t() | nil, apdu :: binary()}

  @typedoc """
  BACnet transport identifier, represented by the protocol and the implementing transport module.
  """
  @type transport_id :: {transport_protocol(), module()}

  @typedoc """
  Transport message structure.
  """
  @type transport_msg ::
          {:bacnet_transport, transport_id(), source_address :: term(),
           data :: transport_cb_frame(), portal :: portal()}

  @typedoc """
  BACnet transport protocols.
  """
  @type transport_protocol ::
          :bacnet_arcnet
          | :bacnet_ethernet
          | :bacnet_ipv4
          | :bacnet_ipv6
          | :bacnet_lontalk
          | :bacnet_mstp
          | :bacnet_ptp
          | :bacnet_sc

  @typedoc """
  Valid transport send options. For a description of each, see `c:send/4`.
  """
  @type transport_send_option ::
          {:destination, NpciTarget.t()}
          | {:npci, NPCI.t() | false}
          | {:skip_headers, boolean()}
          | {:source, NpciTarget.t()}

  @doc """
  Opens/starts the Transport module. If a process is started, it is linked to the caller process.

  The callback argument can be one of PID (resp. `t:Process.dest/0`), MFA tuple or a three arity function.
  In case of a PID, the `t:transport_msg/0` structure is sent as message. Otherwise the function or MFA tuple
  gets invoked with the arguments: `source_address :: term(), frame :: transport_cb_frame(), portal :: portal()`.
  The function or MFA tuple may be run under a standalone task or a supervisored task.

  The source address is any term and depends on the transport protocol. The portal is a term, where
  the BACnet data is received from and sent to. The portal may be the same as the transport, but must
  not be assumed it is. Sending data must always be directed to the portal and not to the transport.
  Some transports may use "grouping data structures" to avoid going through processes and build
  bottlenecks on busy networks.
  """
  @callback open(
              callback :: transport_callback(),
              opts :: Keyword.t()
            ) :: {:ok, transport :: transport()} | {:error, term()}

  @doc """
  Closes the Transport module.
  """
  @callback close(transport :: transport()) :: :ok

  @doc """
  Get the BACnet transport protocol this transport implements.
  """
  @callback bacnet_protocol() :: transport_protocol()

  @doc """
  Get the maximum APDU length for this transport.
  """
  @callback max_apdu_length() :: pos_integer()

  @doc """
  Get the maximum NPDU length for this transport.

  The NPDU length contains the maximum transmittable size
  of the NPDU, including the APDU, without violating
  the maximum transmission unit of the underlying transport.

  Any necessary transport header (i.e. BVLL, LLC) must have
  been taken into account when calculating this number.
  """
  @callback max_npdu_length() :: pos_integer()

  @doc """
  Get the broadcast address.
  """
  @callback get_broadcast_address(transport :: transport()) :: term()

  @doc """
  Get the local address.
  """
  @callback get_local_address(transport :: transport()) :: term()

  @doc """
  Get the transport module portal for the given transport PID/port.
  Transport modules may return the input as output, if the same
  PID or port is used for sending.

  This is used to get the portal before having received data from
  the transport module, so data can be sent prior to reception.
  """
  @callback get_portal(transport :: transport()) :: portal()

  @doc """
  Checks whether the given destination is an address that needs to be routed.
  """
  @callback is_destination_routed(transport :: transport(), address :: term()) :: boolean()

  @doc """
  Verifies whether the given destination is valid for the transport module.
  """
  @callback is_valid_destination(destination :: term()) :: boolean()

  @doc """
  Sends data to the BACnet network.

  Segmentation and respect to APDU length needs to be handled by the caller. The transport module will raise,
  if the maximum APDU/NPDU length is exceeded.

  The data is a struct implementing the Encoder Protocol, or must be already encoded (iodata).

  By default, the BACnet Virtual Link Layer, or similar, and Network Protocol Data Unit are added,
  if either of those are required by the transport.

  The following options are available (unless specified otherwise by the transport):
  - `destination: NpciTarget.t()` - Optional. Sets the `destination` (DNET, DADDR, DLEN) in the
    NPCI header accordingly (defaults to absent). A value of `nil` should be treated as option absent.
  - `npci: NPCI.t() | false` - Optional. The NPCI to use. If omitted, the NPCI will be calculated.
    If the `npci` option is present, options `destination` and `source` will be ignored.
    `false` can be used to omit the NPCI completely from the BACnet packet (i.e. for pure BVLL packets).
  - `skip_headers: boolean()` - Optional. Skips adding all headers for the transport protocol (i.e. BVLL, NPCI).
  - `source: NpciTarget.t()` - Optional. Sets the `source` (SNET, SADDR, SLEN) in the
    NPCI header accordingly (defaults to absent). A value of `nil` should be treated as option absent.
  """
  @callback send(
              portal :: portal(),
              destination :: term(),
              data :: EncoderProtocol.t() | iodata(),
              opts :: Keyword.t()
            ) :: :ok | {:error, term()}

  @doc """
  Produces a supervisor child spec based on the BACnet transport `open` callback, as such
  it will take the `callback` and `opts` for `c:open/2`.

  See also `Supervisor.child_spec/2` for the rest of the behaviour.
  """
  @spec child_spec(module(), transport_callback(), Keyword.t(), Keyword.t()) ::
          Supervisor.child_spec()
  def child_spec(module, callback, opts \\ [], child_spec) do
    Supervisor.child_spec(
      module,
      Keyword.put(child_spec, :start, {module, :open, [callback, opts]})
    )
  end

  @doc """
  Builds the BACnet packet common parts. It is used in transports for common tasks.

  It encodes the given APDU (if struct), encodes the NPDU (if not skipping headers)
  and validates common grounds between all transports.

  When the NPCI is not present in `opts`, it will be calculated from the payload.
  `NPCI.new/1` is used to create the NPCI with `destination`, `expects_reply`
  and `source` set.

  The following gets validated:
  - `expects_reply` in NPCI is not set if broadcast
  - Valid `destination` option (is a `NpciTarget` struct - `address` is not validated)
  - Valid `source` option (is a `NpciTarget` struct - `address` is not validated)

  The following options of `c:send/4` are used:
  - `destination: NpciTarget.t()`
  - `npci: NPCI.t()`
  - `skip_headers: boolean()`
  - `source: NpciTarget.t()`
  """
  @spec build_bacnet_packet(iodata() | struct(), boolean(), Keyword.t()) ::
          {:ok, {npci :: iodata(), apdu :: iodata()}} | {:error, term()}
  def build_bacnet_packet(apdu, is_broadcast, opts)
      when is_boolean(is_broadcast) and is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError, "build_bacnet_packet/3 expected a keyword list, got: #{inspect(opts)}"
    end

    new_opts =
      case Keyword.fetch(opts, :npci) do
        {:ok, %NPCI{} = value} ->
          Keyword.put_new(opts, :expects_reply, value.expects_reply)

        _other ->
          if is_struct(apdu) do
            Keyword.put_new_lazy(opts, :expects_reply, fn ->
              EncoderProtocol.expects_reply(apdu)
            end)
          else
            Keyword.put_new_lazy(opts, :expects_reply, fn ->
              apdu_expects_reply(expand_data_to_binary(apdu))
            end)
          end
      end

    with :ok <-
           (if is_broadcast and new_opts[:expects_reply] do
              {:error, :invalid_expects_reply_for_broadcast}
            else
              :ok
            end),
         {:ok, bin_data} <-
           (if is_struct(apdu) do
              do_encode_struct(apdu)
            else
              {:ok, apdu}
            end),
         {:ok, npci_data} <-
           (if Keyword.get(new_opts, :skip_headers) do
              {:ok, []}
            else
              {:ok, do_encode_npci(apdu, is_broadcast, new_opts)}
            end) do
      {:ok, {npci_data, bin_data}}
    end
  end

  @spec do_encode_struct(EncoderProtocol.t()) :: {:ok, iodata()} | {:error, term()}
  defp do_encode_struct(data) do
    {:ok, EncoderProtocol.encode(data)}
  rescue
    e -> {:error, {e, __STACKTRACE__}}
  catch
    _, e -> {:error, e}
  end

  @spec do_encode_npci(iodata(), boolean(), Keyword.t()) :: iodata()
  defp do_encode_npci(_apdu, is_broadcast, opts)
       when is_boolean(is_broadcast) and is_list(opts) do
    npci =
      case opts[:npci] do
        nil ->
          destination =
            case opts[:destination] do
              nil ->
                if is_broadcast do
                  %NpciTarget{
                    net: 65_535,
                    address: nil
                  }
                else
                  nil
                end

              %NpciTarget{net: net} = addr when net in 1..65_535 ->
                addr

              term ->
                raise ArgumentError, "Invalid destination opts value, got: #{inspect(term)}"
            end

          source =
            case opts[:source] do
              nil ->
                nil

              %NpciTarget{net: net} = addr when net in 1..65_534 ->
                addr

              term ->
                raise ArgumentError, "Invalid source opts value, got: #{inspect(term)}"
            end

          NPCI.new(
            destination: destination,
            expects_reply: !!Keyword.fetch!(opts, :expects_reply),
            source: source
          )

        false ->
          nil

        %NPCI{} = npci ->
          npci

        term ->
          raise ArgumentError, "Invalid NPCI opts value, got: #{inspect(term)}"
      end

    if is_broadcast and npci != nil and npci.expects_reply do
      raise ArgumentError, "Invalid NPCI, broadcast can not expect reply"
    end

    if npci, do: NPCI.encode(npci), else: ""
  end

  # Expands the iodata and only gets the first byte, if not a binary
  @spec expand_data_to_binary(iodata() | byte()) :: binary()
  defp expand_data_to_binary(data) do
    case data do
      _bin when is_binary(data) -> data
      _ing when data >= 0 and data <= 255 -> <<data>>
      [] -> <<>>
      [[] | tl] -> expand_data_to_binary(tl)
      [hd | _tl] -> expand_data_to_binary(hd)
    end
  end

  @spec apdu_expects_reply(binary()) :: boolean()
  defp apdu_expects_reply(apdu)

  defp apdu_expects_reply(
         <<Constants.macro_by_name(:pdu_type, :confirmed_request)::size(4), _rest::bitstring>>
       ),
       do: true

  # A segmented Complex-ACK also expects a reply (in the form of a Segment-ACK)
  defp apdu_expects_reply(
         <<Constants.macro_by_name(:pdu_type, :complex_ack)::size(4), _filler::size(1),
           1::size(1), _rest::bitstring>>
       ),
       do: true

  defp apdu_expects_reply(_apdu), do: false
end
