use Mix.Config

config :daisy,
  reader: Daisy.Examples.Kitten.Reader,
  runner: Daisy.Examples.Kitten.Runner,
  ipfs_key: "miner",
  run_miner: false,
  run_api: false
