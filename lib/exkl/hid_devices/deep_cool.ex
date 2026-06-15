defmodule Exkl.HidDevices.DeepCool do
  @moduledoc false

  @display_modes %{
    celsius: 19,
    fahrenheit: 35,
    utilization: 76,
    start: 170
  }

  @spec encode(float(), Exkl.AK.modes() | :start) :: binary()
  def encode(value, mode) do
    value = sanitize_display_value(value, mode)

    base_data = List.duplicate(0, 64)

    numbers =
      value
      |> trunc()
      |> abs()
      |> Integer.to_string()
      |> String.graphemes()
      |> Enum.map(&String.to_integer/1)

    base_data = List.replace_at(base_data, 0, 16)

    bar_value = get_bar_value(value, mode) |> trunc()
    base_data = List.replace_at(base_data, 2, bar_value)

    base_data =
      case mode do
        :start -> List.replace_at(base_data, 1, @display_modes[:start])
        :cpu_util -> List.replace_at(base_data, 1, @display_modes[:utilization])
        :cpu_temp_f -> List.replace_at(base_data, 1, @display_modes[:fahrenheit])
        _ -> List.replace_at(base_data, 1, @display_modes[:celsius])
      end

    result_data =
      case length(numbers) do
        1 -> List.replace_at(base_data, 5, Enum.at(numbers, 0))
        2 ->
          base_data
          |> List.replace_at(4, Enum.at(numbers, 0))
          |> List.replace_at(5, Enum.at(numbers, 1))

        3 ->
          base_data
          |> List.replace_at(3, Enum.at(numbers, 0))
          |> List.replace_at(4, Enum.at(numbers, 1))
          |> List.replace_at(5, Enum.at(numbers, 2))

        _ ->
          base_data
      end

    :binary.list_to_bin(result_data)
  end

  defp get_bar_value(metrics_value, _mode) when metrics_value < 10.0, do: 0.0

  defp get_bar_value(metrics_value, mode) when mode in [:cpu_temp_c, :cpu_util],
    do: metrics_value / 10.0

  defp get_bar_value(metrics_value, :cpu_temp_f),
    do: fahrenheit_to_celsius(metrics_value) / 10.0

  defp sanitize_display_value(value, :cpu_util) when value < 0 or value > 100, do: 0.0
  defp sanitize_display_value(value, _) when value < 0, do: 0.0
  defp sanitize_display_value(value, _), do: value

  defp fahrenheit_to_celsius(f) when is_float(f), do: (f - 32) * 5 / 9
end
