defmodule Exkl.Desktop do
  @behaviour :wx_object

  @title "EXKL"
  @size {1000, 750}
  @icon_path Path.join(:code.priv_dir(:exkl), "static/images/exkl_logo.png")

  require Logger

  def start_link() do
    :wx_object.start_link(__MODULE__, [], [])
  end

  def init(_args \\ []) do
    wx = :wx.new()
    :wx.debug(:verbose)

    frame = :wxFrame.new(wx, -1, @title, size: @size)

    task_bar = build_taskbar()
    web_view = build_webview(frame)

    :wxFrame.setIcon(frame, build_icon())
    :wxFrame.connect(frame, :close_window)
    :wxTaskBarIcon.connect(task_bar, :command_menu_selected)
    :wxFrame.setMinSize(frame, @size)
    :wxFrame.setMaxSize(frame, @size)

    state = %{frame: frame, task_bar: task_bar, web_view: web_view}
    {frame, state}
  end

  def handle_event({:wx, _, _, _, {:wxClose, :close_window}}, %{frame: frame} = state) do
    :wxFrame.hide(frame)
    {:noreply, state}
  end

  def handle_event({:wx, 1, _, _, {:wxCommand, :command_menu_selected, _, _, _}}, state) do
    # Show the main frame
    :wxFrame.show(state.frame)
    {:noreply, state}
  end

  def handle_event({:wx, 2, _, _, {:wxCommand, :command_menu_selected, _, _, _}}, state) do
    Logger.info("Shutting down EXKL.")

    {:stop, :normal, state}
  end

  defp build_webview(frame), do: :wxWebView.new(frame, 0, url: "http://localhost:4000")

  defp build_taskbar do
    task_bar = :wxTaskBarIcon.new(createPopupMenu: fn -> build_menu() end)
    :wxTaskBarIcon.setIcon(task_bar, build_icon())

    task_bar
  end

  def terminate(:normal, state) do
    :wxWindow.destroy(state.web_view)
    :wxTaskBarIcon.destroy(state.task_bar)
    :wxFrame.close(state.frame)
    :wxFrame.destroy(state.frame)

    :wx.destroy()

    :ok
  end

  defp build_menu() do
    menu = :wxMenu.new()
    :wxMenu.append(menu, build_show_window_option())
    :wxMenu.append(menu, build_exit_option())

    menu
  end

  defp build_show_window_option() do
    item = :wxMenuItem.new(id: 1, text: "Show window")

    item
  end

  defp build_exit_option() do
    item = :wxMenuItem.new(id: 2, text: "Exit")

    item
  end

  defp build_icon, do: :wxIcon.new(@icon_path)
end
