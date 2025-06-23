defmodule Exkl.MainWindow do
  @behaviour :wx_object

  @title "EXKL"
  @size {600, 600}

  def start_link() do
    :wx_object.start_link(__MODULE__, [], [])
  end

  def init(_args \\ []) do
    wx = :wx.new()
    frame = :wxFrame.new(wx, -1, @title, size: @size)

    task_bar = :wxTaskBarIcon.new()
    :wxTaskBarIcon.setIcon(task_bar, build_icon())

    :wxFrame.show(frame)
    :wxFrame.maximize(frame)

    state = %{frame: frame}
    {frame, state}
  end

  def handle_event({:wx, _, _, _, {listener, action}}, state) do
    dbg(listener)
    dbg(action)
    {:noreply, state}
  end

  defp build_icon do
    icon_path = Path.join(:code.priv_dir(:exkl), "static/images/deepcool.bmp")
    dbg(icon_path)
    :wxIcon.new(icon_path)
  end
end
