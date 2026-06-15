defmodule Exkl.HidDevice.Impl do
  @moduledoc false

  alias Exkl.HidDevice.Catalog
  alias Exkl.HidDevices.{AkSeries, ChSeries, G2Series}

  def vendor_id(_device), do: Catalog.deepcool_vendor_id()

  def product_id(%{product_id: product_id}), do: product_id

  def name(device), do: Catalog.label(device)

  def startup_payload(device) do
    device
    |> encoder()
    |> then(& &1.startup())
  end

  def encode_metrics(device, metrics) do
    device
    |> encoder()
    |> then(& &1.encode(metrics))
  end

  defp encoder(device) do
    case Catalog.family(device) do
      :ak_series -> AkSeries
      :ch_series -> ChSeries
      :g2_series -> G2Series
      nil -> AkSeries
    end
  end
end
