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
            description="Faithfulness, relevance, hallucination detection, toxicity, bias checks."
          />
          <.feature_card
            icon="hero-arrows-right-left"
            title="Embeddings"
            description="Semantic similarity comparison using vector embeddings."
          />
        </section>

        <section class="card bg-base-200 p-8">
          <h2 class="text-2xl font-bold mb-6">Available Assertions</h2>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
            <div>
              <h3 class="font-semibold text-primary mb-3 flex items-center gap-2">
                <.icon name="hero-bolt" class="size-5" /> Deterministic
              </h3>
              <ul class="space-y-1 text-sm text-base-content/80">
                <li>
                  <code class="text-xs bg-base-300 px-1 rounded">contains</code>
                  - Output includes substring(s)
                </li>
                <li>
                  <code class="text-xs bg-base-300 px-1 rounded">regex</code> - Output matches pattern
                </li>
                <li>
                  <code class="text-xs bg-base-300 px-1 rounded">is_json</code> - Valid JSON output
                </li>
                <li>
                  <code class="text-xs bg-base-300 px-1 rounded">max_tokens</code> - Token limit
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
                  <code class="text-xs bg-base-300 px-1 rounded">hallucination</code>
                  - Fabricated info
                </li>
                <li>
                  <code class="text-xs bg-base-300 px-1 rounded">correctness</code> - Matches expected
                </li>
                <li>
                  <code class="text-xs bg-base-300 px-1 rounded">pii</code> - Personal info detection
                </li>
                <li>
                  <code class="text-xs bg-base-300 px-1 rounded">toxicity</code> - Harmful content
                </li>
                <li>
                  <code class="text-xs bg-base-300 px-1 rounded">bias</code> - Biased statements
                </li>
                <li>
                  <code class="text-xs bg-base-300 px-1 rounded">jailbreak</code> - Attack detection
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
                Requires <code class="bg-base-300 px-1 rounded">alike</code> dependency
              </p>
            </div>
          </div>
        </section>

        <section class="card bg-base-200 p-8">
          <h2 class="text-2xl font-bold mb-6">Quick Start</h2>
          <div class="mockup-code text-sm" phx-no-curly-interpolation>
            <pre data-prefix="1"><code>defmodule MyApp.RAGEvalTest do</code></pre>
            <pre data-prefix="2"><code>  use ExUnit.Case</code></pre>
            <pre data-prefix="3"><code>  use Tribunal.EvalCase</code></pre>
            <pre data-prefix="4"><code></code></pre>
            <pre data-prefix="5"><code>  @moduletag :eval</code></pre>
            <pre data-prefix="6"><code></code></pre>
            <pre data-prefix="7"><code>  test "response is grounded in context" do</code></pre>
            <pre data-prefix="8"><code>    response = MyApp.RAG.query("What's the return policy?")</code></pre>
            <pre data-prefix="9"><code></code></pre>
            <pre data-prefix="10"><code>    assert_contains response, "30 days"</code></pre>
            <pre data-prefix="11"><code>    assert_faithful response, context: @docs, threshold: 0.8</code></pre>
            <pre data-prefix="12"><code>  end</code></pre>
            <pre data-prefix="13"><code>end</code></pre>
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
