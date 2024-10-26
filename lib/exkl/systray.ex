defmodule Exkl.Systray do
  @behaviour :wx_object

  @wxID_ANY -1
  @wxID_ABOUT 5014

  def start_link do
    :wx_object.start_link(__MODULE__, [], [])
  end

  def init(_args) do
    wx = :wx.new()

    frame = :wxFrame.new(wx, @wxID_ANY, ~c"EXKL")

    systray = :wxTaskBarIcon.new(createPopupMenu: &create_menu/0)
    :wxTaskBarIcon.setIcon(systray, get_icon())
    :wxTaskBarIcon.connect(systray, :taskbar_left_dclick)
    :wxTaskBarIcon.connect(systray, :command_menu_selected)

    {frame, []}
  end

  def handle_event(event, state) do
    dbg(event)

    {:noreply, state}
  end

  defp create_menu do
    menu = :wxMenu.new()
    :wxMenu.append(menu, @wxID_ABOUT, ~c"About", [])

    menu
  end

  defp get_icon do
    bitmap =
      Path.join(:code.priv_dir(:exkl), "/images/deepcool.png")
      |> :wxImage.new()
      |> :wxBitmap.new()

    icon = :wxIcon.new()
    :wxIcon.copyFromBitmap(icon, bitmap)
    module = :wx.getObjectType(bitmap)
    module.destroy(bitmap)

    icon
  end
end
