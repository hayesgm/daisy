use Mix.Config

config :daisy,
  serializer: Daisy.Serializer.JSONSerializer,
  run_leader: false,
  run_follower: false,
  run_api: false

import_config "#{Mix.env}.exs"
