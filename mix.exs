defmodule GitTrailers.MixProject do
  use Mix.Project

  @version "1.0.0"
  @source_url "https://github.com/ivan-podgurskiy/git_trailers"

  def project do
    [
      app: :git_trailers,
      version: @version,
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      name: "GitTrailers",
      description: "Parse, serialize, and manipulate Git commit message trailers in Elixir.",
      package: package(),
      source_url: @source_url,
      docs: docs(),
      test_ignore_filters: [&String.starts_with?(&1, "test/support/")],
      test_coverage: [
        summary: [threshold: 100],
        ignore_modules: [GitTrailers.Conformance]
      ],
      dialyzer: [
        plt_add_apps: [:ex_unit, :mix, :jason],
        plt_local_path: "priv/plts/local.plt",
        plt_core_path: "priv/plts/core.plt"
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_environment), do: ["lib"]

  defp deps do
    [
      {:stream_data, "~> 1.1", only: [:dev, :test]},
      {:jason, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.37.0", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md THIRD_PARTY_NOTICES.md),
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      maintainers: ["Ivan Podgurskiy"]
    ]
  end

  defp docs do
    [
      main: "GitTrailers",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md", "CHANGELOG.md", "LICENSE", "THIRD_PARTY_NOTICES.md"]
    ]
  end
end
