defmodule ExklWeb.DashboardLive.Index do
  alias Phoenix.PubSub
  require Logger

  use ExklWeb, :live_view

  import ExklWeb.MetricCard

  alias Exkl.Display.Settings
  alias Exkl.HidDevice.Discovery

  @pubsub_topic "cpu_metrics"
  @display_settings_topic "display_settings"
  @history_size 36
  @device_refresh_ms 10_000

  @modes [
    %{id: :cpu_temp_c, label: "°C", title: "Temperature °C", icon: "hero-fire"},
    %{id: :cpu_temp_f, label: "°F", title: "Temperature °F", icon: "hero-fire"},
    %{id: :cpu_util, label: "CPU", title: "Utilization %", icon: "hero-cpu-chip"}
  ]

  @impl true
  def render(assigns) do
    {cpu_min, cpu_max} = chart_range(assigns.cpu_history, assigns.ak.mode)
    {gpu_min, gpu_max} = chart_range(assigns.gpu_history, assigns.ak.mode)

    assigns =
      assigns
      |> assign(:modes, @modes)
      |> assign(:metric_progress, metric_progress(assigns.ak))
      |> assign(:metric_title, metric_title(assigns.ak.mode))
      |> assign(:metric_unit, metric_unit(assigns.ak.mode))
      |> assign(:gpu_title, gpu_title(assigns.ak.mode))
      |> assign(:gpu_available?, gpu_available?(assigns.ak))
      |> assign(:gpu_display, gpu_display(assigns.ak))
      |> assign(:gpu_unit, gpu_unit(assigns.ak.mode))
      |> assign(:gpu_metric_progress, gpu_metric_progress(assigns.ak))
      |> assign(:cpu_stats, history_stats(assigns.cpu_history))
      |> assign(:gpu_stats, history_stats(assigns.gpu_history))
      |> assign(:cpu_chart_min, cpu_min)
      |> assign(:cpu_chart_max, cpu_max)
      |> assign(:gpu_chart_min, gpu_min)
      |> assign(:gpu_chart_max, gpu_max)
      |> assign(:gpu_icon, if(assigns.ak.mode == :cpu_util, do: "hero-bolt", else: "hero-fire"))
      |> assign(:cpu_freq, format_freq(assigns.ak.cpu_freq_mhz))
      |> assign(:gpu_freq, format_freq(assigns.ak.gpu_freq_mhz))
      |> assign(:cpu_power, format_power(assigns.ak.cpu_power_w))
      |> assign(:gpu_power, format_power(assigns.ak.gpu_power_w))
      |> assign(:screen_on, assigns.screen_on)

    ~H"""
    <Layouts.app flash={@flash}>
      <div class="dashboard-grid">
        <section class="glass-panel system-panel">
          <div class="system-panel-header">
            <div class="logo-glow rounded-2xl p-1">
              <img
                src={~p"/images/exkl_logo.png"}
                alt="EXKL"
                class="system-logo rounded-xl object-cover"
              />
            </div>
            <p class="font-display text-base font-semibold tracking-tight text-base-content sm:text-lg">
              EXKL
            </p>
            <p class="system-subtitle text-sm text-base-content/50">v{@version}</p>
          </div>

          <div class="divider my-2 opacity-30" />

          <ul class="system-facts">
            <li :for={fact <- system_facts(@facts)} class="system-fact">
              <span class="system-fact-label">{fact.label}</span>
              <span class="system-fact-value">{fact.value}</span>
            </li>
          </ul>

          <div class="divider my-2 opacity-30" />

          <div class="device-section">
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
                    title={if(@screen_on, do: "Screen on — sending live metrics", else: "Screen off — display powered down")}
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
                  <span class="device-family">{device_family_label(device.family)}</span>
                </div>
                <span class={["device-status-label", device_status_class(device.status)]}>
                  {device_status_label(device.status)}
                </span>
              </li>
            </ul>
          </div>
        </section>

        <div class="metrics-column">
          <.metric_card
            title={@metric_title}
            subtitle={@facts.cpu_name}
            value={if(@ak.metrics_value >= 0, do: "#{trunc(@ak.metrics_value)}", else: "—")}
            unit={@metric_unit}
            available?={true}
            progress={@metric_progress}
            tone="primary"
            history={@cpu_history}
            chart_min={@cpu_chart_min}
            chart_max={@cpu_chart_max}
            stats={@cpu_stats}
            icon="hero-cpu-chip"
            chart_id="cpu"
            value_id="metric-value"
            freq={@cpu_freq}
            power={@cpu_power}
          />

          <.metric_card
            title={@gpu_title}
            subtitle={@facts.gpu_name}
            value={@gpu_display}
            unit={@gpu_unit}
            available?={@gpu_available?}
            progress={@gpu_metric_progress}
            tone="accent"
            history={@gpu_history}
            chart_min={@gpu_chart_min}
            chart_max={@gpu_chart_max}
            stats={@gpu_stats}
            icon={@gpu_icon}
            chart_id="gpu"
            value_id="gpu-metric-value"
            freq={@gpu_freq}
            power={@gpu_power}
          />
        </div>

        <section class="glass-panel mode-panel">
            <p class="mode-label">Display mode</p>
            <div class="mode-selector">
              <button
                :for={mode <- @modes}
                type="button"
                phx-click="change_mode"
                phx-value-mode={mode.id}
                class={["mode-btn", @ak.mode == mode.id && "mode-btn-active"]}
                aria-pressed={@ak.mode == mode.id}
                title={mode.title}
              >
                <.icon name={mode.icon} class="size-4 shrink-0" />
                <span class="mode-btn-label">{mode.title}</span>
              </button>
            </div>
          </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    PubSub.subscribe(Exkl.PubSub, @pubsub_topic)
    PubSub.subscribe(Exkl.PubSub, @display_settings_topic)

    if connected?(socket) do
      :timer.send_interval(@device_refresh_ms, self(), :refresh_devices)
    end

    {os_type, os_name} = :os.type()
    {:ok, hostname} = :inet.gethostname()

    {:ok,
     socket
     |> assign(:ak, %Exkl.AK{})
     |> assign(:cpu_history, [])
     |> assign(:gpu_history, [])
     |> assign(:devices, Discovery.list())
     |> assign(:screen_on, Settings.screen_on?())
     |> assign(:version, app_version())
     |> assign(:facts, %{
       os: "#{os_type} - #{os_name}",
       arch: :erlang.system_info(:system_architecture) |> to_string(),
       hostname: to_string(hostname),
       cpu_name: Exkl.HardwareInfo.cpu_name(),
       gpu_name: Exkl.HardwareInfo.gpu_name()
     })}
  end

  @impl true
  def handle_event("toggle_screen", _params, socket) do
    on = not socket.assigns.screen_on
    Settings.set_screen_on(on)
    {:noreply, assign(socket, :screen_on, on)}
  end

  @impl true
  def handle_event("change_mode", %{"mode" => "cpu_temp_c"}, socket) do
    Exkl.Core.change_mode(:cpu_temp_c)
    {:noreply, reset_histories(socket)}
  end

  @impl true
  def handle_event("change_mode", %{"mode" => "cpu_temp_f"}, socket) do
    Exkl.Core.change_mode(:cpu_temp_f)
    {:noreply, reset_histories(socket)}
  end

  @impl true
  def handle_event("change_mode", %{"mode" => "cpu_util"}, socket) do
    Exkl.Core.change_mode(:cpu_util)
    {:noreply, reset_histories(socket)}
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
    Logger.debug("Exkl.DashboardLive.Index received CPU metrics update: #{inspect(ak)}%")

    cpu_value = cpu_chart_value(ak)
    gpu_value = gpu_chart_value(ak)

    {:noreply,
     socket
     |> assign(:ak, ak)
     |> update(:cpu_history, &push_history(&1, cpu_value))
     |> update(:gpu_history, &push_history(&1, gpu_value))}
  end

  defp reset_histories(socket) do
    socket
    |> assign(:cpu_history, [])
    |> assign(:gpu_history, [])
  end

  defp push_history(history, value) when is_float(value) do
    (history ++ [value]) |> Enum.take(-@history_size)
  end

  defp push_history(history, _), do: history

  defp cpu_chart_value(%{mode: :cpu_util, metrics_value: value}), do: value
  defp cpu_chart_value(%{metrics_value: value}), do: value

  defp gpu_chart_value(%{mode: :cpu_util, gpu_util: value}) when is_float(value), do: value

  defp gpu_chart_value(%{mode: :cpu_temp_f, gpu_temp_c: temp}) when is_float(temp),
    do: celsius_to_fahrenheit(temp)

  defp gpu_chart_value(%{gpu_temp_c: temp}) when is_float(temp), do: temp
  defp gpu_chart_value(_), do: nil

  defp chart_range(_history, :cpu_util), do: {0.0, 100.0}
  defp chart_range(history, :cpu_temp_c), do: temp_chart_range(history, 30.0, 100.0)
  defp chart_range(history, :cpu_temp_f), do: temp_chart_range(history, 86.0, 212.0)
  defp chart_range(history, _), do: temp_chart_range(history, 0.0, 100.0)

  defp temp_chart_range([], min, max), do: {min, max}

  defp temp_chart_range(values, default_min, default_max) do
    data_min = Enum.min(values) - 3.0
    data_max = Enum.max(values) + 3.0
    {Kernel.max(data_min, default_min), Kernel.min(data_max, default_max)}
  end

  defp history_stats([]), do: %{min: "—", avg: "—", max: "—"}

  defp history_stats(values) do
    min = values |> Enum.min() |> trunc()
    max = values |> Enum.max() |> trunc()
    avg = values |> Enum.sum() |> Kernel./(length(values)) |> trunc()

    %{min: min, avg: avg, max: max}
  end

  defp system_facts(facts) do
    [
      %{label: "Hostname", value: facts.hostname},
      %{label: "OS", value: facts.os},
      %{label: "Arch", value: facts.arch}
    ]
  end

  defp app_version do
    Application.spec(:exkl, :vsn) |> to_string()
  end

  defp format_freq(nil), do: nil
  defp format_freq(mhz) when mhz >= 1000, do: "#{:erlang.float_to_binary(mhz / 1000, decimals: 2)} GHz"
  defp format_freq(mhz), do: "#{round(mhz)} MHz"

  defp format_power(nil), do: nil
  defp format_power(watts), do: "#{format_decimal(watts, 1)} W"

  defp format_decimal(value, decimals) do
    :erlang.float_to_binary(value * 1.0, decimals: decimals)
  end

  defp metric_title(:cpu_temp_c), do: "CPU Temperature"
  defp metric_title(:cpu_temp_f), do: "CPU Temperature"
  defp metric_title(:cpu_util), do: "CPU Load"
  defp metric_title(_), do: "Metric"

  defp metric_unit(:cpu_temp_c), do: "°C"
  defp metric_unit(:cpu_temp_f), do: "°F"
  defp metric_unit(:cpu_util), do: "%"
  defp metric_unit(_), do: ""

  defp metric_progress(%{mode: mode, metrics_value: value}) when mode != :start do
    value |> Exkl.Bar.progress(mode) |> Float.round(1)
  end

  defp metric_progress(_), do: 0.0

  defp gpu_title(:cpu_util), do: "GPU Load"
  defp gpu_title(_), do: "GPU Temperature"

  defp gpu_available?(%{mode: :cpu_util, gpu_util: util}) when is_float(util), do: true
  defp gpu_available?(%{gpu_temp_c: temp}) when is_float(temp), do: true
  defp gpu_available?(_), do: false

  defp gpu_display(%{mode: :cpu_util, gpu_util: nil}), do: "—"
  defp gpu_display(%{mode: :cpu_util, gpu_util: util}), do: "#{trunc(util)}"
  defp gpu_display(%{gpu_temp_c: nil}), do: "—"
  defp gpu_display(%{gpu_temp_c: temp, mode: :cpu_temp_f}), do: "#{trunc(celsius_to_fahrenheit(temp))}"
  defp gpu_display(%{gpu_temp_c: temp}), do: "#{trunc(temp)}"

  defp gpu_unit(:cpu_util), do: "%"
  defp gpu_unit(:cpu_temp_f), do: "°F"
  defp gpu_unit(_), do: "°C"

  defp gpu_metric_progress(%{mode: :cpu_util, gpu_util: nil}), do: 0.0

  defp gpu_metric_progress(%{mode: :cpu_util, gpu_util: util}) do
    util |> Exkl.Bar.progress(:cpu_util) |> Float.round(1)
  end

  defp gpu_metric_progress(%{gpu_temp_c: nil}), do: 0.0

  defp gpu_metric_progress(%{gpu_temp_c: temp, mode: :cpu_temp_f}) do
    temp |> celsius_to_fahrenheit() |> Exkl.Bar.progress(:cpu_temp_f) |> Float.round(1)
  end

  defp gpu_metric_progress(%{gpu_temp_c: temp}) do
    temp |> Exkl.Bar.progress(:cpu_temp_c) |> Float.round(1)
  end

  defp celsius_to_fahrenheit(celsius), do: celsius * 9.0 / 5.0 + 32.0

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
