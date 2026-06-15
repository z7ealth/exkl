defmodule Exkl.Display do
  @moduledoc """
  Supervises one worker per connected HID display device.

  Each supported device model implements `Exkl.HidDevice` and is listed in
  `Exkl.HidDevice.Registry`. On startup, every registered model is probed via
  USB vendor/product ID; connected devices receive live metrics over PubSub.
  """

  use Supervisor

  require Logger

  alias Exkl.Display.Worker
  alias Exkl.HidApiNif
  alias Exkl.HidDevice
  alias Exkl.HidDevice.Registry

  def start_link(init_arg \\ []) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl Supervisor
  def init(_arg) do
    children =
      Registry.all()
      |> Enum.flat_map(&start_worker/1)

    case children do
      [] ->
        Logger.info("No HID display devices connected")

      _ ->
        Logger.info("Started #{length(children)} HID display worker(s)")
    end

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp start_worker(device) do
    vendor_id = HidDevice.vendor_id(device)
    product_id = HidDevice.product_id(device)

    case open_handle(vendor_id, product_id) do
      {:ok, handle} ->
        [
          %{
            id: {device.__struct__, product_id},
            start: {Worker, :start_link, [{handle, device}]}
          }
        ]

      :error ->
        Logger.debug(
          "HID device not connected: #{HidDevice.name(device)} " <>
            "(#{hex(vendor_id)}:#{hex(product_id)})"
        )

        []
    end
  end

  defp open_handle(vendor_id, product_id) do
    case HidApiNif.open(vendor_id, product_id) do
      handle when is_integer(handle) -> :error
      handle -> {:ok, handle}
    end
  end

  defp hex(value), do: String.pad_leading(Integer.to_string(value, 16), 4, "0")
end
