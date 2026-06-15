defmodule Exkl.HidDevices.Morpheus do
  @moduledoc "DeepCool case displays with dual CPU/GPU readouts (e.g. MORPHEUS, PID 7)."

  @behaviour Exkl.HidDevice.Behaviour

  defstruct [:product_id]

  @impl true
  def vendor_id, do: Exkl.HidDevice.Catalog.deepcool_vendor_id()

  @impl true
  def default_product_id, do: 7

  @impl true
  def name, do: "DeepCool MORPHEUS"
end

defimpl Exkl.HidDevice, for: Exkl.HidDevices.Morpheus do
  defdelegate vendor_id(device), to: Exkl.HidDevice.Impl
  defdelegate product_id(device), to: Exkl.HidDevice.Impl
  defdelegate name(device), to: Exkl.HidDevice.Impl
  defdelegate startup_payload(device), to: Exkl.HidDevice.Impl
  defdelegate encode_metrics(device, metrics), to: Exkl.HidDevice.Impl
end
