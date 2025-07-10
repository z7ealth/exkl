defmodule ExklWeb.DashboardLive.Index do
  alias Phoenix.PubSub
  require Logger

  use ExklWeb, :live_view

  @pubsub_topic "cpu_metrics"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="flex flex-col md:flex-row justify-center items-center md:items-start gap-6">
        <div class="card w-96 bg-base-300 card-xs shadow-sm p-8">
          <div class="card-body flex flex-col items-center">
            <div class="avatar">
              <div class="w-24 rounded">
                <img src={~p"/images/exkl_logo.png"} />
              </div>
            </div>
            <.list>
              <:item title="Hostname">{@facts.hostname}</:item>
              <:item title="OS">{@facts.os}</:item>
              <:item title="Arch">{@facts.arch}</:item>
            </.list>
          </div>
        </div>

        <div class="stats shadow bg-base-300 text-base-content">
          <div class="stat">
            <div class="stat-figure">
              <.icon name="hero-cpu-chip" class="w-8 h-8" />
            </div>
            <div class="stat-title">Temperature C°</div>
            <div class="stat-value text-primary">{trunc(@cpu_metrics.temp)}°</div>
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
     |> assign(:cpu_metrics, %{temp: 0})
     |> assign(:facts, %{
       os: "#{os_type} - #{os_name}",
       arch: :erlang.system_info(:system_architecture) |> to_string(),
       hostname: to_string(hostname)
     })}
  end

  @impl true
  def handle_info({:cpu_metrics, new_cpu_metrics}, socket) do
    Logger.debug(
      "Exkl.DashboardLive.Index received CPU metrics update: #{inspect(new_cpu_metrics)}%"
    )

    {:noreply, socket |> assign(:cpu_metrics, new_cpu_metrics)}
  end
end
