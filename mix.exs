defmodule GleamPlug.MixProject do
  use Mix.Project

  @app :wisp_plug

  def project do
    [
      app: @app,
      version: "0.1.0",
      elixir: "~> 1.9",
      archives: [mix_gleam: "~> 0.6"],
      start_permanent: Mix.env() == :prod,
      compilers: [:gleam | Mix.compilers()],
      description: "A Gleam HTTP service adapter for the Plug web application interface",
      package: [
        licenses: ["Apache-2.0"],
        links: %{github: "https://github.com/gleam-lang/plug"}
      ],
      deps: deps(),
      aliases: [
        # Or add this to your aliases function
        "deps.get": ["deps.get", "gleam.deps.get"]
      ],
      erlc_paths: [
        "build/dev/erlang/#{@app}/_gleam_artefacts",
        "build/dev/erlang/#{@app}/build",
      ],
      erlc_include_path: "build/dev/erlang/#{@app}/include",
      prune_code_paths: false,
    ]

  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:gleam_stdlib, "~> 0.40"},
      {:gleam_http, "~> 3.7"},
      {:wisp, "~> 1.2"},
      {:plug, "~> 1.10"},
      {:directories, "~> 1.1"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
