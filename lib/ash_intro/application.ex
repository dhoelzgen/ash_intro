defmodule AshIntro.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AshIntroWeb.Telemetry,
      AshIntro.Repo,
      {DNSCluster, query: Application.get_env(:ash_intro, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: AshIntro.PubSub},
      # Start a worker by calling: AshIntro.Worker.start_link(arg)
      # {AshIntro.Worker, arg},
      # Start to serve requests, typically the last entry
      AshIntroWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :ash_intro]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AshIntro.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AshIntroWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
