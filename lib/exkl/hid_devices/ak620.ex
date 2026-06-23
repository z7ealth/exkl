defmodule Exkl.HidDevices.AK620 do
  @moduledoc """
  DeepCool AK620 G2 Digital NYX (USB PID 41).

  Uses the G2/LQ binary packet format from
  [deepcool-digital-linux](https://github.com/Nortank12/deepcool-digital-linux)
  (`lq_series.rs`): power, temperature, utilization, frequency, and checksum.
  """

  @behaviour Exkl.HidDevice.Behaviour

  defstruct [:product_id]

  @impl true
  def vendor_id, do: Exkl.HidDevice.Catalog.deepcool_vendor_id()

  @impl true
  def default_product_id, do: 41

  @impl true
  def name, do: "DeepCool AK620 G2 Digital NYX"
end

defimpl Exkl.HidDevice, for: Exkl.HidDevices.AK620 do
  defdelegate vendor_id(device), to: Exkl.HidDevice.Impl
  defdelegate product_id(device), to: Exkl.HidDevice.Impl
  defdelegate name(device), to: Exkl.HidDevice.Impl
  defdelegate startup_payload(device), to: Exkl.HidDevice.Impl
  defdelegate blank_payload(device), to: Exkl.HidDevice.Impl
  defdelegate off_payload(device), to: Exkl.HidDevice.Impl
  defdelegate encode_metrics(device, metrics), to: Exkl.HidDevice.Impl
end
