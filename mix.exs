defmodule Daisy.Mixfile do
  use Mix.Project

  def project do
    [
      app: :daisy,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      description: "A new blockchain experience",
      package: [
        maintainers: ["Geoffrey Hayes"],
        licenses: ["MIT"],
        links: %{"GitHub" => "https://github.com/hayesgm/daisy"}
      ],
      deps: deps()
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
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:ipfs_client, github: "hayesgm/elixir-ipfs-client", branch: "hayesgm/add-potent-operations"},
      {:protobufex, github: "hayesgm/protobuf-elixir", branch: "hayesgm/extensions-ex"},
      {:uuid, "~> 1.1"},
      {:base58check, github: "lukaszsamson/base58check"},
    ]
  end
end
