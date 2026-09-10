defmodule TribunalJurorWeb.HomeLive do
  use TribunalJurorWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-12">
        <section class="text-center py-12">
          <div class="flex justify-center mb-6">
            <div class="p-4 rounded-full bg-primary/10">
              <.icon name="hero-scale" class="size-16 text-primary" />
            </div>
          </div>
          <h1 class="text-4xl font-bold tracking-tight mb-4">
            Tribunal
          </h1>
          <p class="text-xl text-base-content/70 max-w-2xl mx-auto mb-8">
            LLM Evaluation Framework for Elixir. Detect hallucinations, measure faithfulness,
            and validate AI outputs with confidence.
          </p>
          <div class="flex justify-center gap-4">
            <a href="/playground" class="btn btn-primary btn-lg">
              <.icon name="hero-play" class="size-5" /> Try Playground
            </a>
            <a href="/scenarios" class="btn btn-outline btn-lg">
              <.icon name="hero-beaker" class="size-5" /> View Scenarios
            </a>
          </div>
        </section>

        <section class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <.feature_card
            icon="hero-bolt"
            title="Deterministic"
            description="Fast, no-LLM checks: regex, JSON validation, contains, length limits."
          />
          <.feature_card
            icon="hero-cpu-chip"
            title="LLM-as-Judge"
            description="Faithfulness, relevance, correctness, refusal, privacy, toxicity, and explicit policies."
          />
          <.feature_card
            icon="hero-arrows-right-left"
            title="Embeddings"
            description="Semantic similarity using local embeddings via alike, without a remote LLM judge."
          />
        </section>

        <section class="card bg-base-200 p-8">
          <h2 class="text-2xl font-bold mb-2">Evaluation Keys</h2>
          <p class="text-sm text-base-content/70 mb-6">
            These keys work in datasets and Tribunal.evaluate. For simple ExUnit checks, use
            native assertions. No-prefixed keys pass when the unwanted condition is absent.
          </p>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
            <div>
              <h3 class="font-semibold text-primary mb-3 flex items-center gap-2">
                <.icon name="hero-bolt" class="size-5" /> Deterministic
              </h3>
              <ul class="space-y-1 text-sm text-base-content/80">
                <li>
                  <code class="text-xs bg-base-300 px-1 rounded">contains</code>
                  - Output includes one substring
                </li>
                <li>
                  <code class="text-xs bg-base-300 px-1 rounded">regex</code> - Output matches pattern
                </li>
                <li>
                  <code class="text-xs bg-base-300 px-1 rounded">is_json</code> - Valid JSON output
                </li>
                <li>
                  <code class="text-xs bg-base-300 px-1 rounded">contains_all</code>
                  - Includes every listed substring
                </li>
                <li>
                  <code class="text-xs bg-base-300 px-1 rounded">levenshtein</code> - Edit distance
                </li>
              </ul>
            </div>
            <div>
              <h3 class="font-semibold text-secondary mb-3 flex items-center gap-2">
                <.icon name="hero-cpu-chip" class="size-5" /> LLM-as-Judge
              </h3>
              <ul class="space-y-1 text-sm text-base-content/80">
                <li>
                  <code class="text-xs bg-base-300 px-1 rounded">faithful</code> - Grounded in context
                </li>
                <li>
                  <code class="text-xs bg-base-300 px-1 rounded">relevant</code> - Addresses query
                </li>
                <li>
                  <code class="text-xs bg-base-300 px-1 rounded">correctness</code> - Matches expected
                </li>
                <li>
                  <code class="text-xs bg-base-300 px-1 rounded">no_pii</code>
                  - No personal info exposure
                </li>
                <li>
                  <code class="text-xs bg-base-300 px-1 rounded">no_toxicity</code>
                  - No abusive or harmful content
                </li>
                <li>
                  <code class="text-xs bg-base-300 px-1 rounded">no_policy_violation</code>
                  - Follows your explicit rules
                </li>
                <li>
                  <code class="text-xs bg-base-300 px-1 rounded">refusal</code> - Detects refusals
                </li>
              </ul>
            </div>
            <div>
              <h3 class="font-semibold text-accent mb-3 flex items-center gap-2">
                <.icon name="hero-arrows-right-left" class="size-5" /> Embedding
              </h3>
              <ul class="space-y-1 text-sm text-base-content/80">
                <li>
                  <code class="text-xs bg-base-300 px-1 rounded">similar</code> - Semantic similarity
                </li>
              </ul>
              <p class="text-xs text-base-content/60 mt-4">
                Requires the optional <code class="bg-base-300 px-1 rounded">alike</code>
                dependency, which is not installed in this showcase. First use may download
                the model. Similarity does not guarantee factual correctness.
              </p>
            </div>
          </div>
        </section>

        <section class="card bg-base-200 p-8">
          <h2 class="text-2xl font-bold mb-6">Quick Start</h2>
          <div class="mockup-code text-sm" phx-no-curly-interpolation>
            <pre data-prefix="1"><code>defmodule MyApp.RAGEvalTest do</code></pre>
            <pre data-prefix="2"><code>  use ExUnit.Case</code></pre>
            <pre data-prefix="3"><code>  use Tribunal.ExUnit</code></pre>
            <pre data-prefix="4"><code></code></pre>
            <pre data-prefix="5"><code>  @moduletag :eval</code></pre>
            <pre data-prefix="6"><code></code></pre>
            <pre data-prefix="7"><code>  test "response is grounded in context" do</code></pre>
            <pre data-prefix="8"><code>    response = MyApp.RAG.query("What's the return policy?")</code></pre>
            <pre data-prefix="9"><code></code></pre>
            <pre data-prefix="10"><code>    assert response =~ "30 days"</code></pre>
            <pre data-prefix="11"><code>    assert_faithful response, context: @docs, threshold: 0.8</code></pre>
            <pre data-prefix="12"><code>  end</code></pre>
            <pre data-prefix="13"><code>end</code></pre>
          </div>
        </section>

        <section id="cli-demos" class="card bg-base-200 p-8 space-y-4">
          <h2 class="text-2xl font-bold">From one response to a whole batch</h2>
          <p class="text-base-content/70">
            The playground grades a pasted response. Use the ExUnit/provider examples for
            fresh calls and repeated sampling, and the Mix demos for batch gates and
            red-team case generation.
          </p>
          <div class="space-y-3 text-sm">
            <p>
              <code class="bg-base-300 px-2 py-1 rounded">mix tribunal.eval --config evaluation_policy.yaml</code>
              runs the deterministic batch-gate demo. Assertion thresholds grade attempts,
              sampling combines attempts into cases, and gates grade the complete batch.
            </p>
            <p>
              <code class="bg-base-300 px-2 py-1 rounded">mix run scripts/redteam_demo.exs</code>
              generates attack cases with explicit policies. The five generators cover policy
              violations, scope drift, prompt extraction, excessive agency, and imitation.
            </p>
            <p>
              See the repository README for expected results and live-model options. Offline
              demo results demonstrate the pipeline and do not measure a model's safety.
            </p>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true

  defp feature_card(assigns) do
    ~H"""
    <div class="card bg-base-200 p-6 hover:bg-base-300 transition-colors">
      <div class="flex items-center gap-3 mb-3">
        <div class="p-2 rounded-lg bg-primary/10">
          <.icon name={@icon} class="size-6 text-primary" />
        </div>
        <h3 class="font-semibold text-lg">{@title}</h3>
      </div>
      <p class="text-base-content/70 text-sm">{@description}</p>
    </div>
    """
  end
end
