defmodule Exkl.Desktop.About do
  @moduledoc false

  @icon_path Path.join(:code.priv_dir(:exkl), "static/images/exkl_logo.png")
  @license_url "https://github.com/z7ealth/exkl/blob/main/LICENSE"

  @wx_horizontal 4
  @wx_vertical 8
  @wx_all 240
  @wx_id_ok 5100
  @wx_id_license 5101

  @program_name "AK Digital for Linux"
  @description "Unofficial Linux version of DeepCool's AK Digital Software."
  @copyright "© z7ealth"

  @spec show(parent :: term()) :: :ok
  def show(parent) do
    dialog = build_dialog(parent)

    :wxDialog.centreOnParent(dialog)
    :wxDialog.showModal(dialog)
    :wxDialog.destroy(dialog)

    :ok
  end

  defp build_dialog(parent) do
    dialog = :wxDialog.new(parent, -1, "About")
    :wxDialog.setIcon(dialog, :wxIcon.new(@icon_path))

    panel = :wxPanel.new(dialog)
    logo = scaled_logo_bitmap()
    name = :wxStaticText.new(panel, -1, @program_name)
    version = :wxStaticText.new(panel, -1, "Version #{version()}")
    description = :wxStaticText.new(panel, -1, @description)
    copyright = :wxStaticText.new(panel, -1, @copyright)

    :wxStaticText.wrap(description, 360)

    header = :wxBoxSizer.new(@wx_horizontal)
    name_col = :wxBoxSizer.new(@wx_vertical)

    :wxSizer.add(header, :wxStaticBitmap.new(panel, -1, logo), padding(8))
    :wxSizer.add(name_col, name, [])
    :wxSizer.add(name_col, version, [])
    :wxSizer.add(header, name_col, padding(8))

    content = :wxBoxSizer.new(@wx_vertical)
    :wxSizer.add(content, header, [])
    :wxSizer.add(content, description, padding(12))
    :wxSizer.add(content, copyright, padding(12))
    :wxPanel.setSizer(panel, content)

    license_btn = :wxButton.new(dialog, @wx_id_license, label: "License")
    ok_btn = :wxButton.new(dialog, @wx_id_ok)

    :wxButton.connect(
      license_btn,
      :command_button_clicked,
      callback: fn _, _ -> open_license_in_browser() end
    )

    buttons = :wxBoxSizer.new(@wx_horizontal)
    :wxSizer.add(buttons, license_btn, padding(4))
    :wxSizer.addStretchSpacer(buttons)
    :wxSizer.add(buttons, ok_btn, padding(4))

    outer = :wxBoxSizer.new(@wx_vertical)
    :wxSizer.add(outer, panel, expand())
    :wxSizer.add(outer, buttons, padding(8))
    :wxDialog.setSizer(dialog, outer)

    fit_and_lock_size(dialog)

    dialog
  end

  @doc false
  @spec open_license_in_browser() :: :ok
  def open_license_in_browser do
    :wx_misc.launchDefaultBrowser(@license_url)
    :ok
  end

  defp fit_and_lock_size(window, opts \\ []) do
    min_width = Keyword.get(opts, :min_width, 400)
    min_height = Keyword.get(opts, :min_height, 240)

    :wxWindow.fit(window)
    {width, height} = :wxWindow.getSize(window)
    width = max(width, min_width)
    height = max(height, min_height)
    size = {width, height}
    :wxWindow.setSize(window, size)
    :wxWindow.setMinSize(window, size)
    :wxWindow.setMaxSize(window, size)
  end

  defp scaled_logo_bitmap do
    @icon_path
    |> :wxBitmap.new()
    |> :wxBitmap.convertToImage()
    |> :wxImage.scale(50, 50)
    |> :wxBitmap.new()
  end

  defp version, do: Application.spec(:exkl, :vsn) |> to_string()

  defp padding(border) do
    :wxSizerFlags.new()
    |> :wxSizerFlags.border(@wx_all, border)
  end

  defp expand do
    :wxSizerFlags.new()
    |> :wxSizerFlags.expand()
    |> :wxSizerFlags.border(@wx_all, 8)
  end
end
