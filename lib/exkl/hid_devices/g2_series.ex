defmodule Exkl.HidDevices.G2Series do
  @moduledoc false

  @template [16, 104, 1, 8, 12, 1, 2]

  @spec encode(%Exkl.AK{}) :: binary()
  def encode(%Exkl.AK{} = metrics), do: encode_metrics(metrics)

  @spec startup() :: binary()
  def startup, do: encode_metrics(%Exkl.AK{})

  defp encode_metrics(%Exkl.AK{} = metrics) do
    temp_c = metrics.cpu_temp_c || metrics.metrics_value || 0.0
    temp_c = if is_number(temp_c) and temp_c >= 0, do: temp_c * 1.0, else: 0.0
    fahrenheit? = metrics.mode == :cpu_temp_f

    temp =
      if fahrenheit? do
        celsius_to_fahrenheit(temp_c)
      else
        temp_c
      end

    power_w =
      case metrics.cpu_power_w do
        watts when is_float(watts) and watts > 0 -> round(watts) |> min(65_535)
        _ -> 0
      end

    usage = (metrics.cpu_util || 0.0) |> round() |> min(100) |> max(0)
    freq_mhz = (metrics.cpu_freq_mhz || 0.0) |> round() |> min(65_535) |> max(0)

    <<power_hi::8, power_lo::8>> = <<power_w::16-big>>
    <<temp_b0::8, temp_b1::8, temp_b2::8, temp_b3::8>> = <<temp::float-big-32>>
    <<freq_hi::8, freq_lo::8>> = <<freq_mhz::16-big>>

    payload =
      @template ++
        [
          power_hi,
          power_lo,
          if(fahrenheit?, do: 1, else: 0),
          temp_b0,
          temp_b1,
          temp_b2,
          temp_b3,
          usage,
          freq_hi,
          freq_lo
        ]

    checksum = payload |> Enum.slice(1..16) |> Enum.sum() |> rem(256)

    (payload ++ [checksum, 22] ++ List.duplicate(0, 64 - 19))
    |> Enum.take(64)
    |> :binary.list_to_bin()
  end

  defp celsius_to_fahrenheit(celsius), do: celsius * 9.0 / 5.0 + 32.0
end
