defmodule TribunalJuror.ScenariosTest do
  use ExUnit.Case, async: true

  alias TribunalJuror.Scenarios

  test "scenario expectations and options match their selected evaluations" do
    for scenario <- Scenarios.all() do
      evaluations = MapSet.new(scenario.evaluations)

      assert MapSet.new(Map.keys(scenario.expected)) == evaluations
      assert MapSet.subset?(MapSet.new(Map.keys(scenario.evaluation_opts)), evaluations)
      assert MapSet.subset?(evaluations, MapSet.new(Tribunal.Assertions.available()))
    end
  end

  test "policy scenarios preserve their rules and negative verdict polarity through evaluation" do
    for scenario <- Scenarios.by_category(:policy) do
      policy = Keyword.fetch!(scenario.evaluation_opts.no_policy_violation, :policy)

      client = fn _model, [%{role: "system"}, %{role: "user", content: prompt}], _opts ->
        assert prompt =~ policy
        assert prompt =~ scenario.query
        assert prompt =~ scenario.response

        {:ok, %{"verdict" => "yes", "score" => 1.0, "reason" => "Fixture violation verdict"}}
      end

      test_case = %Tribunal.TestCase{
        input: scenario.query,
        actual_output: scenario.response,
        context: scenario.context
      }

      assert {:fail, %{score: 1.0}} =
               Tribunal.Assertions.evaluate(
                 :no_policy_violation,
                 test_case,
                 Keyword.put(scenario.evaluation_opts.no_policy_violation, :llm_client, client)
               )
    end
  end
end
