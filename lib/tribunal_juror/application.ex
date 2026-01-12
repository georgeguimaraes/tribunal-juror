defmodule TribunalJuror.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TribunalJurorWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:tribunal_juror, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TribunalJuror.PubSub},
      # Start a worker by calling: TribunalJuror.Worker.start_link(arg)
      # {TribunalJuror.Worker, arg},
      # Start to serve requests, typically the last entry
      TribunalJurorWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TribunalJuror.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TribunalJurorWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
