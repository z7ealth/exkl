defmodule Exkl.HidApiNif do
  @on_load :init
  @nif_path Path.join(:code.priv_dir(:exkl), "/nifs/hid_api_nif")
  @nifs [open: 2, close: 1]

  def init, do: :erlang.load_nif(@nif_path, 0)

  def open(_vendor_id, _product_id), do: load_error(:hid_nif_library_not_loaded)
  def close(_hid_handle), do: load_error(:hid_nif_library_not_loaded)

  defp load_error(error) do
    error
    |> :erlang.nif_error()
    |> exit()
  end
end
