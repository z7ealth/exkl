defmodule Exkl.GUI do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  ## Callbacks

  @impl true
  def init(_args) do

    desktop = Exkl.Desktop.start_link()
    {:ok, desktop}
  end
end
