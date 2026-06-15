defmodule Exkl.Core do
  use GenServer

  require Logger

  alias Phoenix.PubSub
  alias Exkl.GpuSensors
  alias Exkl.SensorsNif
  alias Exkl.AK

  @pubsub_topic "cpu_metrics"
  @update_interval 1000

  ## Public API

  @spec start_link(Exkl.AK.t()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(%AK{} = ak) do
    GenServer.start_link(__MODULE__, ak, name: __MODULE__)
  end

  @spec change_mode(AK.modes()) :: :ok
  def change_mode(mode) do
    GenServer.cast(__MODULE__, {:change_mode, mode})
  end

  ## GenServer Callbacks

  @impl true
  def init(%AK{} = ak) do
    schedule_update()

    {:ok, ak}
  end

  @impl true
  def handle_cast({:change_mode, mode}, ak) do
    {:noreply, Map.replace!(ak, :mode, mode)}
  end

  @impl true
  def handle_info(:update_cpu_metrics, ak) do
    updated_ak =
      ak
      |> update_cpu_metrics()
      |> update_gpu_metrics()

    Logger.debug("Publishing updated metrics: #{inspect(updated_ak)}%")

    PubSub.broadcast(Exkl.PubSub, @pubsub_topic, {:cpu_metrics, updated_ak})

    schedule_update()
    {:noreply, updated_ak}
  rescue
    e ->
      Logger.error("Error getting or publishing CPU usage: #{inspect(e)}")
      schedule_update()
      {:noreply, ak}
  end

  defp update_cpu_metrics(%AK{mode: :cpu_temp_c} = ak),
    do: Map.replace!(ak, :metrics_value, SensorsNif.get_cpu_temp_celsius())

  defp update_cpu_metrics(%AK{mode: :cpu_temp_f} = ak),
    do: Map.replace!(ak, :metrics_value, SensorsNif.get_cpu_temp_fahrenheit())

  defp update_cpu_metrics(%AK{mode: :cpu_util} = ak),
    do: Map.replace!(ak, :metrics_value, :cpu_sup.util())

  defp update_gpu_metrics(ak) do
    ak
    |> update_gpu_temp()
    |> update_gpu_util()
  end

  defp update_gpu_temp(ak) do
    case SensorsNif.get_gpu_temp_celsius() do
      temp when temp < 0 -> Map.put(ak, :gpu_temp_c, nil)
      temp -> Map.put(ak, :gpu_temp_c, temp)
    end
  end

  defp update_gpu_util(ak) do
    case GpuSensors.utilization() do
      nil -> Map.put(ak, :gpu_util, nil)
      util -> Map.put(ak, :gpu_util, util)
    end
  end

  defp schedule_update() do
    Process.send_after(self(), :update_cpu_metrics, @update_interval)
  end
end
