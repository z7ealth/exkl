defmodule Exkl.Bar do
  @moduledoc """
  Gauge bar level for AK-series HID packets and the dashboard UI.

  The bar tracks the displayed metric: value ÷ 10, up to 10 segments on the
  cooler (0–100% progress in the web UI). Values below 10 show an empty bar.
  """

  @max_segments 10

  @spec segments(number(), atom()) :: 0..10
  def segments(_value, :start), do: 0

  def segments(value, mode) do
    value
    |> normalize_value(mode)
    |> segments_from_normalized()
  end

  @spec progress(number(), atom()) :: float()
  def progress(value, mode) do
    segments(value, mode) / @max_segments * 100.0
  end

  defp normalize_value(value, :cpu_util), do: clamp(value, 0, 100)

  defp normalize_value(value, :cpu_temp_f) do
    value |> fahrenheit_to_celsius() |> max(0)
  end

  defp normalize_value(value, _mode), do: max(value, 0)

  defp segments_from_normalized(value) when value < 10, do: 0

  defp segments_from_normalized(value) do
    value
    |> Kernel./(10.0)
    |> trunc()
    |> min(@max_segments)
  end

  defp fahrenheit_to_celsius(fahrenheit), do: (fahrenheit - 32) * 5 / 9

  defp clamp(value, min, _max) when value < min, do: min
  defp clamp(value, _min, max) when value > max, do: max
  defp clamp(value, _min, _max), do: value
end
