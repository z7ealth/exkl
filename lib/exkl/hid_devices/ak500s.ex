defmodule Exkl.HidDevices.AK500S do
  @moduledoc "DeepCool AK500S Digital CPU cooler (USB PID 4)."

  @behaviour Exkl.HidDevice.Behaviour

  defstruct [:product_id]

  @impl true
  def vendor_id, do: Exkl.HidDevice.Catalog.deepcool_vendor_id()

  @impl true
  def default_product_id, do: 4

  @impl true
  def name, do: "DeepCool AK500S Digital"
end

defimpl Exkl.HidDevice, for: Exkl.HidDevices.AK500S do
  defdelegate vendor_id(device), to: Exkl.HidDevice.Impl
  defdelegate product_id(device), to: Exkl.HidDevice.Impl
  defdelegate name(device), to: Exkl.HidDevice.Impl
  defdelegate startup_payload(device), to: Exkl.HidDevice.Impl
  defdelegate encode_metrics(device, metrics), to: Exkl.HidDevice.Impl
end
