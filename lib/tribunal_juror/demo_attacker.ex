defmodule TribunalJuror.DemoAttacker do
  @moduledoc """
  Returns one authored attack fixture without calling a model.

  Used by `scripts/redteam_demo.exs` to demonstrate Tribunal's real plugin
  pipeline, YAML policies, and provenance. It does not validate attack quality
  or judge a target assistant.
  """

  @behaviour Tribunal.RedTeam.Attacker

  @impl true
  def generate(_prompt, _schema, opts) do
    case {Keyword.get(opts, :count), Keyword.get(opts, :demo_attack)} do
      {1, %{"prompt" => prompt, "goal" => goal} = attack}
      when is_binary(prompt) and is_binary(goal) ->
        if String.trim(prompt) != "" and String.trim(goal) != "" do
          {:ok, %{attacks: [Map.take(attack, ["prompt", "goal"])]}}
        else
          {:error, :invalid_demo_attack}
        end

      _ ->
        {:error, :expected_one_authored_demo_attack}
    end
  end
end
