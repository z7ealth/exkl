defmodule Exkl.Desktop do
  @behaviour :wx_object

  @title "EXKL"
  @aspect_w 16
  @aspect_h 9
  @frame_margin 96
  @default_min_width 1280
  @tray_popup_size {460, 580}
  @tray_popup_url "http://localhost:4500/tray"

  @menu_about 1
  @menu_exit 2

  require Logger

  alias Exkl.Desktop.API

  def start_link() do
    :wx_object.start_link(__MODULE__, [], [])
  end

  def init(_args \\ []) do
    wx = :wx.new()
    :wx.debug(:verbose)

    min_size = min_window_size()
    frame = :wxFrame.new(wx, -1, @title, size: min_size)
    icon = load_icon("icon-dark.png") || :wxIcon.new()
    tray_icon = load_icon("icon-light.png") || icon

    task_bar = build_taskbar(tray_icon)
    web_view = build_webview(frame)
    tray_popup = build_tray_popup(wx)

    :wxWindow.setName(frame, "exkl")
    :wxWindow.setName(web_view, "exkl")
    :wxTopLevelWindow.setIcons(frame, :wxIconBundle.new(icon))
    :wxFrame.setIcon(frame, icon)
    :wxFrame.connect(frame, :close_window)
    :wxTaskBarIcon.connect(task_bar, :taskbar_left_up)
    :wxTaskBarIcon.connect(task_bar, :taskbar_left_dclick)
    :wxTaskBarIcon.connect(task_bar, :command_menu_selected)
    :wxFrame.connect(tray_popup.frame, :close_window)
    :wxFrame.setMinSize(frame, min_size)
    :wxFrame.hide(tray_popup.frame)

    API.register(self())

    state = %{
      frame: frame,
      task_bar: task_bar,
      web_view: web_view,
      tray_popup: tray_popup
    }

    {frame, state}
  end

  def handle_event({:wx, _, _, obj, {:wxClose, :close_window}}, %{tray_popup: %{frame: popup}} = state) do
    if obj == popup do
      hide_tray_popup(state)
    else
      :wxFrame.hide(state.frame)
    end

    {:noreply, state}
  end

  def handle_event({:wx, _, _, _, {:wxTaskBarIcon, type}}, state)
      when type in [:taskbar_left_up, :taskbar_left_dclick] do
    toggle_tray_popup(state)
    {:noreply, state}
  end

  def handle_event({:wx, @menu_about, _, _, {:wxCommand, :command_menu_selected, _, _, _}}, state) do
    Exkl.Desktop.About.show(state.frame)
    {:noreply, state}
  end

  def handle_event({:wx, @menu_exit, _, _, {:wxCommand, :command_menu_selected, _, _, _}}, state) do
    Logger.info("Closing EXKL window.")
    {:stop, :normal, state}
  end

  def handle_event(_event, state) do
    {:noreply, state}
  end

  def handle_info(:show_main_window, state) do
    show_frame(state.frame)
    hide_tray_popup(state)
    {:noreply, state}
  end

  def handle_info(:hide_tray_popup, state) do
    hide_tray_popup(state)
    {:noreply, state}
  end

  def handle_info(:show_tray_popup, state) do
    show_tray_popup(state)
    {:noreply, state}
  end

  def handle_info(:toggle_tray_popup, state) do
    toggle_tray_popup(state)
    {:noreply, state}
  end

  def handle_info(:exit_app, state) do
    Logger.info("Closing EXKL window.")
    {:stop, :normal, state}
  end

  defp build_webview(frame), do: :wxWebView.new(frame, 0, url: "http://localhost:4500")

  defp build_taskbar(icon) do
    task_bar = :wxTaskBarIcon.new(createPopupMenu: &build_menu/0)
    :wxTaskBarIcon.setIcon(task_bar, icon)
    task_bar
  end

  defp build_menu() do
    menu = :wxMenu.new()
    :wxMenu.append(menu, :wxMenuItem.new(id: @menu_about, text: "About"))
    :wxMenu.appendSeparator(menu)
    :wxMenu.append(menu, :wxMenuItem.new(id: @menu_exit, text: "Exit"))
    menu
  end

  defp build_tray_popup(wx) do
    {width, height} = @tray_popup_size
    frame = :wxFrame.new(wx, -1, "", size: {width, height}, style: tray_popup_style())
    web_view = :wxWebView.new(frame, 0, url: @tray_popup_url)

    sizer = :wxBoxSizer.new(8)
    :wxSizer.add(sizer, web_view, tray_expand())
    :wxFrame.setSizer(frame, sizer)
    :wxFrame.layout(frame)

    %{frame: frame, web_view: web_view}
  end

  defp tray_expand do
    :wxSizerFlags.new()
    |> :wxSizerFlags.expand()
    |> :wxSizerFlags.proportion(1)
  end

  defp tray_popup_style do
    # wxFRAME_TOOL_WINDOW | wxSTAY_ON_TOP | wxBORDER_NONE | wxFRAME_NO_TASKBAR
    8_388_608 + 32_768 + 33_554_432 + 524_288
  end

  defp toggle_tray_popup(%{tray_popup: %{frame: frame}} = state) do
    if :wxWindow.isShown(frame) do
      hide_tray_popup(state)
    else
      show_tray_popup(state)
    end
  end

  defp show_tray_popup(%{tray_popup: %{frame: frame, web_view: web_view}} = _state) do
    position_tray_popup(frame)
    :wxFrame.show(frame)
    :wxFrame.raise(frame)
    :wxWindow.setFocus(web_view)
    :ok
  end

  defp hide_tray_popup(%{tray_popup: %{frame: frame}} = _state) do
    if :wxWindow.isShown(frame), do: :wxFrame.hide(frame)
    :ok
  end

  defp position_tray_popup(frame) do
    display = :wxDisplay.new()
    {origin_x, origin_y, width, height} = :wxDisplay.getClientArea(display)
    :wxDisplay.destroy(display)

    {popup_w, popup_h} = @tray_popup_size
    margin = 16

    :wxWindow.move(
      frame,
      {origin_x + width - popup_w - margin, origin_y + height - popup_h - margin}
    )
  end

  def terminate(_reason, state) do
    destroy_wx(state)
    :ok
  end

  defp destroy_wx(state) do
    :wxWindow.destroy(state.web_view)
    :wxWindow.destroy(state.tray_popup.web_view)
    :wxTaskBarIcon.removeIcon(state.task_bar)
    :wxTaskBarIcon.destroy(state.task_bar)
    :wxFrame.destroy(state.tray_popup.frame)
    :wxFrame.destroy(state.frame)
    :wx.destroy()
  rescue
    _ -> :ok
  catch
    :exit, _ -> :ok
  end

  defp load_icon(name) do
    path = priv_icon(name)

    if File.exists?(path) do
      :wxIcon.new(path)
    else
      Logger.warning("Icon not found: #{path}")
      nil
    end
  end

  defp priv_icon(name) do
    Path.join(:code.priv_dir(:exkl), "static/images/icon/#{name}")
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
