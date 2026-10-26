defmodule ExklWeb.DeviceList do
  @moduledoc false
  use Phoenix.Component
  use PhoenixPaper.Components

  attr :devices, :list, required: true
  attr :screen_on, :boolean, required: true
  attr :show_family, :boolean, default: true

  # Renders without a wrapper: placed directly in a pp_card's content, the
  # pp_list lines up with the card edges (phoenix_paper >= 0.5.3).
  def device_list(assigns) do
    ~H"""
    <.pp_typography variant="label-medium" tag="h2" color="on-surface-variant" class="mb-1 uppercase tracking-widest">
      DeepCool devices
    </.pp_typography>

    <.pp_typography :if={@devices == []} variant="body-medium" tag="p" color="on-surface-variant" class="py-2">
      No DeepCool HID devices detected
    </.pp_typography>

    <.pp_list :if={@devices != []} class="min-h-0 overflow-y-auto">
      <.pp_list_item :for={device <- @devices} class={device_status_class(device.status)}>
        <:leading>
          <span class="device-dot" aria-hidden="true" />
        </:leading>
        {device.name}
        <:secondary>
          <span class="device-status-text">{device_status_label(device.status)}</span>
          · {device.usb_id}<span :if={@show_family}> · {device_family_label(device.family)}</span>
        </:secondary>
        <:trailing :if={device.status == :connected}>
          <.pp_switch
            id={"screen-toggle-#{device.usb_id}"}
            checked={@screen_on}
            icons
            phx-click="toggle_screen"
            aria-label={if(@screen_on, do: "Turn cooler screen off", else: "Turn cooler screen on")}
            title={if(@screen_on, do: "Screen on — sending live metrics", else: "Screen off — display powered down")}
          />
        </:trailing>
      </.pp_list_item>
      </.pp_list>
    """
  end

  defp device_status_label(:connected), do: "Connected"
  defp device_status_label(:detected), do: "Detected"
  defp device_status_label(:unsupported), do: "Unsupported"

  defp device_status_class(:connected), do: "device-status-connected"
  defp device_status_class(:detected), do: "device-status-detected"
  defp device_status_class(:unsupported), do: "device-status-unsupported"

  defp device_family_label(nil), do: "Unknown protocol"
  defp device_family_label(:ak_series), do: "AK series"
  defp device_family_label(:ch_series), do: "CH series"
  defp device_family_label(:g2_series), do: "G2 series"
end
