defmodule Exkl.HidDevices.AkSeriesDevice do
  @moduledoc "Legacy DeepCool AK/AG air coolers using the AK series packet format."

  @behaviour Exkl.HidDevice.Behaviour

  defstruct [:product_id]

  @impl true
  def vendor_id, do: Exkl.HidDevice.Catalog.deepcool_vendor_id()

  @impl true
  def default_product_id, do: 1

  @impl true
  def name, do: "DeepCool AK Series"
end

defimpl Exkl.HidDevice, for: Exkl.HidDevices.AkSeriesDevice do
  defdelegate vendor_id(device), to: Exkl.HidDevice.Impl
  defdelegate product_id(device), to: Exkl.HidDevice.Impl
  defdelegate name(device), to: Exkl.HidDevice.Impl
  defdelegate startup_payload(device), to: Exkl.HidDevice.Impl
  defdelegate encode_metrics(device, metrics), to: Exkl.HidDevice.Impl
end
