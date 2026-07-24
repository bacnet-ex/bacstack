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
    certificate_signing_request_file: 509,
    command_validation_result: 510,
    issuer_certificate_files: 511,
    message_text: 512,
    subscription_type: 513,
    ee_cov_resubscription_interval: 514,
    poll_interval: 515,
    timezone_string: 516,
    timezone: 517,
    time_before_operation: 518,
    pulse_value_source: 519,
    input_count_value: 521,
    loop_enable: 523,
    loop_mode: 524

  config :bacstack, :objects_additional_properties,
    accumulator:
      (quote do
         field(:input_count_value, non_neg_integer())
         field(:pulse_value_source, BACnet.Protocol.DeviceObjectPropertyRef.t())
       end),
    device:
      (quote do
         # Intrinsic Reporting was added in 135-2016
         # services(intrinsic: true)

         field(:device_uuid, binary(),
           annotation: [decoder: fn %{value: value} -> Base.encode16(value) end],
           readonly: true
         )

         field(:timezone_string, String.t())
         field(:timezone, String.t())
       end),
    event_enrollment:
      (quote do
         field(:ee_cov_resubscription_interval, non_neg_integer())
         field(:poll_interval, non_neg_integer())

         field(
           :subscription_type,
           :confirmed_cov_if_possible | :polling | :unconfirmed_cov_if_possible,
           bac_type:
             {:in_list, [:confirmed_cov_if_possible, :polling, :unconfirmed_cov_if_possible]},
           annotation: [
             encoder: fn val ->
               case val do
                 :confirmed_cov_if_possible -> {:enumerated, 0}
                 :polling -> {:enumerated, 1}
                 :unconfirmed_cov_if_possible -> {:enumerated, 3}
                 _other -> {:error, :invalid_value}
               end
             end,
             decoder: fn val ->
               case val.value do
                 0 -> {:ok, :confirmed_cov_if_possible}
                 1 -> {:ok, :polling}
                 3 -> {:ok, :unconfirmed_cov_if_possible}
                 _other -> {:error, :invalid_value}
               end
             end
           ]
         )
       end),
    loop:
      (quote do
         field(:loop_enable, boolean(), encode_as: :enumerated)

         field(:loop_mode, :bacnet_loop | :plc_loop,
           bac_type: {:in_list, [:bacnet_loop, :plc_loop]},
           annotation: [
             encoder: &{:enumerated, if(&1 == :plc_loop, do: 1, else: 0)},
             decoder: &if(&1.value == 1, do: :plc_loop, else: :bacnet_loop)
           ],
           readonly: true
         )
       end),
    schedule:
      (quote do
         field(:time_before_operation, non_neg_integer(), readonly: true)
       end)
end
