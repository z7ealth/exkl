defmodule Exkl.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  # alias Exkl.Desktop

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ExklWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:exkl, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Exkl.PubSub},
      # Start a worker by calling: Exkl.Worker.start_link(arg)
      # {Exkl.Worker, arg},
      # Start to serve requests, typically the last entry
      ExklWeb.Endpoint,
      {Exkl.Core, %{mode: "temp_c"}},
      Exkl.Display,
      Exkl.Gui
    ]

    :observer.start()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Exkl.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ExklWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
