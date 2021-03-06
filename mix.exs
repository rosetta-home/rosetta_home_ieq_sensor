defmodule RosettaHomeIeqSensor.Mixfile do
  use Mix.Project

  def project do
    [app: :rosetta_home_ieq_sensor,
     version: "0.1.1",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [extra_applications: [:logger, :cicada]]
  end

  defp deps do
    [
      {:ieq_gateway, "~> 0.2.0"},
      {:cicada, github: "rosetta-home/cicada",  optional: true}
    ]
  end
end
