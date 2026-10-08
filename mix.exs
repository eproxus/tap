defmodule Tap.MixProject do
  use Mix.Project

  def project do
    [
      app: :tap,
      description: "Elixir tracing",
      package: package(),
      version: "0.1.5",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [extras: ["README.md"]]
    ]
  end

  def package do
    [
      maintainers: [
        "Adam Lindberg <hello@alind.io>"
      ],
      licenses: ["Apache-2.0"],
      source_url: "https://github.com/eproxus/tap",
      links: %{
        "GitHub" => "https://github.com/eproxus/tap",
        "Changelog" => "https://github.com/eproxus/tap/blob/master/CHANGELOG.md"
      }
    ]
  end

  def application do
    [extra_applications: [:runtime_tools]]
  end

  defp deps do
    [
      {:recon, "~> 2.5"},

      # Documentation
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end
end
