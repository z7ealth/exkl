defmodule Exkl.GpuSensors do
  @moduledoc false

  alias Exkl.SensorsNif

  # Prefer nvidia-smi first so hybrid systems (iGPU + NVIDIA dGPU) report the
  # discrete card, not integrated amdgpu/i915 sysfs readings.

  @spec temp_celsius() :: float() | nil
  def temp_celsius do
    nvidia_temp() || sensors_temp()
  end

  @spec utilization() :: float() | nil
  def utilization do
    nvidia_util() || amdgpu_util() || intel_util()
  end

  @spec frequency_mhz() :: float() | nil
  def frequency_mhz do
    nvidia_freq() || amdgpu_freq() || intel_freq()
  end

  @spec power_watts() :: float() | nil
  def power_watts do
    nvidia_power() || amdgpu_power() || intel_power() || sensors_power()
  end

  defp sensors_temp do
    case SensorsNif.get_gpu_temp_celsius() do
      temp when temp >= 0 -> temp
      _ -> nil
    end
  end

  defp amdgpu_util do
    "/sys/class/drm/card*/device/gpu_busy_percent"
    |> Path.wildcard()
    |> Enum.find_value(&read_sysfs_percent/1)
  end

  defp amdgpu_freq do
    drm_device_paths("amdgpu")
    |> Enum.find_value(&read_hwmon_freq/1)
  end

  defp amdgpu_power do
    drm_device_paths("amdgpu")
    |> Enum.find_value(&read_hwmon_power/1)
  end

  defp intel_power do
    intel_device_paths()
    |> Enum.find_value(&read_hwmon_power/1)
  end

  defp sensors_power do
    case SensorsNif.get_gpu_power_watts() do
      power when power > 0 -> power
      _ -> nil
    end
  end

  defp read_hwmon_power(device_path) do
    ["power1_average", "power1_input"]
    |> Enum.find_value(fn file ->
      device_path
      |> Path.join("hwmon/hwmon*/#{file}")
      |> Path.wildcard()
      |> Enum.find_value(&read_power_uw/1)
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

  defp drm_device_paths(driver) do
    "/sys/class/drm/card*/device/uevent"
    |> Path.wildcard()
    |> Enum.filter(fn path ->
      case File.read(path) do
        {:ok, content} -> String.contains?(content, "DRIVER=#{driver}")
        _ -> false
      end
    end)
    |> Enum.map(&Path.dirname/1)
  end

  defp intel_util do
    intel_sysfs_util() || intel_gpu_top_util()
  end

  defp intel_sysfs_util do
    intel_device_paths()
    |> Enum.find_value(&read_intel_card_busy/1)
  end

  defp intel_freq do
    intel_device_paths()
    |> Enum.find_value(&read_intel_card_freq/1)
  end

  defp read_intel_card_freq(device_path) do
    [
      Path.join(device_path, "gt/gt0/rps/cur_freq"),
      Path.join(device_path, "gt/gt1/rps/cur_freq")
    ]
    |> Enum.find_value(fn path ->
      case File.read(path) do
        {:ok, content} -> parse_freq_mhz(content)
        _ -> nil
      end
    end) || read_hwmon_freq(device_path)
  end

  defp read_hwmon_freq(device_path) do
    device_path
    |> Path.join("hwmon/hwmon*/freq1_input")
    |> Path.wildcard()
    |> Enum.find_value(&read_sysfs_hz/1)
  end

  defp intel_device_paths do
    drm_device_paths("i915") ++ drm_device_paths("xe")
  end

  defp read_intel_card_busy(device_path) do
    busy_paths(device_path)
    |> Enum.find_value(&read_sysfs_percent/1)
  end

  defp busy_paths(device_path) do
    gt_glob = Path.join(device_path, "gt/gt*/busy_percent")

    [gt_glob | legacy_busy_paths(device_path)]
    |> Enum.flat_map(&Path.wildcard/1)
  end

  defp legacy_busy_paths(device_path) do
    for gt <- Path.wildcard(Path.join(device_path, "gt/gt*")),
        engine <- Path.wildcard(Path.join(gt, "engine/*/busy_percent")) do
      engine
    end
  end

  defp intel_gpu_top_util do
    case System.find_executable("intel_gpu_top") do
      nil ->
        nil

      path ->
        case System.cmd(path, ["-o", "-", "-s", "400"], stderr_to_stdout: true) do
          {output, _} -> parse_intel_gpu_top(output)
        end
    end
  end

  defp parse_intel_gpu_top(output) do
    output
    |> String.split("\n", trim: true)
    |> Enum.find_value(fn line ->
      case Regex.run(~r/^\d+\.\d+,(\d+(?:\.\d+)?),/, line) do
        [_, util] ->
          case Float.parse(util) do
            {value, _} when value >= 0 and value <= 100 -> value
            _ -> nil
          end

        _ ->
          nil
      end
    end)
  end

  defp nvidia_temp do
    nvidia_query("temperature.gpu", &parse_percent/1)
  end

  defp nvidia_freq do
    nvidia_query("clocks.current.graphics", &parse_freq_mhz/1)
  end

  defp nvidia_power do
    nvidia_query("power.draw", &parse_power_watts/1)
  end

  defp nvidia_util do
    nvidia_query("utilization.gpu", &parse_percent/1)
  end

  defp nvidia_query(field, parser) do
    case System.find_executable("nvidia-smi") do
      nil ->
        nil

      path ->
        case System.cmd(path, ["--query-gpu=#{field}", "--format=csv,noheader,nounits"],
               stderr_to_stdout: true
             ) do
          {output, 0} -> parser.(output)
          _ -> nil
        end
    end
  end

  defp read_sysfs_percent(path) do
    case File.read(path) do
      {:ok, content} -> parse_percent(content)
      _ -> nil
    end
  end

  defp read_sysfs_hz(path) do
    case File.read(path) do
      {:ok, content} ->
        case Integer.parse(String.trim(content)) do
          {hz, _} when hz > 0 -> hz / 1_000_000.0
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp parse_freq_mhz(content) do
    content
    |> String.trim()
    |> String.split("\n", parts: 2)
    |> List.first("")
    |> String.trim()
    |> case do
      "" ->
        nil

      line ->
        case Float.parse(line) do
          {value, _} when value > 0 -> value
          _ -> nil
        end
    end
  end

  defp parse_power_watts(content) do
    content
    |> String.trim()
    |> String.split("\n", parts: 2)
    |> List.first("")
    |> String.trim()
    |> case do
      "" ->
        nil

      line ->
        case Float.parse(line) do
          {value, _} when value > 0 -> value
          _ -> nil
        end
    end
  end

  defp parse_percent(content) do
    content
    |> String.trim()
    |> String.split("\n", parts: 2)
    |> List.first("")
    |> String.trim()
    |> case do
      "" ->
        nil

      line ->
        case Float.parse(line) do
          {value, _} when value >= 0 and value <= 100 -> value
          _ -> nil
        end
    end
  end
end
