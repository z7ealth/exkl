defmodule Exkl.Core do
  use GenServer

  require Logger

  alias Exkl.SensorsNif

  ## Public API

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def get_temp do
    GenServer.call(__MODULE__, :get_cpu_temp)
  end

  def change_mode(mode) do
    GenServer.cast(__MODULE__, {:change_mode, %{mode: mode}})
  end

  ## GenServer Callbacks

  @impl true
  def init(initial_state) do
    {:ok, initial_state}
  end

  @impl true
  def handle_call(:get_cpu_temp, _from, %{mode: "temp_c"} = state) do
    {:reply, SensorsNif.get_cpu_temp_celcius(), state}
  end

  @impl true
  def handle_call(:get_cpu_temp, _from, %{mode: "temp_f"} = state) do
    {:reply, SensorsNif.get_cpu_temp_fahrenheit(), state}
  end

  @impl true
  def handle_cast({:change_mode, new_state}, _state) do
    {:noreply, new_state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.error("Display - Unhandled message: #{msg}")
    {:noreply, state}
  end
end
