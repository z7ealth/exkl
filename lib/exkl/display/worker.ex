defmodule Exkl.Display.Worker do
  @moduledoc false

  use GenServer

  require Logger

  alias Exkl.Display.Settings
  alias Exkl.HidApiNif
  alias Exkl.HidDevice

  @off_writes 5

  def start_link({device, vendor_id, product_id}) do
    GenServer.start_link(__MODULE__, {device, vendor_id, product_id})
  end

  @impl true
  def init({device, vendor_id, product_id}) do
    :ok = Settings.subscribe()
    Phoenix.PubSub.subscribe(Exkl.PubSub, "cpu_metrics")

    screen_on = Settings.screen_on?()
    handle = open_handle(vendor_id, product_id)

    cond do
      handle && screen_on ->
        write_startup(handle, device)

      handle ->
        write_off(handle, device)

      true ->
        :ok
    end

    {:ok,
     %{
       handle: handle,
       device: device,
       vendor_id: vendor_id,
       product_id: product_id,
       screen_on: screen_on,
       last_metrics: nil
     }}
  end

  @impl true
  def handle_info({:screen_on, on}, %{screen_on: on} = state), do: {:noreply, state}

  def handle_info({:screen_on, true}, %{handle: handle, device: device} = state) when not is_nil(handle) do
    write_startup(handle, device)

    if state.last_metrics do
      write_metrics(handle, device, state.last_metrics)
    end

    {:noreply, %{state | screen_on: true}}
  end

  def handle_info({:screen_on, true}, state) do
    case open_handle(state.vendor_id, state.product_id) do
      nil ->
        Logger.warning("Could not open HID display for #{HidDevice.name(state.device)}")
        {:noreply, %{state | screen_on: true}}

      handle ->
        write_startup(handle, state.device)

        if state.last_metrics do
          write_metrics(handle, state.device, state.last_metrics)
        end

        {:noreply, %{state | handle: handle, screen_on: true}}
    end
  end

  def handle_info({:screen_on, false}, %{handle: nil} = state) do
    {:noreply, %{state | screen_on: false}}
  end

  def handle_info({:screen_on, false}, %{handle: handle, device: device} = state) do
    write_off(handle, device)
    {:noreply, %{state | screen_on: false}}
  end

  @impl true
  def handle_info({:cpu_metrics, %Exkl.AK{} = metrics}, state) do
    if state.handle && Settings.screen_on?() do
      Logger.debug("HID update for #{HidDevice.name(state.device)}: #{inspect(metrics)}%")
      write_metrics(state.handle, state.device, metrics)
    end

    {:noreply, %{state | last_metrics: metrics}}
  rescue
    e ->
      Logger.error("HID worker failed for #{HidDevice.name(state.device)}: #{inspect(e)}")
      {:noreply, %{state | last_metrics: metrics}}
  end

  @impl true
  def terminate(reason, %{handle: nil, device: device}) do
    Logger.debug("Stopping #{HidDevice.name(device)} worker (no open handle). Reason: #{inspect(reason)}")
    :ok
  end

  def terminate(reason, %{handle: handle, device: device}) do
    Logger.debug("Stopping #{HidDevice.name(device)} worker. Reason: #{inspect(reason)}")
    close_handle(handle)
    :ok
  end

  defp open_handle(vendor_id, product_id) do
    case HidApiNif.open(vendor_id, product_id) do
      handle when is_integer(handle) ->
        Logger.warning("Failed to open HID display #{hex(vendor_id)}:#{hex(product_id)}")
        nil

      handle ->
        handle
    end
  end

  defp close_handle(handle) do
    HidApiNif.close(handle)
  end

  defp write_startup(handle, device) do
    case HidApiNif.write(handle, HidDevice.startup_payload(device)) do
      0 -> :ok
      _ -> Logger.warning("HID startup write failed for #{HidDevice.name(device)}")
    end
  end

  defp write_off(handle, device) do
    payload = HidDevice.off_payload(device)

    for _ <- 1..@off_writes do
      case HidApiNif.write(handle, payload) do
        0 -> :ok
        _ -> Logger.warning("HID off write failed for #{HidDevice.name(device)}")
      end
    end
  end

  defp write_metrics(handle, device, metrics) do
    payload = HidDevice.encode_metrics(device, metrics)

    case HidApiNif.write(handle, payload) do
      0 -> :ok
      _ -> Logger.error("HID write failed for #{HidDevice.name(device)}")
    end
  end

  defp hex(value), do: String.pad_leading(Integer.to_string(value, 16), 4, "0")
end
