defmodule Exkl.HardwareInfo do
  @moduledoc false

  @spec cpu_name() :: String.t()
  def cpu_name do
    case read_cpu_model() do
      nil -> "Unknown CPU"
      model -> simplify_cpu_name(model)
    end
  end

  @spec gpu_name() :: String.t()
  def gpu_name do
    case read_gpu_model() do
      nil -> "Unknown GPU"
      model -> model
    end
  end

  defp read_cpu_model do
    case File.read("/proc/cpuinfo") do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.find_value(fn line ->
          case Regex.run(~r/^model name\s*:\s*(.+)$/, line) do
            [_, model] -> String.trim(model)
            _ -> nil
          end
        end)

      _ ->
        nil
    end
  end

  defp simplify_cpu_name(name) do
    name
    |> String.replace(~r/\s+\d+-Core Processor$/, "")
    |> String.replace(~r/\s+Processor$/, "")
    |> String.replace_prefix("AMD ", "")
    |> String.replace_prefix("Intel(R) ", "Intel ")
    |> String.replace("(R)", "")
    |> String.trim()
  end

  defp read_gpu_model do
    with path when is_binary(path) <- System.find_executable("lspci"),
         {output, 0} <- System.cmd(path, [], stderr_to_stdout: true),
         line when is_binary(line) <- find_gpu_pci_line(output) do
      line
      |> pci_description()
      |> format_gpu_name()
    else
      _ -> nil
    end
  end

  defp find_gpu_pci_line(output) do
    lines =
      output
      |> String.split("\n")
      |> Enum.filter(fn line ->
        String.match?(
          line,
          ~r/(VGA compatible controller|3D controller|Display controller)/i
        )
      end)

    preferred =
      Enum.find(lines, &String.match?(&1, ~r/(NVIDIA|AMD\/ATI|Advanced Micro Devices|Arc)/i))

    preferred || Enum.find(lines, &String.match?(&1, ~r/Intel/i)) || List.first(lines)
  end

  defp pci_description(line) do
    case String.split(line, ": ", parts: 2) do
      [_, description] ->
        description
        |> String.replace(~r/\s*\(rev [^)]+\)$/, "")
        |> String.trim()

      _ ->
        nil
    end
  end

  defp format_gpu_name(nil), do: nil

  defp format_gpu_name(description) do
    case Regex.scan(~r/\[([^\]]+)\]/, description) do
      [] ->
        description
        |> String.split(":", parts: 2)
        |> List.last()
        |> polish_gpu_segment()

      matches ->
        matches
        |> List.last()
        |> case do
          [_full, captured] -> captured
          _ -> nil
        end
        |> polish_gpu_segment()
    end
  end

  defp polish_gpu_segment(nil), do: nil

  defp polish_gpu_segment(name) do
    name
    |> String.split(" / ")
    |> List.last()
    |> String.trim()
    |> normalize_gpu_segment()
  end

  defp normalize_gpu_segment(segment) do
    cond do
      String.match?(segment, ~r/^RX /i) ->
        "AMD " <> segment

      String.match?(segment, ~r/^\d{4}/) ->
        "AMD RX " <> segment

      String.match?(segment, ~r/^Radeon /i) ->
        segment
        |> String.replace(~r/^Radeon /i, "AMD ")
        |> String.replace("AMD RX RX", "AMD RX")

      String.match?(segment, ~r/^GeForce /i) ->
        "NVIDIA " <> segment

      String.match?(segment, ~r/^Arc /i) ->
        "Intel " <> segment

      String.match?(segment, ~r/^(UHD |Iris |HD Graphics|Xe )/i) ->
        "Intel " <> segment

      String.match?(segment, ~r/Graphics/i) ->
        "Intel " <> String.trim_leading(segment, "Intel ")

      true ->
        segment
    end
  end
end
