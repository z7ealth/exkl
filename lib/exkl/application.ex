defmodule Exkl.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  alias Exkl.Systray

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: Exkl.Worker.start_link(arg)
      # {Exkl.Worker, arg}
    ]

    Systray.start_link()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Exkl.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
