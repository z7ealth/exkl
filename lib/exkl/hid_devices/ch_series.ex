defmodule Exkl.HidDevices.ChSeries do
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
    List.duplicate(0, 64)
    |> List.replace_at(0, 16)
    |> List.replace_at(1, @display_modes.start)
    |> List.replace_at(2, 1)
    |> :binary.list_to_bin()
  end

  @spec blank() :: binary()
  def blank, do: encode_metrics(%Exkl.AK{mode: :cpu_temp_c, metrics_value: 0.0, cpu_util: 0.0, gpu_util: 0.0})

  @spec off() :: binary()
  def off, do: blank()

  defp encode_metrics(%Exkl.AK{} = metrics) do
    cpu_usage = metrics.cpu_util || 0.0
    gpu_usage = metrics.gpu_util || 0.0

    {cpu_mode, cpu_value, gpu_mode, gpu_value} =
      case metrics.mode do
        :cpu_util ->
          {:cpu_util, cpu_usage, :gpu_util, gpu_usage}

        :cpu_temp_f ->
          gpu_c = metrics.gpu_temp_c || 0.0

          {:cpu_temp_f, metrics.metrics_value, :gpu_temp_f, celsius_to_fahrenheit(gpu_c)}

        _ ->
          {:cpu_temp_c, metrics.metrics_value, :gpu_temp_c, metrics.gpu_temp_c || 0.0}
      end

    build_packet(cpu_mode, cpu_value, gpu_mode, gpu_value, cpu_usage, gpu_usage)
  end

  defp build_packet(cpu_mode, cpu_value, gpu_mode, gpu_value, cpu_usage, gpu_usage) do
    base = List.duplicate(0, 64) |> List.replace_at(0, 16)

    {cpu_mode_byte, cpu_digits} = primary_display(cpu_mode, cpu_value)
    {gpu_mode_byte, gpu_digits} = secondary_display(gpu_mode, gpu_value)

    base
    |> List.replace_at(1, cpu_mode_byte)
    |> List.replace_at(2, usage_bar(cpu_usage))
    |> put_digits(cpu_digits, 3)
    |> List.replace_at(6, gpu_mode_byte)
    |> List.replace_at(7, usage_bar(gpu_usage))
    |> put_digits(gpu_digits, 8)
    |> :binary.list_to_bin()
  end

  defp primary_display(:cpu_util, value),
    do: {@display_modes.utilization, value_digits(value)}

  defp primary_display(:cpu_temp_f, value),
    do: {@display_modes.fahrenheit, temp_digits(value)}

  defp primary_display(_, value),
    do: {@display_modes.celsius, temp_digits(value)}

  defp secondary_display(:gpu_util, value),
    do: {@display_modes.utilization, value_digits(value)}

  defp secondary_display(:gpu_temp_f, value),
    do: {@display_modes.fahrenheit, temp_digits(value)}

  defp secondary_display(_, value),
    do: {@display_modes.celsius, temp_digits(value)}

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

  defp usage_bar(usage) when usage < 15.0, do: 1
  defp usage_bar(usage), do: usage / 10.0 |> round() |> min(10) |> max(1)

  defp put_digits(data, {d0, d1, d2}, offset) do
    data
    |> List.replace_at(offset, d0)
    |> List.replace_at(offset + 1, d1)
    |> List.replace_at(offset + 2, d2)
  end

  defp celsius_to_fahrenheit(celsius), do: celsius * 9.0 / 5.0 + 32.0
end
