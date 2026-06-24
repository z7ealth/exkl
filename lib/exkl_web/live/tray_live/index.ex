defmodule ExklWeb.TrayLive.Index do
  @moduledoc false
  use ExklWeb, :live_view

  import ExklWeb.TraySparkline

  alias Exkl.Desktop.API
  alias Exkl.Display.Settings
  alias Exkl.HidDevice.Discovery
  alias Phoenix.PubSub

  @pubsub_topic "cpu_metrics"
  @display_settings_topic "display_settings"
  @history_size 24
  @device_refresh_ms 10_000

  @impl true
  def mount(_params, _session, socket) do
    PubSub.subscribe(Exkl.PubSub, @pubsub_topic)
    PubSub.subscribe(Exkl.PubSub, @display_settings_topic)

    if connected?(socket) do
      :timer.send_interval(@device_refresh_ms, self(), :refresh_devices)
    end

    {:ok,
     socket
     |> assign(:ak, %Exkl.AK{})
     |> assign(:cpu_history, [])
     |> assign(:gpu_history, [])
     |> assign(:devices, Discovery.list())
     |> assign(:screen_on, Settings.screen_on?())
     |> assign(:version, app_version())}
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:cpu_temp, format_temp(cpu_temp_c(assigns.ak)))
      |> assign(:cpu_util, format_percent(assigns.ak.cpu_util))
      |> assign(:gpu_temp, format_temp(gpu_temp_c(assigns.ak)))
      |> assign(:gpu_util, format_percent(assigns.ak.gpu_util))
      |> assign(:gpu_available?, gpu_available?(assigns.ak))

    ~H"""
    <div class="tray-popup">
      <header class="tray-popup-header">
        <div class="flex items-center gap-2">
          <span class="live-dot" aria-hidden="true" />
          <h1 class="font-display text-base font-semibold tracking-tight text-base-content">EXKL</h1>
        </div>
        <span class="text-xs text-base-content/50">v{@version}</span>
      </header>

      <section class="dc-card tray-metric-card">
        <div class="tray-card-top">
          <div class="flex items-center gap-2">
            <.icon name="hero-cpu-chip" class="size-5 text-primary" />
            <p class="metric-label">CPU</p>
          </div>
          <div class="tray-metric-grid">
            <div class="tray-metric">
              <span class="tray-metric-label">Temp</span>
              <span class="tray-metric-value">{@cpu_temp}</span>
            </div>
            <div class="tray-metric">
              <span class="tray-metric-label">Load</span>
              <span class="tray-metric-value">{@cpu_util}</span>
            </div>
          </div>
        </div>
        <div class="text-primary">
          <.tray_sparkline
            id="tray-cpu-spark"
            values={@cpu_history}
            min={0.0}
            max={100.0}
            stroke="currentColor"
            fill="currentColor"
          />
        </div>
      </section>

      <section class={["dc-card tray-metric-card", !@gpu_available? && "opacity-60"]}>
        <div class="tray-card-top">
          <div class="flex items-center gap-2">
            <.icon name="hero-fire" class="size-5 text-primary" />
            <p class="metric-label">GPU</p>
          </div>
          <div class="tray-metric-grid">
            <div class="tray-metric">
              <span class="tray-metric-label">Temp</span>
              <span class="tray-metric-value">{@gpu_temp}</span>
            </div>
            <div class="tray-metric">
              <span class="tray-metric-label">Load</span>
              <span class="tray-metric-value">{@gpu_util}</span>
            </div>
          </div>
        </div>
        <div class="text-primary">
          <.tray_sparkline
            id="tray-gpu-spark"
            values={@gpu_history}
            min={0.0}
            max={100.0}
            stroke="currentColor"
            fill="currentColor"
          />
        </div>
      </section>

      <section class="dc-card device-section tray-device-section">
        <p class="device-section-label">DeepCool devices</p>

        <p :if={@devices == []} class="device-empty">
          No DeepCool HID devices detected
        </p>

        <ul :if={@devices != []} class="device-list">
          <li :for={device <- @devices} class="device-item">
            <div class="device-item-top">
              <div class="device-item-header">
                <span class={["device-status", device_status_class(device.status)]} />
                <span class="device-name">{device.name}</span>
              </div>

              <button
                :if={device.status == :connected}
                type="button"
                phx-click="toggle_screen"
                class={["screen-toggle", "device-screen-toggle", !@screen_on && "screen-toggle-off"]}
                aria-pressed={@screen_on}
                aria-label={if(@screen_on, do: "Turn cooler screen off", else: "Turn cooler screen on")}
              >
                <span class="screen-toggle-track" aria-hidden="true">
                  <span class="screen-toggle-thumb">
                    <.icon
                      name={if(@screen_on, do: "hero-signal", else: "hero-pause")}
                      class="size-2.5"
                    />
                  </span>
                </span>
                <span class="screen-toggle-label">{if(@screen_on, do: "On", else: "Off")}</span>
              </button>
            </div>

            <div class="device-item-meta">
              <span class="device-usb-id">{device.usb_id}</span>
              <span class={["device-status-label", device_status_class(device.status)]}>
                {device_status_label(device.status)}
              </span>
            </div>
          </li>
        </ul>
      </section>

      <footer class="tray-popup-footer">
        <button type="button" phx-click="open_window" class="btn btn-primary btn-sm">
          Open dashboard
        </button>
        <button type="button" phx-click="close_popup" class="btn btn-ghost btn-sm">
          Close
        </button>
      </footer>
    </div>
    """
  end

  @impl true
  def handle_event("open_window", _params, socket) do
    API.show_main_window()
    {:noreply, socket}
  end

  @impl true
  def handle_event("close_popup", _params, socket) do
    API.hide_tray_popup()
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_screen", _params, socket) do
    on = not socket.assigns.screen_on
    Settings.set_screen_on(on)
    {:noreply, assign(socket, :screen_on, on)}
  end

  @impl true
  def handle_info({:screen_on, on}, socket) do
    {:noreply, assign(socket, :screen_on, on)}
  end

  @impl true
  def handle_info(:refresh_devices, socket) do
    {:noreply, assign(socket, :devices, Discovery.list())}
  end

  @impl true
  def handle_info({:cpu_metrics, ak}, socket) do
    {:noreply,
     socket
     |> assign(:ak, ak)
     |> update(:cpu_history, &push_history(&1, ak.cpu_util))
     |> update(:gpu_history, &push_history(&1, ak.gpu_util))}
  end

  defp push_history(history, value) when is_float(value) do
    (history ++ [value]) |> Enum.take(-@history_size)
  end

  defp push_history(history, _), do: history

  defp cpu_temp_c(%{cpu_temp_c: temp}) when is_float(temp), do: temp
  defp cpu_temp_c(_), do: nil

  defp gpu_temp_c(%{gpu_temp_c: temp}) when is_float(temp), do: temp
  defp gpu_temp_c(_), do: nil

  defp gpu_available?(%{gpu_util: util}) when is_float(util), do: true
  defp gpu_available?(%{gpu_temp_c: temp}) when is_float(temp), do: true
  defp gpu_available?(_), do: false

  defp format_temp(nil), do: "—"
  defp format_temp(temp), do: "#{round(temp)}°C"

  defp format_percent(nil), do: "—"
  defp format_percent(value), do: "#{round(value)}%"

  defp device_status_label(:connected), do: "Connected"
  defp device_status_label(:detected), do: "Detected"
  defp device_status_label(:unsupported), do: "Unsupported"

  defp device_status_class(:connected), do: "device-status-connected"
  defp device_status_class(:detected), do: "device-status-detected"
  defp device_status_class(:unsupported), do: "device-status-unsupported"

  defp app_version, do: Application.spec(:exkl, :vsn) |> to_string()
end
