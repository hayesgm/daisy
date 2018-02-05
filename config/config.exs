use Mix.Config

config :daisy,
  serializer: Daisy.Serializer.JSONSerializer

import_config "#{Mix.env}.exs"
