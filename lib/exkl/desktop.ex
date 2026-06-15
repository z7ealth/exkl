defmodule Exkl.Desktop do
  @behaviour :wx_object

  @title "EXKL"
  @icon_path Path.join(:code.priv_dir(:exkl), "static/images/exkl_logo.png")
  @aspect_w 16
  @aspect_h 9
  @frame_margin 96
  @default_min_width 1280

  require Logger

  def start_link() do
    :wx_object.start_link(__MODULE__, [], [])
  end

  def init(_args \\ []) do
    wx = :wx.new()
    :wx.debug(:verbose)

    min_size = min_window_size()
    frame = :wxFrame.new(wx, -1, @title, size: min_size)
    icon = build_icon()

    task_bar = build_taskbar(icon)
    web_view = build_webview(frame)

    :wxWindow.setName(frame, "exkl")
    :wxWindow.setName(web_view, "exkl")
    :wxTopLevelWindow.setIcons(frame, :wxIconBundle.new(icon))
    :wxFrame.setIcon(frame, icon)
    :wxFrame.connect(frame, :close_window)
    :wxTaskBarIcon.connect(task_bar, :command_menu_selected)
    :wxFrame.setMinSize(frame, min_size)

    state = %{frame: frame, task_bar: task_bar, web_view: web_view}
    {frame, state}
  end

  def handle_event({:wx, _, _, _, {:wxClose, :close_window}}, %{frame: frame} = state) do
    :wxFrame.hide(frame)
    {:noreply, state}
  end

  def handle_event({:wx, 1, _, _, {:wxCommand, :command_menu_selected, _, _, _}}, state) do
    show_frame(state.frame)
    {:noreply, state}
  end

  def handle_event({:wx, 3, _, _, {:wxCommand, :command_menu_selected, _, _, _}}, state) do
    Exkl.Desktop.About.show(state.frame)
    {:noreply, state}
  end

  def handle_event({:wx, 2, _, _, {:wxCommand, :command_menu_selected, _, _, _}}, state) do
    Logger.info("Shutting down EXKL.")

    {:stop, :normal, state}
  end

  defp build_webview(frame), do: :wxWebView.new(frame, 0, url: "http://localhost:4500")

  defp build_taskbar(icon) do
    task_bar = :wxTaskBarIcon.new(createPopupMenu: fn -> build_menu() end)
    :wxTaskBarIcon.setIcon(task_bar, icon)

    task_bar
  end

  def terminate(_reason, state) do
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
    :wxMenu.append(menu, build_about_option())
    :wxMenu.appendSeparator(menu)
    :wxMenu.append(menu, build_exit_option())

    menu
  end

  defp build_show_window_option() do
    item = :wxMenuItem.new(id: 1, text: "Show window")

    item
  end

  defp build_about_option() do
    item = :wxMenuItem.new(id: 3, text: "About")

    item
  end

  defp build_exit_option() do
    item = :wxMenuItem.new(id: 2, text: "Exit")

    item
  end

  defp build_icon do
    if File.exists?(@icon_path) do
      :wxIcon.new(@icon_path)
    else
      :wxIcon.new()
    end
  end

  defp show_frame(frame) do
    :wxFrame.show(frame)
    :wxFrame.maximize(frame)
    :wxFrame.raise(frame)
    :ok
  end

  defp min_window_size do
    display = :wxDisplay.new()
    {_x, _y, width, height} = :wxDisplay.getClientArea(display)
    :wxDisplay.destroy(display)

    available_w = max(width - @frame_margin, 640)
    available_h = max(height - @frame_margin, 360)

    target_w = min(@default_min_width, trunc(available_w * 0.85))
    target_h = aspect_height(target_w)

    {target_w, target_h} =
      if target_h > available_h do
        fitted_h = available_h
        {aspect_width(fitted_h), fitted_h}
      else
        {target_w, target_h}
      end

    {max(target_w, 640), max(target_h, 360)}
  end

  defp aspect_height(width), do: div(width * @aspect_h, @aspect_w)
  defp aspect_width(height), do: div(height * @aspect_w, @aspect_h)
end
