# Daisy

![Daisy Chain](https://upload.wikimedia.org/wikipedia/commons/thumb/2/29/Daisy_chain.JPG/1200px-Daisy_chain.JPG)

Daisy is a simple, but fully featured blockchain with a pluggable VM. The goal of Daisy is to make it trivially simple to build a side-chain which can accept thousands of transactions per second. Daisy is backed by `ipfs` which makes it trivially easy for anyone to read, verify or explore the chain. We have designed Daisy to easily bridge to and from other block chains (e.g. Ethereum), so clients can easily move assets on to and off of a Daisy chain.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `daisy` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:daisy, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/daisy](https://hexdocs.pm/daisy).

