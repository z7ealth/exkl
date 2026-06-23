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
    build_packet(:start, 0.0)
  end

  @spec blank() :: binary()
  def blank, do: encode_metrics(%Exkl.AK{mode: :cpu_temp_c, metrics_value: 0.0})

  @spec off() :: binary()
  def off do
    List.duplicate(0, 64)
    |> List.replace_at(0, 16)
    |> :binary.list_to_bin()
  end

  defp encode_metrics(%Exkl.AK{mode: mode, metrics_value: value}) do
    build_packet(mode, value)
  end

  defp build_packet(:start, _value) do
    List.duplicate(0, 64)
    |> List.replace_at(0, 16)
    |> List.replace_at(1, @display_modes.start)
    |> List.replace_at(2, Exkl.Bar.segments(0, :start))
    |> :binary.list_to_bin()
  end

  defp build_packet(mode, value) do
    {mode_byte, digits} =
      case mode do
        :cpu_util -> {@display_modes.utilization, value_digits(value)}
        :cpu_temp_f -> {@display_modes.fahrenheit, temp_digits(value)}
        _ -> {@display_modes.celsius, temp_digits(value)}
      end

    bar = Exkl.Bar.segments(value, mode)

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

  defp value_digits(value) when value < 0, do: {0, 0, 0}

  defp value_digits(value) do
    scaled = value |> round() |> min(100) |> max(0)
    {div(scaled, 100), div(rem(scaled, 100), 10), rem(scaled, 10)}
  end

  defp put_digits(data, {d3, d4, d5}) do
    data
    |> List.replace_at(3, d3)
    |> List.replace_at(4, d4)
    |> List.replace_at(5, d5)
  end
end
