defmodule Exkl.Desktop do
  @behaviour :wx_object

  @title "EXKL"
  @size {800, 800}
  @icon_path Path.join(:code.priv_dir(:exkl), "static/images/exkl_logo.png")

  def start_link() do
    :wx_object.start_link(__MODULE__, [], [])
  end

  def init(_args \\ []) do
    wx = :wx.new()
    frame = :wxFrame.new(wx, -1, @title, size: @size)

    task_bar = build_taskbar()
    web_view = build_webview(frame)

    :wxFrame.setIcon(frame, build_icon())
    :wxFrame.show(frame)
    #:wxFrame.maximize(frame)

    state = %{task_bar: task_bar, web_view: web_view}
    {frame, state}
  end

  def handle_event({:wx, _, _, _, {listener, action}}, state) do
    dbg(listener)
    dbg(action)
    {:noreply, state}
  end

  defp build_webview(frame) do
    :wxWebView.new(frame, -1, url: "http://localhost:4000")
  end

  defp build_taskbar do
    task_bar = :wxTaskBarIcon.new()

    :wxTaskBarIcon.setIcon(task_bar, build_icon())
  end

  defp build_icon, do: :wxIcon.new(@icon_path)
end
