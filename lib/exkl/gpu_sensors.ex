defmodule Exkl.GpuSensors do
  @moduledoc false

  @spec utilization() :: float() | nil
  def utilization do
    amdgpu_util() || nvidia_util()
  end

  defp amdgpu_util do
    "/sys/class/drm/card*/device/gpu_busy_percent"
    |> Path.wildcard()
    |> Enum.find_value(&read_sysfs_percent/1)
  end

  defp nvidia_util do
    case System.find_executable("nvidia-smi") do
      nil ->
        nil

      path ->
        case System.cmd(path, [
               "--query-gpu=utilization.gpu",
               "--format=csv,noheader,nounits"
             ],
             stderr_to_stdout: true
           ) do
          {output, 0} -> parse_percent(output)
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
