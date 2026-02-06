import Config

config :codepagex, :encodings, [
  :ascii,
  :iso_8859_1,
  "VENDORS/MICSFT/PC/CP850",
  "VENDORS/MICSFT/WINDOWS/CP932"
]

config :bacstack, :default_timezone, "Etc/UTC"

if String.downcase(System.get_env("BACSTACK_ENABLE_WAGO_PROPERTIES", "")) in ["1", "true", "yes"] do
  config :bacstack, :additional_property_identifiers,
    device_uuid: 507,
    timezone_string: 516,
    timezone: 517,
    time_before_operation: 518,
    loop_enable: 523,
    loop_mode: 524

  config :bacstack, :objects_additional_properties,
    device:
      (quote do
         # Intrinsic Reporting was added in 135-2016
         # services(intrinsic: true)

         field(:device_uuid, binary(),
           annotation: [decoder: fn %{value: value} -> Base.encode16(value) end]
         )

         field(:timezone_string, String.t())
         field(:timezone, String.t())
       end),
    loop:
      (quote do
         field(:loop_enable, boolean(), encode_as: :enumerated)

         field(:loop_mode, :bacnet_loop | :plc_loop,
           bac_type: {:in_list, [:bacnet_loop, :plc_loop]},
           annotation: [
             encoder: &{:enumerated, if(&1 == :plc_loop, do: 1, else: 0)},
             decoder: &if(&1.value == 1, do: :plc_loop, else: :bacnet_loop)
           ]
         )
       end),
    schedule:
      (quote do
         field(:time_before_operation, non_neg_integer())
       end)
end
