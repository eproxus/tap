defmodule Tap.Mixfile do
  use Mix.Project

  def project do
    [
      app: :tap,
      description: "Elixir tracing",
      maintainers: [
        "Adam Lindberg <hello@alind.io>"
      ],
      licenses: ["Apache License 2.0"],
      version: "0.1.0",
      elixir: "~> 1.0",
      source_url: "https://github.com/eproxus/tap",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps,
      docs: [extras: ["README.md"]]
    ]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:recon]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [
      {:recon, github: "ferd/recon", branch: "master"},
    ]
  end
end
