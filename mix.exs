defmodule Tap.Mixfile do
  use Mix.Project

  def project do
    [
      app: :tap,
      description: "Elixir tracing",
      package: package(),
      version: "0.1.5",
      elixir: "~> 1.2",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
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
        "Changelog" => "https://github.com/eproxus/tap/blob/master/CHANGELOG.md",
      },
    ]
  end

  def application do
    [applications: [:runtime_tools, :recon]]
  end

  defp deps do
    [
      {:recon, "~> 2.3"},

      # Documentation
      {:ex_doc,  "~> 0.9", only: :dev},
      {:earmark, "~> 0.1", only: :dev},
    ]
  end
end
