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

## Design Mantras

Daisy aims to be a side-chain. We have a few important design mantras to guide our process:

1. **Bring your own Bespoke VM**. Anyone who builds a Daisy chain can incorporate whatever VM fits that business application. For example, you could build a ZombieKittens VM that exposes `sire_kitten(kitten_uuid)`, `fight_kitten(kitten_uuid, target_uuid)`, both of which are implemented in Elixir. Anyone who submits a transaction to the chain is submitting intent, not arbitrary code. Which brings us to:
2. **Forks are Patches**. Transactions are intent-based given a Daisy VM. For example, a Payment VM might have a transaction: `transfer_funds(from, to)` or a Chess VM: `move_pawn(game, location)`. When there are bugs in the implementation of a function, it should be easily agreed upon to make a change if it matches the original intent for the user. Patches must be agreed upon by the community, and the goal is that most patches should be quickly accepted.
3. **Ethereum Bridge Contracts**. Daisy is just a side-chain; it's meant to interact with one or more main chains. The root hash of every mined block is submitted to an Ethereum Bridge Contract. This contract can, via evidence provided by merkle-proofs, verify that data exists on the side-chain. For instance, this allows your chain to verifiable move Ether into your Daisy side-chain. The end-user could add Ether to the bridge contract, which would be held as pending until a merkle-proof from a new root hash included the user's updated side-chain balance. These bridges allow Daisy side-chains to interact with Ethereum, Bitcoin and all other chains.
4. **Elected-Leader Sidechain**. We belive that adding a little centralization can go a long way. In Daisy, token holders on a main chain (e.g. the Ethereum Bridge Contract) elect a leader who mines all blocks. To submit a transction, you pass the transaction to the leader directly (and get an immediate pending result). Anyone can run a Daisy node and verify that the given blocks are accurate to the protocol. If the leader posts any inaccurate blocks, the community immediately holds a new leader election in the bridge contract. The central leader allows the entire system to be free, instant and verifiable.
5. **IPFS**. All blockchains need to store data in a content-addressable structure and distribute those blocks in a peer-to-peer system. Can't somebody else do it? Well, they did, and it's IPFS. Daisy relies on IPFS for distributing new blocks, IPNS for information about the current block hash and even allows users to explore the blockchain through the web at https://ipfs.io.

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