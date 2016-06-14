defmodule Tap.Mixfile do
  use Mix.Project

  def project do
    [
      app: :tap,
      description: "Elixir tracing",
      package: package,
      version: "0.1.0",
      elixir: "~> 1.0",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps,
      docs: [extras: ["README.md"]]
    ]
  end

  def package do
    [
      maintainers: [
        "Adam Lindberg <hello@alind.io>"
      ],
      licenses: ["Apache 2.0"],
      source_url: "https://github.com/eproxus/tap",
      links: %{
        "GitHub" => "https://github.com/eproxus/tap",
        "Documentation" => "http://hexdocs.pm/tap",
      },
    ]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:runtime_tools, :recon]]
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

      # Documentation
      {:ex_doc, "~> 0.9", only: :dev},
      {:earmark, "~> 0.1", only: :dev},
    ]
  end
end
