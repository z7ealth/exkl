defmodule Exkl.Display do
  @moduledoc """
  Supervises one worker per connected DeepCool HID display.

  Devices are discovered automatically via `hidapi` enumeration (vendor `0x3633`),
  matching the approach used by
  [deepcool-digital-linux](https://github.com/Nortank12/deepcool-digital-linux).
  """

  use Supervisor

  require Logger

  alias Exkl.Display.Worker
  alias Exkl.HidApiNif
  alias Exkl.HidDevice
  alias Exkl.HidDevice.Discovery

  def start_link(init_arg \\ []) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl Supervisor
  def init(_arg) do
    children =
      Discovery.discover()
      |> Enum.flat_map(&start_worker/1)

    case children do
      [] ->
        Logger.info("No supported DeepCool HID display devices connected")

      workers ->
        Logger.info("Started #{length(workers)} HID display worker(s)")
    end

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp start_worker({device, product_id}) do
    vendor_id = HidDevice.vendor_id(device)

    case open_handle(vendor_id, product_id) do
      {:ok, handle} ->
        Logger.info("Connected HID display: #{HidDevice.name(device)} (#{hex(vendor_id)}:#{hex(product_id)})")

        [
          %{
            id: {device.__struct__, product_id},
            start: {Worker, :start_link, [{handle, device}]}
          }
        ]

      :error ->
        Logger.warning("Failed to open HID display: #{HidDevice.name(device)}")
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

  @spec connected_product_ids() :: MapSet.t(non_neg_integer())
  def connected_product_ids do
    __MODULE__
    |> Supervisor.which_children()
    |> Enum.flat_map(fn
      {{_module, product_id}, pid, :worker, _} when is_pid(pid) ->
        if Process.alive?(pid), do: [product_id], else: []

      _ ->
        []
    end)
    |> MapSet.new()
  end
end
