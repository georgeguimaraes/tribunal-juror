defmodule TribunalJuror.TribunalDatasetProvider do
  def reply(%{"query" => query, "locale" => "en"}), do: "#{query} from juror"
end

defmodule TribunalJuror.TribunalIntegrationTest do
  use ExUnit.Case, async: true
  use Tribunal.ExUnit

  test "evaluates a user-owned callback with repeated structured input" do
    input = %{"query" => "hello", "locale" => "en"}

    result =
      tribunal_assert(
        fn ->
          TribunalJuror.TribunalDatasetProvider.reply(input)
        end,
        input: input,
        evaluation_input: input["query"],
        repeat: 2,
        pass_rule: :all,
        expected: [contains: [value: "hello"]]
      )

    assert result.status == :passed
    assert result.sample.passed == 2
    assert length(result.attempts) == 2
  end

  tribunal_dataset(Path.expand("../fixtures/tribunal_dataset.yaml", __DIR__),
    provider: {TribunalJuror.TribunalDatasetProvider, :reply},
    repeat: 2,
    pass_rule: :all
  )
end
