defmodule Exkl.Desktop.API do
  @moduledoc false

  @key {:exkl, :desktop}

  @spec register(pid()) :: :ok
  def register(pid) when is_pid(pid) do
    :persistent_term.put(@key, pid)
    :ok
  end

  @spec show_main_window() :: :ok
  def show_main_window do
    send_desktop(:show_main_window)
  end

  @spec show_tray_popup() :: :ok
  def show_tray_popup do
    send_desktop(:show_tray_popup)
  end

  @spec hide_tray_popup() :: :ok
  def hide_tray_popup do
    send_desktop(:hide_tray_popup)
  end

  @spec toggle_tray_popup() :: :ok
  def toggle_tray_popup do
    send_desktop(:toggle_tray_popup)
  end

  @spec exit_app() :: :ok
  def exit_app do
    send_desktop(:exit_app)
  end

  defp send_desktop(message) do
    case :persistent_term.get(@key, nil) do
      pid when is_pid(pid) -> send(pid, message)
      _ -> :ok
    end

    :ok
  end
end
