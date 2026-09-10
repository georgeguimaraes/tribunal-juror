# Tribunal Juror

A Phoenix LiveView showcase application demonstrating the [Tribunal](https://github.com/georgeguimaraes/tribunal) LLM evaluation library.

## What is this?

Tribunal Juror provides an interactive web interface to explore and test Tribunal's evaluation capabilities. It includes:

- **Home**: Overview of Tribunal's features and available assertions
- **Playground**: Interactive sandbox to test LLM outputs against various evaluation criteria
- **Scenarios**: Pre-built examples demonstrating common evaluation patterns and edge cases

The dependency lock pins Tribunal's consolidated API. The playground grades one supplied response. ExUnit examples demonstrate fresh repeated calls, and the Mix task handles whole-batch gates and reports.

## Setup

```bash
# Clone the repo
git clone https://github.com/georgeguimaraes/tribunal-juror.git
cd tribunal-juror

# Install dependencies
mix setup

# Start the server
mix phx.server
```

Visit [localhost:4000](http://localhost:4000) to explore the app.

## Configuration

The playground uses GLM-5.3-Flash as its judge. Export a Z.AI API key before starting the server:

```bash
export ZAI_API_KEY="your-api-key"
mix phx.server
```

The sample agent used by `mix tribunal.eval` stays on GLM-4.7 so the system being evaluated and its judge can be configured independently.

The offline demos below need no API key. Live judge and agent runs require credentials and can produce different results between runs.

## Presentation walkthrough

### 1. Explore assertions in the browser

Open `/playground` and run a Contains, Regex, or JSON check without credentials. Open `/scenarios` for grounded and unsupported answers, PII, refusal, and explicit policy examples. Policy compliance requires the policy text you want enforced.

Judge checks use the configured live model. Scenario expectations are teaching examples, not guaranteed model verdicts. The playground evaluates the response you enter, it doesn't generate or repeatedly sample an assistant response.

### 2. Run native ExUnit evaluations

```bash
mix test test/tribunal_juror/tribunal_integration_test.exs
mix test
```

These run offline. They exercise `tribunal_assert`, dataset-generated tests, and repeated callbacks. ExUnit requires every test to pass.

### 3. Show why batch gates are separate

```bash
mix tribunal.eval --config evaluation_policy.yaml
```

This offline fixture deliberately exits **1**: 9 of 10 cases pass, so the 90% overall gate passes, but only 1 of 2 account-safety cases passes, below the 80% category requirement. The other 8 cases pass. These are deterministic checks of authored outputs, not measurements of a live model's safety.

For a passing run with only the overall gate, or a machine-readable report:

```bash
mix tribunal.eval priv/demo/batch.yaml --threshold 0.9
mix tribunal.eval --config evaluation_policy.yaml --format json --output tmp/batch-report.json
```

The JSON command still exits 1 because the category gate fails. `evaluation_policy.yaml` owns the batch requirements. Each dataset row owns its assertions and category metadata.

| Layer | Decision |
|---|---|
| Assertion | Does one output satisfy a check? Each metric defines its own threshold semantics. |
| Sampling | Do enough fresh attempts pass for this case? For example, 4 of 5 with `pass_rule: {:rate, 0.8}`. |
| Batch gate | Do enough cases pass overall and within each category? |

The batch fixture uses one attempt per case. Repeating a stored output would just recheck that output. Use a provider or `tribunal_assert` callback to sample fresh application responses.

### 4. Generate reviewable red-team cases

```bash
mix run scripts/redteam_demo.exs
```

This offline walkthrough feeds explicitly authored attack fixtures through all five real generators: `policy`, `hijacking`, `prompt_extraction`, `excessive_agency`, and `imitation`. It prints the path of a new temporary YAML file with an explicit `no_policy_violation` policy and plugin metadata for each case. You can pass a new destination path as an argument, existing files won't be overwritten. It demonstrates generation and serialization, not live attack discovery or judge accuracy.

For live attack generation, using the configured provider's credentials:

```bash
mix tribunal.redteam.generate \
  --plugins policy,hijacking,prompt_extraction,excessive_agency,imitation \
  --purpose "Informational shopping assistant for products, orders, and returns." \
  --policy-file priv/demo/policy.txt \
  --model zai:glm-5.3-flash \
  --count 2 \
  --output tmp/redteam-live.yaml

mix tribunal.eval tmp/redteam-live.yaml \
  --provider TribunalJuror.Agent.query \
  --group-by plugin \
  --group-threshold 0.8
```

The sample agent is a generic assistant, so failures against shopping-specific policies are possible and useful to inspect. Review generated policies against your target before interpreting results. Excessive-agency cases assume an informational assistant without transaction capabilities. A text judge cannot prove whether an external action happened.

Each generated attack is a separate one-shot case. Multi-turn adaptive attacks aren't implemented here. Review candidates, then promote useful cases into a committed dataset consumed by `tribunal_dataset`. Generating attacks alone doesn't evaluate the target.

## Evaluation modes

Use `tribunal_assert` inside a normal ExUnit test when every sample should call your application again:

```elixir
defmodule MyApp.ResponseEvalTest do
  use ExUnit.Case
  use Tribunal.ExUnit

  test "response stays relevant" do
    question = "How do I reset my password?"

    tribunal_assert fn -> MyApp.Support.reply(question) end,
      input: question,
      repeat: 3,
      pass_rule: :majority,
      expected: [relevant: []]
  end
end
```

Use `tribunal_dataset` when a dataset should generate one native ExUnit test per row:

```elixir
tribunal_dataset "test/evals/datasets/support.yaml",
  provider: {MyApp.Support, :reply},
  repeat: 3,
  pass_rule: :majority
```

Use the Mix task for batch evaluation, reports, and suite-wide gates. Juror includes datasets and a sample provider for this mode:

```bash
mix tribunal.eval test/evals/datasets/agent_evals.yaml \
  --provider TribunalJuror.Agent.query \
  --repeat 3 \
  --pass-rule majority \
  --threshold 0.8
```

## Features

### Deterministic Assertions

- `contains` / `not_contains`: Check for one substring
- `contains_all` / `contains_any`: Check several substrings
- `is_json`: Validate JSON format
- `regex`: Pattern matching

These are dataset/evaluation keys. In ordinary ExUnit tests, use native assertions for simple text and JSON checks.

### LLM-as-Judge Assertions

- `faithful`: Is the response faithful to the context?
- `relevant`: Does it answer the question?
- `correctness`: Is the answer correct?
- `no_pii`: Require absence of personally identifiable information
- `no_toxicity`: Require absence of abusive or harmful content, including politely worded dangerous advice
- `no_policy_violation`: Enforce explicit rules for scope, fairness, confidentiality, action claims, or identity
- `refusal`: Detect refusal responses

Unsupported claims are checked with `faithful`. Negative checks use `no_*` dataset names, while the corresponding ExUnit macros read `refute_pii`, `refute_toxicity`, and `refute_policy_violation`.

`assert_similar` is a separate embedding-based check in Tribunal. It uses the optional `alike` dependency and a local model, not an LLM judge. Juror doesn't install that dependency or offer an embedding demo.

## Pre-built Scenarios

The app includes pre-built scenarios across these categories:

| Category | Scenarios |
|----------|-----------|
| Faithfulness | Faithful Summary, Hallucinated Facts, Subtle Hallucination, Contradictory Response |
| Safety | PII Leak Detection, Correct Refusal |
| Format | JSON Validation |
| Relevance | Off-Topic Answer |

Explicit policy scenarios also demonstrate staying in scope, protecting private information, and avoiding unsupported action claims. The larger YAML suites under `test/evals/datasets` include live judge checks and intentionally failing outputs, so their pass rates aren't fixed presentation expectations.

## Learn More

- [Tribunal Documentation](https://hexdocs.pm/tribunal)
- [Phoenix Framework](https://www.phoenixframework.org/)
