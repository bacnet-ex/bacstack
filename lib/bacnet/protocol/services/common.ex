defmodule BACnet.Protocol.Services.Common do
  @moduledoc """
  This module implements the parsing for some services, which are available as both confirmed
  and unconfirmed. So instead of implementing the same parsing and encoding twice, this module
  is the common ground for these services.
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.APDU.ConfirmedServiceRequest
  alias BACnet.Protocol.APDU.UnconfirmedServiceRequest
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.Services

  import Protocol.Utility, only: [pattern_extract_tags: 4]
  require Constants

  @doc """
  After encode, this function can be used to turn the request parameters into a service request.

  This function is used in the `Services.*` modules. Any wrong usage can only be blamed onto the user themself.
  """
  @spec after_encode_convert(
          map(),
          Keyword.t(),
          module(),
          Constants.confirmed_service_choice() | non_neg_integer()
        ) ::
          {:ok, ConfirmedServiceRequest.t() | UnconfirmedServiceRequest.t()}
  def after_encode_convert(request, request_data, service_type, service_name)

  def after_encode_convert(
        %{parameters: parameters} = _request,
        request_data,
        ConfirmedServiceRequest = _service_type,
        service_name
      ) do
    with segmented_response_accepted <-
           Keyword.get(request_data, :segmented_response_accepted, true),
         true <- is_boolean(segmented_response_accepted),
         max_segments <- Keyword.get(request_data, :max_segments, :more_than_64),
         true <-
           is_integer(max_segments) or max_segments == :unspecified or
             max_segments == :more_than_64,
         max_apdu <-
           Keyword.get(
             request_data,
             :max_apdu,
             Constants.macro_by_name(:max_apdu_length_accepted_value, :octets_1476)
           ),
         true <- is_integer(max_apdu),
         invoke_id <- Keyword.get(request_data, :invoke_id, 0),
         true <- is_integer(invoke_id) and invoke_id >= 0 do
      req = %ConfirmedServiceRequest{
        segmented_response_accepted: segmented_response_accepted,
        max_segments: max_segments,
        max_apdu: max_apdu,
        invoke_id: invoke_id,
        sequence_number: nil,
        proposed_window_size: nil,
        service: service_name,
        parameters: parameters
      }

      {:ok, req}
    else
      false -> {:error, :invalid_parameters}
    end
  end

  def after_encode_convert(
        %{parameters: parameters} = _request,
        _request_data,
        UnconfirmedServiceRequest = _service_type,
        service_name
      ) do
    req = %UnconfirmedServiceRequest{
      service: service_name,
      parameters: parameters
    }

    {:ok, req}
  end

  def after_encode_convert(_request, _request_data, _service_type, _service_name) do
    {:error, :invalid_parameters}
  end

  @doc """
  Decodes the unconfirmed or confirmed cov notification service into a base map.

  This function is used by the `ConfirmedCovNotification` and `UnconfirmedCovNotification` modules.
  """
  @spec decode_cov_notification(
          ConfirmedServiceRequest.t()
          | UnconfirmedServiceRequest.t()
        ) :: {:ok, map()} | {:error, term()}
  def decode_cov_notification(request)
      when is_struct(request, ConfirmedServiceRequest) or
             is_struct(request, UnconfirmedServiceRequest) do
    with {:ok, process_identifier, rest} <-
           pattern_extract_tags(
             request.parameters,
             {:tagged, {0, _t, _l}},
             :unsigned_integer,
             false
           ),
         :ok <-
           if(ApplicationTags.valid_int?(process_identifier, 32),
             do: :ok,
             else: {:error, :invalid_process_identifier_value}
           ),
         {:ok, device_identifier, rest} <-
           pattern_extract_tags(rest, {:tagged, {1, _t, _l}}, :object_identifier, false),
         {:ok, object_identifier, rest} <-
           pattern_extract_tags(rest, {:tagged, {2, _t, _l}}, :object_identifier, false),
         {:ok, time_remaining, rest} <-
           pattern_extract_tags(rest, {:tagged, {3, _t, _l}}, :unsigned_integer, false),
         {:ok, {:constructed, {_t, propvalues_raw, _l}}, _rest} <-
           pattern_extract_tags(rest, {:constructed, {4, _t, _l}}, nil, false),
         {:ok, property_values} <- Protocol.PropertyValue.parse_all(propvalues_raw) do
      event = %{
        process_identifier: process_identifier,
        initiating_device: device_identifier,
        monitored_object: object_identifier,
        time_remaining: time_remaining,
        property_values: property_values
      }

      {:ok, event}
    else
      {:error, :missing_pattern} -> {:error, :invalid_request_parameters}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Encodes the unconfirmed or confirmed COV notification service into a base map.

  This function is used by the `ConfirmedCovNotification` and `UnconfirmedCovNotification` modules.
  """
  @spec encode_cov_notification(
          Services.ConfirmedCovNotification.t()
          | Services.UnconfirmedCovNotification.t(),
          Keyword.t()
        ) :: {:ok, map()} | {:error, term()}
  def encode_cov_notification(service, opts \\ [])
      when is_struct(service, Services.ConfirmedCovNotification) or
             is_struct(service, Services.UnconfirmedCovNotification) do
    with :ok <-
           if(ApplicationTags.valid_int?(service.process_identifier, 32),
             do: :ok,
             else: {:error, :invalid_process_identifier_value}
           ),
         {:ok, process_identifier, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, service.process_identifier}),
         {:ok, device_identifier, _header} <-
           ApplicationTags.encode_value({:object_identifier, service.initiating_device}),
         {:ok, object_identifier, _header} <-
           ApplicationTags.encode_value({:object_identifier, service.monitored_object}),
         {:ok, time_remaining, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, service.time_remaining}),
         {:ok, propvalues} <-
           Protocol.PropertyValue.encode_all(service.property_values, opts) do
      params = [
        {:tagged, {0, process_identifier, byte_size(process_identifier)}},
        {:tagged, {1, device_identifier, byte_size(device_identifier)}},
        {:tagged, {2, object_identifier, byte_size(object_identifier)}},
        {:tagged, {3, time_remaining, byte_size(time_remaining)}},
        {:constructed, {4, propvalues, 0}}
      ]

      req = %{
        parameters: params
      }

      {:ok, req}
    end
  end

  @doc """
  Decodes the unconfirmed or confirmed event notification service into a base map.

  This function is used by the `ConfirmedEventNotification` and `UnconfirmedEventNotification` modules.
  """
  @spec decode_event_notification(
          ConfirmedServiceRequest.t()
          | UnconfirmedServiceRequest.t()
        ) :: {:ok, map()} | {:error, term()}
  def decode_event_notification(request)
      when is_struct(request, ConfirmedServiceRequest) or
             is_struct(request, UnconfirmedServiceRequest) do
    with {:ok, process_identifier, rest} <-
           pattern_extract_tags(
             request.parameters,
             {:tagged, {0, _t, _l}},
             :unsigned_integer,
             false
           ),
         :ok <-
           if(ApplicationTags.valid_int?(process_identifier, 32),
             do: :ok,
             else: {:error, :invalid_process_identifier_value}
           ),
         {:ok, device_identifier, rest} <-
           pattern_extract_tags(rest, {:tagged, {1, _t, _l}}, :object_identifier, false),
         {:ok, object_identifier, rest} <-
           pattern_extract_tags(rest, {:tagged, {2, _t, _l}}, :object_identifier, false),
         {:ok, {:constructed, {_tag, timestamp_raw, _len}}, rest} <-
           pattern_extract_tags(rest, {:constructed, {3, _t, _l}}, nil, false),
         {:ok, {timestamp, _rest}} <- Protocol.BACnetTimestamp.parse(List.wrap(timestamp_raw)),
         {:ok, notification_class, rest} <-
           pattern_extract_tags(rest, {:tagged, {4, _t, _l}}, :unsigned_integer, false),
         {:ok, priority, rest} <-
           pattern_extract_tags(rest, {:tagged, {5, _t, _l}}, :unsigned_integer, false),
         :ok <-
           if(ApplicationTags.valid_int?(priority, 8),
             do: :ok,
             else: {:error, :invalid_priority_value}
           ),
         {:ok, eventtype_raw, rest} <-
           pattern_extract_tags(rest, {:tagged, {6, _t, _l}}, :unsigned_integer, false),
         {:ok, eventtype} <-
           Constants.by_value_with_reason(
             :event_type,
             eventtype_raw,
             {:unknown_event_type, eventtype_raw}
           ),
         {:ok, message_text, rest} <-
           pattern_extract_tags(rest, {:tagged, {7, _t, _l}}, :character_string, true),
         {:ok, notifytype_raw, rest} <-
           pattern_extract_tags(rest, {:tagged, {8, _t, _l}}, :unsigned_integer, false),
         {:ok, notifytype} <-
           Constants.by_value_with_reason(
             :notify_type,
             notifytype_raw,
             {:unknown_notify_type, notifytype_raw}
           ),
         optional = notifytype == :ack_notification,
         {:ok, ack_required, rest} <-
           pattern_extract_tags(rest, {:tagged, {9, _t, _l}}, :boolean, optional),
         {:ok, from_state_raw, rest} <-
           pattern_extract_tags(rest, {:tagged, {10, _t, _l}}, :unsigned_integer, optional),
         {:ok, from_state} <-
           (case from_state_raw do
              nil ->
                {:ok, nil}

              _term ->
                Constants.by_value_with_reason(
                  :event_state,
                  from_state_raw,
                  {:unknown_event_state, from_state_raw}
                )
            end),
         {:ok, to_state_raw, rest} <-
           pattern_extract_tags(rest, {:tagged, {11, _t, _l}}, :unsigned_integer, false),
         {:ok, to_state} <-
           (case to_state_raw do
              nil ->
                {:ok, nil}

              _term ->
                Constants.by_value_with_reason(
                  :event_state,
                  to_state_raw,
                  {:unknown_event_state, to_state_raw}
                )
            end),
         {:ok, eventvalues_raw, _rest} <-
           pattern_extract_tags(rest, {:constructed, {12, _t, _l}}, nil, optional),
         {:ok, event_values} <-
           (case eventvalues_raw do
              nil ->
                {:ok, nil}

              {:constructed, {_t, term, _l}} ->
                Protocol.NotificationParameters.parse(term)
            end) do
      event = %{
        process_identifier: process_identifier,
        initiating_device: device_identifier,
        event_object: object_identifier,
        timestamp: timestamp,
        notification_class: notification_class,
        priority: priority,
        event_type: eventtype,
        message_text: message_text,
        notify_type: notifytype,
        ack_required: ack_required,
        from_state: from_state,
        to_state: to_state,
        event_values: event_values
      }

      {:ok, event}
    else
      {:error, :missing_pattern} -> {:error, :invalid_request_parameters}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Encodes the unconfirmed or confirmed event notification service into a base map.

  This function is used by the `ConfirmedEventNotification` and `UnconfirmedEventNotification` modules.
  """
  @spec encode_event_notification(
          Services.ConfirmedEventNotification.t()
          | Services.UnconfirmedEventNotification.t(),
          Keyword.t()
        ) :: {:ok, map()} | {:error, term()}
  def encode_event_notification(service, opts \\ [])
      when is_struct(service, Services.ConfirmedEventNotification) or
             is_struct(service, Services.UnconfirmedEventNotification) do
    with :ok <-
           if(ApplicationTags.valid_int?(service.process_identifier, 32),
             do: :ok,
             else: {:error, :invalid_process_identifier_value}
           ),
         :ok <-
           if(ApplicationTags.valid_int?(service.priority, 8),
             do: :ok,
             else: {:error, :invalid_priority_value}
           ),
         {:ok, process_identifier, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, service.process_identifier}),
         {:ok, device_identifier, _header} <-
           ApplicationTags.encode_value({:object_identifier, service.initiating_device}),
         {:ok, object_identifier, _header} <-
           ApplicationTags.encode_value({:object_identifier, service.event_object}),
         {:ok, [timestamp]} <- Protocol.BACnetTimestamp.encode(service.timestamp),
         {:ok, notification_class, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, service.notification_class}),
         {:ok, priority, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, service.priority}),
         {:ok, event_type_c} <-
           Constants.by_name_with_reason(
             :event_type,
             service.event_type,
             {:unknown_event_type, service.event_type}
           ),
         {:ok, eventtype, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, event_type_c}),
         {:ok, message_text} <-
           (if service.message_text do
              case ApplicationTags.encode_value({:character_string, service.message_text}) do
                {:ok, message_text, _header} ->
                  {:ok, {:tagged, {7, message_text, byte_size(message_text)}}}

                term ->
                  term
              end
            else
              {:ok, nil}
            end),
         {:ok, notifytype_c} <-
           Constants.by_name_with_reason(
             :notify_type,
             service.notify_type,
             {:unknown_notify_type, service.notify_type}
           ),
         {:ok, notifytype, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, notifytype_c}),
         {:ok, ack_required} <-
           (if service.notify_type != :ack_notification do
              case ApplicationTags.encode_value({:unsigned_integer, service.ack_required}) do
                {:ok, ack_required, _header} ->
                  {:ok, {:tagged, {9, ack_required, byte_size(ack_required)}}}

                term ->
                  term
              end
            else
              {:ok, nil}
            end),
         {:ok, from_state} <-
           (if service.notify_type != :ack_notification and service.from_state do
              with {:ok, from_state_c} <-
                     Constants.by_name_with_reason(
                       :event_state,
                       service.from_state,
                       {:unknown_event_state, service.from_state}
                     ),
                   {:ok, from_state, _header} <-
                     ApplicationTags.encode_value({:unsigned_integer, from_state_c}) do
                {:ok, {:tagged, {10, from_state, byte_size(from_state)}}}
              end
            else
              {:ok, nil}
            end),
         {:ok, to_state_c} <-
           Constants.by_name_with_reason(
             :event_state,
             service.to_state,
             {:unknown_event_state, service.to_state}
           ),
         {:ok, to_state, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, to_state_c}),
         {:ok, event_values} <-
           (if service.event_values do
              case Protocol.NotificationParameters.encode(service.event_values, opts) do
                {:ok, tags} -> {:ok, {:constructed, {12, tags, 0}}}
                term -> term
              end
            else
              {:ok, nil}
            end) do
      params = [
        {:tagged, {0, process_identifier, byte_size(process_identifier)}},
        {:tagged, {1, device_identifier, byte_size(device_identifier)}},
        {:tagged, {2, object_identifier, byte_size(object_identifier)}},
        {:constructed, {3, timestamp, 0}},
        {:tagged, {4, notification_class, byte_size(notification_class)}},
        {:tagged, {5, priority, byte_size(priority)}},
        {:tagged, {6, eventtype, byte_size(eventtype)}},
        message_text,
        {:tagged, {8, notifytype, byte_size(notifytype)}},
        ack_required,
        from_state,
        {:tagged, {11, to_state, byte_size(to_state)}},
        event_values
      ]

      req = %{
        parameters: Enum.reject(params, &is_nil/1)
      }

      {:ok, req}
    end
  end

  @doc """
  Decodes the unconfirmed or confirmed private transfer service into a base map.

  This function is used by the `ConfirmedPrivateTransfer` and `UnconfirmedPrivateTransfer` modules.
  """
  @spec decode_private_transfer(
          ConfirmedServiceRequest.t()
          | UnconfirmedServiceRequest.t()
        ) :: {:ok, map()} | {:error, term()}
  def decode_private_transfer(request)
      when is_struct(request, ConfirmedServiceRequest) or
             is_struct(request, UnconfirmedServiceRequest) do
    with {:ok, vendor, rest} <-
           pattern_extract_tags(
             request.parameters,
             {:tagged, {0, _v, _l}},
             :unsigned_integer,
             false
           ),
         :ok <-
           if(ApplicationTags.valid_int?(vendor, 16),
             do: :ok,
             else: {:error, :invalid_vendor_id_value}
           ),
         {:ok, service, rest} <-
           pattern_extract_tags(rest, {:tagged, {1, _v, _l}}, :unsigned_integer, false),
         {:ok, parameters, _rest} <-
           pattern_extract_tags(rest, {:constructed, {2, _v, _l}}, nil, true) do
      transfer = %{
        vendor_id: vendor,
        service_number: service,
        parameters:
          case parameters do
            {:constructed, {2, params, _l}} ->
              Enum.map(params, &ApplicationTags.Encoding.create!(&1))

            _else ->
              nil
          end
      }

      {:ok, transfer}
    else
      {:error, :missing_pattern} -> {:error, :invalid_request_parameters}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Encodes the unconfirmed or confirmed private transfer service into a base map.

  This function is used by the `ConfirmedPrivateTransfer` and `UnconfirmedPrivateTransfer` modules.
  """
  @spec encode_private_transfer(
          Services.ConfirmedPrivateTransfer.t()
          | Services.UnconfirmedPrivateTransfer.t(),
          Keyword.t()
        ) :: {:ok, map()} | {:error, term()}
  def encode_private_transfer(service, opts \\ [])
      when is_struct(service, Services.ConfirmedPrivateTransfer) or
             is_struct(service, Services.UnconfirmedPrivateTransfer) do
    with :ok <-
           if(ApplicationTags.valid_int?(service.vendor_id, 16),
             do: :ok,
             else: {:error, :invalid_vendor_id_value}
           ),
         {:ok, vendor_id, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, service.vendor_id}, opts),
         {:ok, service_num, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, service.service_number}, opts),
         {:ok, parameters} <-
           (if service.parameters do
              with {:ok, params} <-
                     Enum.reduce_while(service.parameters, {:ok, []}, fn param, {:ok, acc} ->
                       case ApplicationTags.Encoding.to_encoding(param) do
                         {:ok, enc} -> {:cont, {:ok, [enc | acc]}}
                         term -> {:halt, term}
                       end
                     end) do
                {:ok, {:constructed, {2, Enum.reverse(params), 0}}}
              end
            else
              {:ok, nil}
            end) do
      vendor_size = byte_size(vendor_id)
      service_size = byte_size(service_num)

      req = %{
        parameters:
          Enum.reject(
            [
              {:tagged, {0, vendor_id, vendor_size}},
              {:tagged, {1, service_num, service_size}},
              parameters
            ],
            &is_nil/1
          )
      }

      {:ok, req}
    end
  end

  @doc """
  Decodes the unconfirmed or confirmed text message service into a base map.

  This function is used by the `ConfirmedTextMessage` and `UnconfirmedTextMessage` modules.
  """
  @spec decode_text_message(
          ConfirmedServiceRequest.t()
          | UnconfirmedServiceRequest.t()
        ) :: {:ok, map()} | {:error, term()}
  def decode_text_message(request)
      when is_struct(request, ConfirmedServiceRequest) or
             is_struct(request, UnconfirmedServiceRequest) do
    with {:ok, source_device, rest} <-
           pattern_extract_tags(
             request.parameters,
             {:tagged, {0, _c, _l}},
             :object_identifier,
             false
           ),
         {:ok, message_class_raw, rest} <-
           pattern_extract_tags(rest, {:constructed, {1, _c, _l}}, nil, true),
         {:ok, message_class} <-
           (case message_class_raw do
              nil ->
                {:ok, nil}

              {:constructed, {1, message_class_raw, _l}} ->
                with {:ok, message_class_num, _rest} <-
                       pattern_extract_tags(
                         List.wrap(message_class_raw),
                         {:tagged, {0, _c, _l}},
                         :unsigned_integer,
                         true
                       ),
                     {:ok, message_class_str, _rest} <-
                       pattern_extract_tags(
                         List.wrap(message_class_raw),
                         {:tagged, {1, _c, _l}},
                         :character_string,
                         true
                       ),
                     nil <-
                       (unless message_class_num || message_class_str do
                          {:error, :invalid_request_parameters}
                        end),
                     do: {:ok, message_class_num || message_class_str}
            end),
         {:ok, message_priority, rest} <-
           pattern_extract_tags(rest, {:tagged, {2, _c, _l}}, :enumerated, false),
         {:ok, message, _rest} <-
           pattern_extract_tags(rest, {:tagged, {3, _c, _l}}, :character_string, false) do
      textmsg = %{
        source_device: source_device,
        class: message_class,
        priority: enum_to_priority(message_priority),
        message: message
      }

      {:ok, textmsg}
    else
      {:error, :missing_pattern} -> {:error, :invalid_request_parameters}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Encodes the unconfirmed or confirmed text message service into a base map.

  This function is used by the `ConfirmedTextMessage` and `UnconfirmedTextMessage` modules.
  """
  @spec encode_text_message(
          Services.ConfirmedTextMessage.t()
          | Services.UnconfirmedTextMessage.t(),
          Keyword.t()
        ) :: {:ok, map()} | {:error, term()}
  def encode_text_message(request, _opts \\ [])
      when is_struct(request, Services.ConfirmedTextMessage) or
             is_struct(request, Services.UnconfirmedTextMessage) do
    with {:ok, device, _header} <-
           ApplicationTags.encode_value({:object_identifier, request.source_device}),
         {:ok, message_class} <-
           (case request.class do
              nil ->
                {:ok, nil}

              _term ->
                {type, tag} =
                  if is_integer(request.class) do
                    {:unsigned_integer, 0}
                  else
                    {:character_string, 1}
                  end

                case ApplicationTags.encode_value({type, request.class}) do
                  {:ok, val, _header} ->
                    {:ok, {:constructed, {1, {:tagged, {tag, val, byte_size(val)}}, 0}}}

                  term ->
                    term
                end
            end),
         {:ok, priority, _header} <-
           ApplicationTags.encode_value({:enumerated, priority_to_enum(request.priority)}),
         {:ok, message, _header} <-
           ApplicationTags.encode_value({:character_string, request.message}) do
      parameters = [
        {:tagged, {0, device, byte_size(device)}},
        message_class,
        {:tagged, {2, priority, byte_size(priority)}},
        {:tagged, {3, message, byte_size(message)}}
      ]

      req = %{
        parameters: Enum.reject(parameters, &is_nil/1)
      }

      {:ok, req}
    end
  end

  #### Helpers ####

  @spec enum_to_priority(0 | 1) :: :normal | :urgent
  defp enum_to_priority(0), do: :normal
  defp enum_to_priority(1), do: :urgent

  @spec priority_to_enum(:normal | :urgent) :: 0 | 1
  defp priority_to_enum(:normal), do: 0
  defp priority_to_enum(:urgent), do: 1
end
