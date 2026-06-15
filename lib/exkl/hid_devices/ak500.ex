defmodule Exkl.HidDevices.AK500 do
  @moduledoc "DeepCool AK500 Digital CPU cooler."

  @behaviour Exkl.HidDevice.Behaviour

  defstruct []

  @vendor_id 0x3633
  @product_id 0x0003

  @impl true
  def vendor_id, do: @vendor_id

  @impl true
  def product_id, do: @product_id

  @impl true
  def name, do: "DeepCool AK500 Digital"
end

defimpl Exkl.HidDevice, for: Exkl.HidDevices.AK500 do
  alias Exkl.HidDevices.{AK500, DeepCool}

  def vendor_id(_), do: AK500.vendor_id()
  def product_id(_), do: AK500.product_id()
  def name(_), do: AK500.name()
  def startup_payload(_), do: DeepCool.encode(0.0, :start)
  def encode_metrics(_, %Exkl.AK{} = metrics), do: DeepCool.encode(metrics.metrics_value, metrics.mode)
end
