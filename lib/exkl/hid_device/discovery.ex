defmodule Exkl.HidDevice.Discovery do
  @moduledoc false

  require Logger

  alias Exkl.HidApiNif
  alias Exkl.HidDevice.Catalog

  @spec discover() :: [{struct(), non_neg_integer()}]
  def discover do
    Catalog.deepcool_vendor_id()
    |> HidApiNif.enumerate()
    |> Enum.uniq()
    |> Enum.flat_map(&device_for/1)
  end

  defp device_for({vendor_id, product_id}) do
    case Catalog.lookup(vendor_id, product_id) do
      {:ok, device} ->
        [{device, product_id}]

      :error ->
        Logger.warning(
          "Unsupported DeepCool HID device #{hex(vendor_id)}:#{hex(product_id)} " <>
            "(see https://github.com/Nortank12/deepcool-digital-linux device list)"
        )

        []
    end
  end

  defp hex(value), do: String.pad_leading(Integer.to_string(value, 16), 4, "0")
end
