defmodule Exkl.SensorsNif do
  @on_load :init
  @nif_path Path.join(:code.priv_dir(:exkl), "/nifs/sensors_nif")
  @nifs [hello: 0]

  def init, do: :erlang.load_nif(@nif_path, 0)

  def hello(), do: load_error(:sensors_nif_library_not_loaded)

  defp load_error(error) do
    error
    |> :erlang.nif_error()
    |> exit()
  end
end
