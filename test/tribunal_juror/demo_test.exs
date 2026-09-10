defmodule TribunalJuror.DemoTest do
  use ExUnit.Case, async: true
  use Tribunal.ExUnit

  alias Tribunal.{Dataset, Evaluator}
  alias Tribunal.Batch.{Policy, Report}

  @root Path.expand("../..", __DIR__)
  @demo_dir Path.join(@root, "priv/demo")

  test "offline batch passes overall but fails the account-safety gate" do
    {:ok, policy} = Policy.load("evaluation_policy.yaml", cwd: @root)
    [dataset] = policy.datasets
    cases = Dataset.load_with_assertions!(dataset)
    group_field = policy.gates.groups.by
    groups = Report.validate_group_cases!(cases, group_field)

    results =
      Enum.zip_with(cases, groups, fn {test_case, assertions}, group ->
        test_case
        |> Evaluator.evaluate(assertions)
        |> Map.put(:group, %{by: group_field, value: group})
      end)

    report = Report.build(results, System.monotonic_time(:millisecond))

    assert {report, false} =
             Report.apply_gates(report, %{
               overall: policy.gates.overall.threshold,
               groups: %{by: group_field, pass_rate: policy.gates.groups.threshold}
             })

    assert %{total: 10, passed: 9, errors: 0, pass_rate: 0.9, gate_status: :failed} =
             report.summary

    assert %{passed_gate: true, pass_rate: 0.9} = report.gates.overall

    assert [
             %{value: "account-safety", passed: 1, total: 2, passed_gate: false},
             %{value: "product-support", passed: 8, total: 8, passed_gate: true}
           ] = report.gates.groups.results
  end

  test "repeat invokes the callback five times and accepts four passing outputs" do
    replies = ["accepted", "accepted", "rejected", "accepted", "accepted"]
    state = start_supervised!({Agent, fn -> replies end})

    result =
      tribunal_assert(
        fn -> Agent.get_and_update(state, fn [reply | rest] -> {reply, rest} end) end,
        input: "Return accepted",
        repeat: 5,
        pass_rule: {:rate, 0.8},
        expected: [equals: [value: "accepted"]]
      )

    assert %{status: :passed, sample: %{passed: 4, failed: 1, pass_rate: 0.8}} = result
    assert Enum.map(result.attempts, & &1.actual_output) == replies
    assert Agent.get(state, & &1) == []
  end

  test "migrated datasets have no unsupported assertions or list-valued contains" do
    judge_types = Tribunal.Judge.all_judge_names()

    for path <- Path.wildcard(Path.join(@root, "test/evals/datasets/*.yaml")),
        {test_case, assertions} <- Dataset.load_with_assertions!(path) do
      for {type, opts} <- assertions do
        if type in judge_types do
          assert type in [:faithful, :relevant, :refusal, :no_pii, :no_toxicity]
        else
          populated = %{
            test_case
            | actual_output: test_case.actual_output || "offline format check"
          }

          assert {status, _details} = Tribunal.Assertions.evaluate(type, populated, opts)

          assert status in [:pass, :fail],
                 "Unsupported dataset assertion in #{path}: #{inspect(type)}"
        end
      end
    end
  end

  @tag :tmp_dir
  test "five authored red-team fixtures preserve policies through YAML and route to the policy judge",
       %{tmp_dir: tmp_dir} do
    attacks = @demo_dir |> Path.join("attacks.json") |> File.read!() |> JSON.decode!()
    policy = @demo_dir |> Path.join("policy.txt") |> File.read!()
    plugins = [:policy, :hijacking, :prompt_extraction, :excessive_agency, :imitation]

    generated =
      Enum.flat_map(plugins, fn plugin ->
        assert {:ok, [case_]} =
                 Tribunal.RedTeam.generate(
                   plugins: [plugin],
                   purpose: "Informational shopping assistant for a cosmetics retailer.",
                   policy: policy,
                   count: 1,
                   attacker: TribunalJuror.DemoAttacker,
                   demo_attack: Map.fetch!(attacks, Atom.to_string(plugin))
                 )

        [case_]
      end)

    path = Path.join(tmp_dir, "redteam.yaml")
    File.write!(path, Tribunal.RedTeam.YamlEmit.encode(generated))
    loaded = Dataset.load_with_assertions!(path)

    assert Enum.map(loaded, fn {case_, _} -> case_.metadata["plugin"] end) ==
             Enum.map(plugins, &Atom.to_string/1)

    for {original, {test_case, [no_policy_violation: opts] = assertions}} <-
          Enum.zip(generated, loaded) do
      expected_policy = original.expected.no_policy_violation.policy
      assert opts[:policy] == expected_policy
      assert test_case.metadata["attack_id"] == original.metadata.attack_id
      assert test_case.metadata["generation"]["attacker"] == "TribunalJuror.DemoAttacker"

      output = "This is an authored test response."
      populated = %{test_case | actual_output: output}

      for {verdict, expected_status} <- [{"yes", :failed}, {"no", :passed}] do
        client = fn _model, [%{role: "system"}, %{role: "user", content: prompt}], _opts ->
          assert prompt =~ expected_policy
          assert prompt =~ test_case.input
          assert prompt =~ output
          {:ok, %{"verdict" => verdict, "reason" => "Injected verdict for routing only."}}
        end

        result = Evaluator.evaluate(populated, assertions, defaults: [llm: client])
        assert result.status == expected_status
        refute result.execution_error
      end
    end
  end
end
