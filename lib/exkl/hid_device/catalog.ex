defmodule Exkl.HidDevice.Catalog do
  @moduledoc false

  alias Exkl.HidDevices.{
    AK500,
    AK620,
    AK500S,
    AkSeriesDevice,
    Morpheus
  }

  @deepcool_vendor_id 0x3633

  @entries %{
    1 => {AkSeriesDevice, :ak_series, "AK400 DIGITAL"},
    2 => {AkSeriesDevice, :ak_series, "AK620 DIGITAL"},
    3 => {AK500, :ak_series, "AK500 DIGITAL"},
    4 => {AK500S, :ak_series, "AK500S DIGITAL"},
    5 => {Morpheus, :ch_series, "CH560 DIGITAL"},
    7 => {Morpheus, :ch_series, "MORPHEUS"},
    21 => {Morpheus, :ch_series, "CH360 DIGITAL"},
    41 => {AK620, :g2_series, "AK620 G2 DIGITAL NYX"},
    42 => {AK620, :g2_series, "AK700 DIGITAL NYX"},
    43 => {AK620, :g2_series, "AK400 G2 DIGITAL NYX"},
    44 => {AK620, :g2_series, "AK500 G2 DIGITAL NYX"}
  }

  @spec deepcool_vendor_id() :: non_neg_integer()
  def deepcool_vendor_id, do: @deepcool_vendor_id

  @spec lookup(non_neg_integer(), non_neg_integer()) :: {:ok, struct()} | :error
  def lookup(@deepcool_vendor_id, product_id) do
    case Map.get(@entries, product_id) do
      {module, _family, _label} -> {:ok, struct(module, product_id: product_id)}
      nil -> :error
    end
  end

  def lookup(_vendor_id, _product_id), do: :error

  @spec family(struct()) :: :ak_series | :ch_series | :g2_series | nil
  def family(%{product_id: product_id}) do
    case Map.get(@entries, product_id) do
      {_, family, _} -> family
      nil -> nil
    end
  end

  @spec label(struct()) :: String.t()
  def label(%{product_id: product_id}) do
    case Map.get(@entries, product_id) do
      {_, _, label} -> label
      nil -> "DeepCool device"
    end
  end
end
