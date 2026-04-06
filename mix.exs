defmodule Kontor.MixProject do
  use Mix.Project

  def project do
    [
      app: :kontor,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      releases: releases(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ]
    ]
  end

  def application do
    [
      mod: {Kontor.Application, []},
      extra_applications: [:logger, :runtime_tools, :crypto]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Phoenix
      {:phoenix, "~> 1.7"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_live_dashboard, "~> 0.8"},
      {:plug_cowboy, "~> 2.7"},
      {:websock_adapter, "~> 0.5"},

      # Ecto / PostgreSQL
      {:ecto_sql, "~> 3.12"},
      {:postgrex, ">= 0.0.0"},
      {:pgvector, "~> 0.3"},

      # Auth / Security
      {:cloak_ecto, "~> 1.3"},
      {:cloak, "~> 1.1"},
      {:guardian, "~> 2.3"},

      # HTTP
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},

      # Background jobs
      {:oban, "~> 2.19"},

      # AI / Embeddings (only in prod; dev/test use mock fallback in embeddings.ex)
      {:bumblebee, "~> 0.6", only: :prod},
      {:nx, "~> 0.9", only: :prod},
      {:exla, "~> 0.9", only: :prod},

      # YAML frontmatter parsing for skills
      {:yaml_elixir, "~> 2.9"},
      {:ymlr, "~> 5.1"},

      # OAuth
      {:ueberauth, "~> 0.10"},
      {:ueberauth_google, "~> 0.10"},

      # Telemetry
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},

      # Zero-install distribution
      {:burrito, "~> 1.0"},

      # Dev/Test
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:ex_machina, "~> 2.7", only: [:dev, :test]},
      {:floki, ">= 0.30.0", only: :test},
      {:mox, "~> 1.2", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}
    ]
  end

  defp releases do
    [
      kontor: [
        steps: [:assemble, &Burrito.wrap/1],
        burrito: [
          targets: [
            macos_arm: [os: :darwin, cpu: :aarch64],
            macos_x86: [os: :darwin, cpu: :x86_64],
            linux_x86: [os: :linux, cpu: :x86_64]
          ]
        ]
      ]
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
