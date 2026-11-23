defmodule BACnet.Protocol.SecureConnect.Settings do
  @moduledoc """
  Defines the BACnet/SC Network Port settings shared by the protocol objects
  and the optional SC transport. Timer defaults and ranges are in seconds.
  """

  @timers [
    sc_minimum_reconnect_time: {:min_reconnect_time, 10, 2..300},
    sc_maximum_reconnect_time: {:max_reconnect_time, 600, 2..600},
    sc_connect_wait_timeout: {:connect_wait_timeout, 10, 5..300},
    sc_disconnect_wait_timeout: {:disconnect_wait_timeout, 10, 5..300},
    sc_heartbeat_timeout: {:heartbeat_timeout, 300, 3..300}
  ]

  for {_property, {option, _default, first..last//1}} <- @timers do
    @typedoc "Accepted values for `#{option}`, in seconds."
    @type unquote(option)() :: unquote(first)..unquote(last)
  end

  @doc """
  Lists timer properties with their runtime option name, default, and range.
  """
  @spec timers() :: [{atom(), {atom(), pos_integer(), Range.t()}}]
  def timers(), do: @timers

  @doc """
  Returns the default for a Network Port timer property.
  """
  @spec timer_default(atom()) :: pos_integer()
  def timer_default(property) do
    {_option, default, _range} = Keyword.fetch!(@timers, property)
    default
  end

  @doc """
  Maps each connector property to its node option.
  """
  @spec connector_options() :: [{atom(), atom()}]
  def connector_options() do
    [
      sc_primary_hub_uri: :primary_hub_uri,
      sc_failover_hub_uri: :failover_hub_uri
    ] ++ Enum.map(@timers, fn {property, {option, _default, _range}} -> {property, option} end)
  end

  @doc """
  Lists the SC-specific properties that participate in managed activation.
  """
  @spec port_properties() :: [atom()]
  def port_properties() do
    Keyword.keys(connector_options()) ++ [:sc_hub_function_enable, :sc_hub_function_accept_uris]
  end
end
