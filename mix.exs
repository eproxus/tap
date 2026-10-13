defmodule Tap.MixProject do
  use Mix.Project

  # src/tap.app.src holds the version and package metadata, so that rebar3
  # builds and Mix builds share them. Hex packages must include it.
  {:ok, [{:application, :tap, app}]} =
    :file.consult(Path.join(__DIR__, "src/tap.app.src"))

  @app Map.new(app)
  @version to_string(@app.vsn)
  @links Map.new(@app.links, fn {name, url} ->
           {to_string(name), to_string(url)}
         end)
  @source_url @links["GitHub"]

  def project do
    [
      app: :tap,
      description: to_string(@app.description),
      package: package(),
      version: @version,
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [
        main: "readme",
        extras: ["README.md", "CHANGELOG.md"],
        # The changelog mentions functions that were removed.
        skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
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
      licenses: Enum.map(@app.licenses, &to_string/1),
      source_url: @source_url,
      links: @links
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      # Linting
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},

      # Documentation
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end
end
