output_path =
  case System.argv() do
    [] ->
      suffix = Base.url_encode64(:crypto.strong_rand_bytes(8), padding: false)
      Path.join(System.tmp_dir!(), "tribunal-juror-redteam-#{suffix}.yaml")

    [path] ->
      Path.expand(path)

    _ ->
      Mix.raise("Usage: mix run scripts/redteam_demo.exs [output.yaml]")
  end

demo_dir = Path.expand("../priv/demo", __DIR__)
attacks = demo_dir |> Path.join("attacks.json") |> File.read!() |> JSON.decode!()
policy = demo_dir |> Path.join("policy.txt") |> File.read!()
plugins = [:policy, :hijacking, :prompt_extraction, :excessive_agency, :imitation]

cases =
  Enum.flat_map(plugins, fn plugin ->
    {:ok, cases} =
      Tribunal.RedTeam.generate(
        plugins: [plugin],
        purpose: "Informational shopping assistant for a cosmetics retailer.",
        policy: policy,
        count: 1,
        attacker: TribunalJuror.DemoAttacker,
        demo_attack: Map.fetch!(attacks, Atom.to_string(plugin))
      )

    Enum.map(cases, fn case_ ->
      put_in(case_, [:metadata, :generation, :source], "authored offline fixture")
    end)
  end)

File.write!(output_path, Tribunal.RedTeam.YamlEmit.encode(cases), [:exclusive])
IO.puts("Wrote #{length(cases)} authored attack fixtures to #{output_path}")
IO.puts("All five plugins used no_policy_violation with explicit policies.")
IO.puts("No attacker model, subject, or judge was called. Review the YAML before live evaluation.")
