defmodule Tap.MixProject do
  use Mix.Project

  @version "0.3.0"
  @source_url "https://github.com/eproxus/tap"

  def project do
    [
      app: :tap,
      description: "Elixir tracing",
      package: package(),
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [
        main: "readme",
        extras: ["README.md", "CHANGELOG.md"],
        source_url: @source_url,
        source_ref: "v#{@version}"
      ]
    ]
  end

  def package do
    [
      maintainers: [
        "Adam Lindberg <hello@alind.io>"
      ],
      licenses: ["MIT"],
      source_url: @source_url,
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      }
    ]
  end

  def application do
    [extra_applications: [:runtime_tools]]
  end

  defp deps do
    [
      {:recon, "~> 2.5"},

      # Linting
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},

      # Documentation
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end
end
