defmodule Exkl.Display.Worker do
  @moduledoc false

  use GenServer

  require Logger

  alias Exkl.HidApiNif
  alias Exkl.HidDevice

  def start_link({handle, device}) do
    GenServer.start_link(__MODULE__, {handle, device})
  end

  @impl true
  def init({handle, device}) do
    Phoenix.PubSub.subscribe(Exkl.PubSub, "cpu_metrics")

    case HidApiNif.write(handle, HidDevice.startup_payload(device)) do
      0 -> :ok
      _ -> Logger.warning("HID startup write failed for #{HidDevice.name(device)}")
    end

    {:ok, %{handle: handle, device: device}}
  end

  @impl true
  def handle_info({:cpu_metrics, %Exkl.AK{} = metrics}, state) do
    Logger.debug("HID update for #{HidDevice.name(state.device)}: #{inspect(metrics)}%")

    payload = HidDevice.encode_metrics(state.device, metrics)

    case HidApiNif.write(state.handle, payload) do
      0 -> :ok
      _ -> Logger.error("HID write failed for #{HidDevice.name(state.device)}")
    end

    {:noreply, state}
  rescue
    e ->
      Logger.error("HID worker failed for #{HidDevice.name(state.device)}: #{inspect(e)}")
      {:noreply, state}
  end

  @impl true
  def terminate(reason, %{handle: handle, device: device}) do
    Logger.debug("Closing #{HidDevice.name(device)}. Reason: #{inspect(reason)}")
    HidApiNif.close(handle)
    :ok
  end
end
