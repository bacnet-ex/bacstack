# This example starts all necessary processes and scans the BACnet network for devices.
# Each device will then have their device object scanned.
# The result is printed to the output.

alias BACnet.Protocol.BACnetArray
alias BACnet.Protocol.BACnetDateTime
alias BACnet.Protocol.Services.IAm
alias BACnet.Protocol.ObjectTypes.Device
alias BACnet.Stack.Client
alias BACnet.Stack.ClientHelper
alias BACnet.Stack.Segmentator
alias BACnet.Stack.SegmentsStore
alias BACnet.Stack.Transport.IPv4Transport

# Set Log level to info to not get flooded by debug messages
# If you have discovery issues, you might want to put this after the process starts,
# to find out on which network interface we're listening
Logger.configure(level: :info)

# Start all necessary processes
# See the documentation if you need to start the transport layer on a specific network adapter

{:ok, _pid} = IPv4Transport.open(Client, name: IPv4Transport)
{:ok, _pid} = Segmentator.start_link(name: Segmentator)
{:ok, _pid} = SegmentsStore.start_link(name: SegmentsStore)

{:ok, _pid} =
  Client.start_link(
    name: Client,
    segmentator: Segmentator,
    segments_store: SegmentsStore,
    transport: IPv4Transport
  )

IO.puts("Sending broadcast WhoIs service request to BACnet network...")

# Send broadcast Who-Is service request and wait 10 seconds for all responses
{:ok, iam_responses} = ClientHelper.who_is(Client, 10_000)

IO.puts("#{length(iam_responses)} device(s) responded, scanning now all found devices...")

# Now iterate over the responses and read the BACnet Device object to display some data
for {{dest_ip, dest_port}, %IAm{} = iam} <- iam_responses do
  case ClientHelper.read_object(Client, {dest_ip, dest_port}, iam.device,
         allow_unknown_properties: true
       ) do
    {:ok, %Device{} = device} ->
      objects_count = BACnetArray.size(device.object_list)

      IO.puts(
        "Found device #{device.object_name} (ID #{iam.device.instance}) on IP address #{:inet.ntoa(dest_ip)}:#{dest_port}:\n" <>
          "\t using BACnet protocol revision #{device.protocol_revision}, \n" <>
          "\t with segmentation supported #{device.segmentation_supported} (max. #{device.max_segments_accepted} segments), \n" <>
          "\t application uses firmware version #{device.firmware_revision}, \n" <>
          "\t it offers #{objects_count} object(s), \n" <>
          "\t the device is approximately running since " <>
          NaiveDateTime.to_iso8601(
            BACnetDateTime.to_naive_datetime!(device.time_of_device_restart.datetime)
          ) <> "\n"
      )

    {:error, err} ->
      IO.puts(
        "Found device with ID #{iam.device.instance} on IP address #{:inet.ntoa(dest_ip)}:#{dest_port}, " <>
          "however reading the device object failed for reason " <> inspect(err)
      )
  end
end
