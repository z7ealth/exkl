defmodule Exkl.CpuSensors do
  @moduledoc false

  require Logger

  alias Exkl.SensorsNif

  @rapl_domain_glob "/sys/class/powercap/intel-rapl*/intel-rapl*"
  @rapl_energy_key {:exkl, :rapl_energy}
  @rapl_watts_key {:exkl, :rapl_watts}

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
    rapl_power()
  end

  defp rapl_power do
    rapl_package_domain()
    |> case do
      nil -> last_rapl_watts()
      domain -> read_rapl_domain_power(domain) || last_rapl_watts()
    end
  end

  defp rapl_package_domain do
    @rapl_domain_glob
    |> Path.wildcard()
    |> Enum.find(fn path ->
      case File.read(Path.join(path, "name")) do
        {:ok, name} -> String.starts_with?(String.trim(name), "package")
        _ -> false
      end
    end)
  end

  defp read_rapl_domain_power(domain) do
    domain
    |> Path.join("power1_average")
    |> read_power_uw()
    |> or_else(fn -> domain |> Path.join("power1_input") |> read_power_uw() end)
    |> or_else(fn -> rapl_energy_power(domain) end)
    |> tap(&store_rapl_watts/1)
  end

  defp rapl_energy_power(domain) do
    with {:ok, energy} <- read_energy_uj(domain),
         {:ok, now} <- {:ok, System.monotonic_time(:millisecond)},
         max_energy <- read_max_energy_uj(domain) do
      key = {@rapl_energy_key, domain}

      case :persistent_term.get(key, nil) do
        {prev_energy, prev_time} when now > prev_time ->
          delta_uj = energy_delta(energy, prev_energy, max_energy)
          delta_s = (now - prev_time) / 1000.0
          watts = delta_uj / 1_000_000.0 / delta_s

          :persistent_term.put(key, {energy, now})

          if watts > 0, do: watts, else: nil

        _ ->
          :persistent_term.put(key, {energy, now})
          nil
      end
    else
      _ -> nil
    end
  end

  defp energy_delta(energy, prev_energy, _max_energy) when energy >= prev_energy do
    energy - prev_energy
  end

  defp energy_delta(energy, prev_energy, max_energy) when is_integer(max_energy) and max_energy > 0 do
    max_energy - prev_energy + energy
  end

  defp energy_delta(energy, prev_energy, _), do: energy - prev_energy

  defp read_energy_uj(domain) do
    path = Path.join(domain, "energy_uj")

    case File.read(path) do
      {:ok, content} ->
        case Integer.parse(String.trim(content)) do
          {energy, _} when energy >= 0 -> {:ok, energy}
          _ -> :error
        end

      {:error, :eacces} ->
        log_rapl_permission_denied(path)
        :error

      _ ->
        :error
    end
  end

  defp log_rapl_permission_denied(path) do
    unless :persistent_term.get({:exkl, :rapl_eacces_logged}, false) do
      :persistent_term.put({:exkl, :rapl_eacces_logged}, true)

      Logger.warning(
        "Cannot read RAPL energy from #{path} (permission denied). " <>
          "Re-run install.sh or: sudo chmod a+r #{path}"
      )
    end
  end

  defp read_max_energy_uj(domain) do
    case File.read(Path.join(domain, "max_energy_range_uj")) do
      {:ok, content} ->
        case Integer.parse(String.trim(content)) do
          {max, _} when max > 0 -> max
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp store_rapl_watts(nil), do: nil

  defp store_rapl_watts(watts) when is_float(watts) do
    :persistent_term.put(@rapl_watts_key, watts)
    watts
  end

  defp last_rapl_watts do
    case :persistent_term.get(@rapl_watts_key, nil) do
      watts when is_float(watts) and watts > 0 -> watts
      _ -> nil
    end
  end

  defp hwmon_temp_celsius do
    read_hwmon_temp(hwmon_path("k10temp")) || read_hwmon_temp(hwmon_path("zenpower"))
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

  defp or_else(nil, fun) when is_function(fun, 0), do: fun.()
  defp or_else(value, _), do: value
end
