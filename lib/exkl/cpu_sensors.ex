defmodule Exkl.CpuSensors do
  @moduledoc false

  alias Exkl.SensorsNif

  @spec temp_celsius() :: float() | nil
  def temp_celsius do
    case SensorsNif.get_cpu_temp_celsius() do
      temp when temp >= 0 -> temp
      _ -> hwmon_temp_celsius()
    end
  end

  @spec temp_fahrenheit() :: float() | nil
  def temp_fahrenheit do
    case temp_celsius() do
      nil -> nil
      c -> c * 9.0 / 5.0 + 32.0
    end
  end

  @spec frequency_mhz() :: float() | nil
  def frequency_mhz do
    "/sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq"
    |> Path.wildcard()
    |> Enum.map(&read_khz/1)
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      freqs -> Enum.max(freqs) / 1000.0
    end
  end

  @spec power_watts() :: float() | nil
  def power_watts do
    rapl_power() || zenpower_hwmon() || sensors_power()
  end

  defp rapl_power do
    [
      "/sys/class/powercap/intel-rapl*/intel-rapl*:*/power1_average",
      "/sys/class/powercap/intel-rapl*/intel-rapl*:*/power1_input"
    ]
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.find_value(&read_power_uw/1)
  end

  defp zenpower_hwmon do
    hwmon_path("zenpower")
    |> read_hwmon_power()
  end

  defp hwmon_temp_celsius do
    read_hwmon_temp(hwmon_path("zenpower")) || read_hwmon_temp(hwmon_path("k10temp"))
  end

  defp read_hwmon_temp(nil), do: nil

  defp read_hwmon_temp(hwmon_path) do
    case File.read(Path.join(hwmon_path, "temp1_input")) do
      {:ok, content} ->
        case Integer.parse(String.trim(content)) do
          {mc, _} when mc > 0 -> mc / 1000.0
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp sensors_power do
    case SensorsNif.get_cpu_power_watts() do
      power when power > 0 -> power
      _ -> nil
    end
  end

  defp hwmon_path(name) do
    "/sys/class/hwmon/hwmon*/name"
    |> Path.wildcard()
    |> Enum.find_value(fn path ->
      case File.read(path) do
        {:ok, content} ->
          if String.trim(content) == name, do: Path.dirname(path), else: nil

        _ ->
          nil
      end
    end)
  end

  defp read_hwmon_power(nil), do: nil

  defp read_hwmon_power(hwmon_path) do
    ["power1_average", "power1_input"]
    |> Enum.find_value(fn file ->
      hwmon_path
      |> Path.join(file)
      |> read_power_uw()
    end)
  end

  defp read_power_uw(path) do
    case File.read(path) do
      {:ok, content} ->
        case Integer.parse(String.trim(content)) do
          {uw, _} when uw > 0 -> uw / 1_000_000.0
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp read_khz(path) do
    case File.read(path) do
      {:ok, content} ->
        case Integer.parse(String.trim(content)) do
          {value, _} when value > 0 -> value
          _ -> nil
        end

      _ ->
        nil
    end
  end
end
