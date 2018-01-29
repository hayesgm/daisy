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

## Terminology

<dl>
  <dt>Block</dt>
  <dd>A block is a collection of transactions which are run from the final state of a parent block. Each transaction generates a receipt describing how it ran.</dd>

  <dt>Transaction, Invokation and Signature</dt>
  <dd>A function invokation signed by a user. Transactions effect the total state of the chain. The `Invokation` specifies what function and arguments to call in the VM Runner, and the signature provides an ECDSA signature to prove who is the owner of the message.</dd>

  <dt>Receipt</dt>
  <dd>After a transaction is run, a receipt is generated. The receipt described what happened during the execution of the transaction. A receipt includes logs, the final state after running, etc.</dd>

  <dt>Daisy VM</dt>
  <dd>A VM describes how your world works in Daisy. For a VM, you specify a `Runner` which is responsible for function invokations from `Transaction`s, and you specify a `Reader` which describes how to read from your world state.</dd>

  <dt>Proof</dt>
  <dd>To interact with other chains (e.g. Ethereum), it's often necessary to state
  that a value exists in a Daisy side-chain without having to include the entire Daisy chain in the Ethereum blockchain. `Proof` are nodes in the IPFS tree that prove a given leaf has a given value rolled up a block hash.</dd>

  <dt>Serializer</dt>
  <dd>Some data, such as transactions and receipts, are serialized before being pushed onto the blockchain. This is because, among other reasons, they need a digital signature and thus a canonical representation. We currently support JSON serialization.</dd>
</dl>

## API

Daisy comes with a JSON-API to communicate with a node.

### Reading from Daisy Blocks

```bash
# Read from current block
curl http://localhost:2235/read/:my_func>/:my_arg_1/:my_arg_2/...
{"result" => "good"}

# Read from specified block
curl http://localhost:2235/read/block/:block_hash/:my_func/:my_arg_1/:my_arg_2/...
{"result" => "good"}
```

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/daisy](https://hexdocs.pm/daisy).

## Contributing

Feel free to open a pull request or raise an issue. Daisy is in early development.