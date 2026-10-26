defmodule ExklWeb.TrayLive.Index do
  @moduledoc false
  use ExklWeb, :live_view

  import ExklWeb.TraySparkline
  import ExklWeb.DeviceList

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
    <div class="flex h-full flex-col gap-3 overflow-hidden p-4">
      <header class="flex shrink-0 items-center justify-between">
        <div class="flex items-center gap-2">
          <span class="live-dot" aria-hidden="true" />
          <.pp_typography variant="title-medium" tag="h1" emphasized>EXKL</.pp_typography>
        </div>
        <.pp_typography variant="label-medium" tag="span" color="on-surface-variant">
          v{@version}
        </.pp_typography>
      </header>

      <.tray_metric
        icon="hero-cpu-chip"
        label="CPU"
        temp={@cpu_temp}
        util={@cpu_util}
        history={@cpu_history}
        spark_id="tray-cpu-spark"
        tone="text-pp-primary"
      />

      <.tray_metric
        icon="hero-fire"
        label="GPU"
        temp={@gpu_temp}
        util={@gpu_util}
        history={@gpu_history}
        spark_id="tray-gpu-spark"
        tone="text-pp-tertiary"
        class={!@gpu_available? && "opacity-60"}
      />

      <.pp_card variant="filled" class="min-h-0 flex-1 overflow-hidden" content_class="flex min-h-0 flex-col">
        <.device_list devices={@devices} screen_on={@screen_on} show_family={false} />
      </.pp_card>

      <footer class="grid shrink-0 grid-cols-[1fr_auto] gap-2">
        <.pp_button phx-click="open_window" variant="filled" size="sm">
          <:start_icon><.pp_icon name="hero-arrow-top-right-on-square" /></:start_icon>
          Open dashboard
        </.pp_button>
        <.pp_button phx-click="close_popup" variant="text" size="sm">Close</.pp_button>
      </footer>
    </div>
    """
  end

  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :temp, :string, required: true
  attr :util, :string, required: true
  attr :history, :list, required: true
  attr :spark_id, :string, required: true
  attr :tone, :string, required: true
  attr :class, :any, default: nil

  defp tray_metric(assigns) do
    ~H"""
    <.pp_card variant="filled" class={["shrink-0", @class]}>
      <div class="mb-2 flex items-start justify-between gap-3">
        <div class="flex items-center gap-2">
          <.pp_icon name={@icon} class={@tone} />
          <.pp_typography variant="title-medium" tag="h2">{@label}</.pp_typography>
        </div>
        <dl class="grid grid-cols-2 gap-x-4 text-right">
          <div class="flex flex-col-reverse">
            <dt class="pp-label-small uppercase tracking-wider text-pp-on-surface-variant">Temp</dt>
            <dd class={["pp-title-small-emphasized", @tone]}>{@temp}</dd>
          </div>
          <div class="flex flex-col-reverse">
            <dt class="pp-label-small uppercase tracking-wider text-pp-on-surface-variant">Load</dt>
            <dd class={["pp-title-small-emphasized", @tone]}>{@util}</dd>
          </div>
        </dl>
      </div>
      <div class={@tone}>
        <.tray_sparkline id={@spark_id} values={@history} min={0.0} max={100.0} />
      </div>
    </.pp_card>
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

  defp app_version, do: Application.spec(:exkl, :vsn) |> to_string()
end
