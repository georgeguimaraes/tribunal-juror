defmodule TribunalJuror.ScenariosTest do
  use ExUnit.Case, async: true

  alias TribunalJuror.Scenarios

  test "scenario expectations and options match their selected evaluations" do
    for scenario <- Scenarios.all() do
      evaluations = MapSet.new(scenario.evaluations)

      assert MapSet.new(Map.keys(scenario.expected)) == evaluations
      assert MapSet.subset?(MapSet.new(Map.keys(scenario.evaluation_opts)), evaluations)
    end
  end
end
