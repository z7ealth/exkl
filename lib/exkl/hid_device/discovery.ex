defmodule Exkl.HidDevice.Discovery do
  @moduledoc false

  require Logger

  alias Exkl.HidApiNif
  alias Exkl.HidDevice.Catalog
  alias Exkl.Display

  @type status :: :connected | :detected | :unsupported

  @type device :: %{
          name: String.t(),
          vendor_id: non_neg_integer(),
          product_id: non_neg_integer(),
          usb_id: String.t(),
          family: atom() | nil,
          status: status()
        }

  @spec discover() :: [{struct(), non_neg_integer()}]
  def discover do
    Catalog.deepcool_vendor_id()
    |> HidApiNif.enumerate()
    |> Enum.uniq()
    |> Enum.flat_map(&device_for/1)
  end

  @spec list() :: [device()]
  def list do
    connected = Display.connected_product_ids()

    Catalog.deepcool_vendor_id()
    |> HidApiNif.enumerate()
    |> Enum.uniq()
    |> Enum.map(&entry_for(&1, connected))
    |> Enum.sort_by(& &1.product_id)
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

  defp entry_for({vendor_id, product_id}, connected) do
    usb_id = "#{hex(vendor_id)}:#{hex(product_id)}"

    case Catalog.lookup(vendor_id, product_id) do
      {:ok, device} ->
        status =
          if MapSet.member?(connected, product_id) do
            :connected
          else
            :detected
          end

        %{
          name: Catalog.label(device),
          vendor_id: vendor_id,
          product_id: product_id,
          usb_id: usb_id,
          family: Catalog.family(device),
          status: status
        }

      :error ->
        %{
          name: "Unknown DeepCool device",
          vendor_id: vendor_id,
          product_id: product_id,
          usb_id: usb_id,
          family: nil,
          status: :unsupported
        }
    end
  end

  defp hex(value), do: String.pad_leading(Integer.to_string(value, 16), 4, "0")
end
