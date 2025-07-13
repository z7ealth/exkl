defmodule ExklWeb.DashboardLive.Index do
  alias Phoenix.PubSub
  require Logger

  use ExklWeb, :live_view

  @pubsub_topic "cpu_metrics"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="grid md:grid-cols-2 justify-center items-center md:items-start gap-6">
        <div class="card bg-base-300 card-xs shadow-sm p-8">
          <div class="card-body flex flex-col items-center">
            <div class="avatar">
              <div class="w-24 rounded">
                <img src={~p"/images/exkl_logo.png"} />
              </div>
            </div>
            <div class="divider" />
            <.list>
              <:item title="Hostname">{@facts.hostname}</:item>
              <:item title="OS">{@facts.os}</:item>
              <:item title="Arch">{@facts.arch}</:item>
            </.list>
          </div>
        </div>

        <div class="flex flex-col gap-2">
          <div class="stats shadow bg-base-300 text-base-content">
            <div class="stat">
              <div class="stat-figure">
                <.icon name="hero-cpu-chip" class="w-8 h-8" />
              </div>
              <div :if={@ak.mode == :cpu_temp_c} class="stat-title">Temperature °C</div>
              <div :if={@ak.mode == :cpu_temp_f} class="stat-title">Temperature °F</div>
              <div :if={@ak.mode == :cpu_util} class="stat-title">CPU Utilization</div>
              <div :if={@ak.mode == :cpu_temp_c} class="stat-value text-primary">
                {trunc(@ak.metrics_value)} °C
              </div>
              <div :if={@ak.mode == :cpu_temp_f} class="stat-value text-primary">
                {trunc(@ak.metrics_value)} °F
              </div>
              <div :if={@ak.mode == :cpu_util} class="stat-value text-primary">
                {trunc(@ak.metrics_value)}%
              </div>
            </div>
          </div>

          <div class="card bg-base-300 card-xs shadow-sm p-8">
            <div class="card-body flex flex-col items-center">
              <.form :let={f} for={nil}>
                <div class="flex flex-col gap-2">
                  <.input
                    field={f[:mode]}
                    type="radio"
                    phx-click="change_mode"
                    phx-value-mode={:cpu_temp_c}
                    label="Temperature °C"
                    checked
                  />
                  <.input
                    field={f[:mode]}
                    phx-click="change_mode"
                    phx-value-mode={:cpu_temp_f}
                    label="Temperature °F"
                    type="radio"
                  />
                  <.input
                    field={f[:mode]}
                    phx-click="change_mode"
                    phx-value-mode={:cpu_util}
                    label="CPU Utilization"
                    type="radio"
                  />
                </div>
              </.form>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    PubSub.subscribe(Exkl.PubSub, @pubsub_topic)

    {os_type, os_name} = :os.type()
    {:ok, hostname} = :inet.gethostname()

    {:ok,
     socket
     |> assign(:ak, %Exkl.AK{})
     |> assign(:facts, %{
       os: "#{os_type} - #{os_name}",
       arch: :erlang.system_info(:system_architecture) |> to_string(),
       hostname: to_string(hostname)
     })}
  end

  @impl true
  def handle_event("change_mode", %{"mode" => "cpu_temp_c"}, socket) do
    Exkl.Core.change_mode(:cpu_temp_c)
    {:noreply, socket}
  end

  @impl true
  def handle_event("change_mode", %{"mode" => "cpu_temp_f"}, socket) do
    Exkl.Core.change_mode(:cpu_temp_f)
    {:noreply, socket}
  end

  @impl true
  def handle_event("change_mode", %{"mode" => "cpu_util"}, socket) do
    Exkl.Core.change_mode(:cpu_util)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:cpu_metrics, ak}, socket) do
    Logger.debug("Exkl.DashboardLive.Index received CPU metrics update: #{inspect(ak)}%")

    {:noreply, socket |> assign(:ak, ak)}
  end
end
