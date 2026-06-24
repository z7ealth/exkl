defmodule Exkl.Desktop.TrayPosition do
  @moduledoc false

  require Logger

  @env_key "EXKL_TRAY_POPUP_POSITION"
  @default "top-right"
  @margin 16

  @type corner :: :top_right | :top_left | :bottom_right | :bottom_left

  @spec coordinates({width :: pos_integer(), height :: pos_integer()}) :: {integer(), integer()}
  def coordinates({width, height}) do
    {origin_x, origin_y, area_w, area_h} = primary_client_area()
    coordinates(corner(), {width, height}, origin_x, origin_y, area_w, area_h)
  end

  @spec corner() :: corner()
  def corner do
    System.get_env(@env_key, @default)
    |> parse()
  end

  @spec parse(String.t() | nil) :: corner()
  def parse(nil), do: :top_right

  def parse(value) when is_binary(value) do
    case value |> String.trim() |> String.downcase() |> String.replace("_", "-") do
      "top-right" -> :top_right
      "top-left" -> :top_left
      "bottom-right" -> :bottom_right
      "bottom-left" -> :bottom_left
      other ->
        Logger.warning(
          "Unknown #{@env_key}=#{inspect(other)} (expected top-right, top-left, bottom-right, or bottom-left); using top-right"
        )

        :top_right
    end
  end

  defp coordinates(:top_right, {width, _height}, origin_x, origin_y, area_w, _area_h) do
    {origin_x + area_w - width - @margin, origin_y + @margin}
  end

  defp coordinates(:top_left, {_width, _height}, origin_x, origin_y, _area_w, _area_h) do
    {origin_x + @margin, origin_y + @margin}
  end

  defp coordinates(:bottom_right, {width, height}, origin_x, origin_y, area_w, area_h) do
    {origin_x + area_w - width - @margin, origin_y + area_h - height - @margin}
  end

  defp coordinates(:bottom_left, {_width, height}, origin_x, origin_y, _area_w, area_h) do
    {origin_x + @margin, origin_y + area_h - height - @margin}
  end

  defp primary_client_area do
    display = :wxDisplay.new()
    area = :wxDisplay.getClientArea(display)
    :wxDisplay.destroy(display)
    area
  end
end
