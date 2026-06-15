defmodule Exkl.HidDevices.AkSeries do
  @moduledoc false

  @display_modes %{
    celsius: 19,
    fahrenheit: 35,
    utilization: 76,
    start: 170
  }

  @spec encode(%Exkl.AK{}) :: binary()
  def encode(%Exkl.AK{} = metrics), do: encode_metrics(metrics)

  @spec startup() :: binary()
  def startup do
    build_packet(:start, 0.0, 0.0)
  end

  defp encode_metrics(%Exkl.AK{mode: mode, metrics_value: value, cpu_util: cpu_util}) do
    build_packet(mode, value, cpu_util || 0.0)
  end

  defp build_packet(:start, _value, _cpu_usage) do
    List.duplicate(0, 64)
    |> List.replace_at(0, 16)
    |> List.replace_at(1, @display_modes.start)
    |> List.replace_at(2, 1)
    |> :binary.list_to_bin()
  end

  defp build_packet(mode, value, cpu_usage) do
    {mode_byte, digits} =
      case mode do
        :cpu_util -> {@display_modes.utilization, value_digits(value)}
        :cpu_temp_f -> {@display_modes.fahrenheit, temp_digits(value)}
        _ -> {@display_modes.celsius, temp_digits(value)}
      end

    bar_usage = if mode == :cpu_util, do: value, else: cpu_usage

    bar =
      if bar_usage < 15.0 do
        1
      else
        bar_usage / 10.0 |> round() |> min(10) |> max(1)
      end

    List.duplicate(0, 64)
    |> List.replace_at(0, 16)
    |> List.replace_at(1, mode_byte)
    |> List.replace_at(2, bar)
    |> put_digits(digits)
    |> :binary.list_to_bin()
  end

  defp temp_digits(value) when value < 0, do: {0, 0, 0}

  defp temp_digits(value) do
    value
    |> max(0.0)
    |> trunc()
    |> integer_digits()
  end

  defp integer_digits(n) when n < 10, do: {0, 0, n}
  defp integer_digits(n) when n < 100, do: {0, div(n, 10), rem(n, 10)}
  defp integer_digits(n) when n < 1000, do: {div(n, 100), div(rem(n, 100), 10), rem(n, 10)}
  defp integer_digits(_), do: {9, 9, 9}

  defp value_digits(value) when value < 0 or value > 100, do: {0, 0, 0}

  defp value_digits(value) do
    scaled = value |> round() |> min(100)
    {div(scaled, 100), div(rem(scaled, 100), 10), rem(scaled, 10)}
  end

  defp put_digits(data, {d3, d4, d5}) do
    data
    |> List.replace_at(3, d3)
    |> List.replace_at(4, d4)
    |> List.replace_at(5, d5)
  end
end
