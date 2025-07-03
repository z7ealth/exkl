defmodule Exkl.Core do
  use GenServer

  require Logger

  alias Phoenix.PubSub
  alias Exkl.SensorsNif

  @pubsub_topic "cpu_metrics"
  @update_interval 1000

  ## Public API

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def change_mode(mode) do
    GenServer.cast(__MODULE__, {:change_mode, %{mode: mode}})
  end

  ## GenServer Callbacks

  @impl true
  def init(initial_state) do
    schedule_update()

    {:ok, initial_state}
  end

  @impl true
  def handle_cast({:change_mode, new_state}, _state) do
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:update_cpu_metrics, state) do
    cpu_temp = SensorsNif.get_cpu_temp_celcius()
    Logger.debug("Publishing CPU temp: #{cpu_temp}%")

    PubSub.broadcast(Exkl.PubSub, @pubsub_topic, {:cpu_metrics, %{temp: cpu_temp}})

    schedule_update()
    {:noreply, state}
  rescue
    e ->
      Logger.error("Error getting or publishing CPU usage: #{inspect(e)}")
      schedule_update()
      {:noreply, state}
  end

  defp schedule_update() do
    Process.send_after(self(), :update_cpu_metrics, @update_interval)
  end
end
