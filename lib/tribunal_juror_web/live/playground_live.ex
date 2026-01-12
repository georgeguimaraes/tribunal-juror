defmodule TribunalJurorWeb.PlaygroundLive do
  use TribunalJurorWeb, :live_view

  alias Tribunal.TestCase

  @deterministic_evals [:contains, :not_contains, :is_json, :no_pii, :is_refusal, :regex]
  @judge_evals [:faithful, :relevant, :hallucination, :correctness]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:context, "")
     |> assign(:response, "")
     |> assign(:query, "")
     |> assign(:contains_value, "")
     |> assign(:selected_evals, MapSet.new([:contains]))
     |> assign(:results, nil)
     |> assign(:running, false)
     |> assign(:error, nil)
     |> assign(:deterministic_evals, @deterministic_evals)
     |> assign(:judge_evals, @judge_evals)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    case params do
      %{"scenario" => scenario_id} ->
        case TribunalJuror.Scenarios.get(scenario_id) do
          nil ->
            {:noreply, socket}

          scenario ->
            {:noreply,
             socket
             |> assign(:context, String.trim(scenario.context))
             |> assign(:response, String.trim(scenario.response))
             |> assign(:query, Map.get(scenario, :query, ""))
             |> assign(:selected_evals, MapSet.new(scenario.evaluations))
             |> assign(:results, nil)}
        end

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_field", %{"field" => field, "value" => value}, socket) do
    {:noreply, assign(socket, String.to_existing_atom(field), value)}
  end

  @impl true
  def handle_event("toggle_eval", %{"eval" => eval}, socket) do
    eval_atom = String.to_existing_atom(eval)
    selected = socket.assigns.selected_evals

    selected =
      if MapSet.member?(selected, eval_atom) do
        MapSet.delete(selected, eval_atom)
      else
        MapSet.put(selected, eval_atom)
      end

    {:noreply, assign(socket, :selected_evals, selected)}
  end

  @impl true
  def handle_event("run_evaluation", _params, socket) do
    %{
      context: context,
      response: response,
      query: query,
      contains_value: contains_value,
      selected_evals: evals
    } = socket.assigns

    if response == "" do
      {:noreply, assign(socket, :error, "Please enter a response to evaluate")}
    else
      send(self(), {:run_evals, context, response, query, contains_value, evals})
      {:noreply, socket |> assign(:running, true) |> assign(:error, nil) |> assign(:results, nil)}
    end
  end

  @impl true
  def handle_event("clear", _params, socket) do
    {:noreply,
     socket
     |> assign(:context, "")
     |> assign(:response, "")
     |> assign(:query, "")
     |> assign(:contains_value, "")
     |> assign(:results, nil)
     |> assign(:error, nil)}
  end

  @impl true
  def handle_info({:run_evals, context, response, query, contains_value, evals}, socket) do
    test_case = %TestCase{
      input: query,
      actual_output: response,
      context: if(context != "", do: context, else: nil)
    }

    results =
      evals
      |> Enum.map(fn eval ->
        opts = build_opts(eval, context, query, contains_value)
        result = run_evaluation(eval, test_case, opts)
        {eval, result}
      end)
      |> Map.new()

    {:noreply,
     socket
     |> assign(:results, results)
     |> assign(:running, false)}
  end

  defp build_opts(:contains, _context, _query, value), do: [value: value]
  defp build_opts(:not_contains, _context, _query, value), do: [value: value]
  defp build_opts(:faithful, _context, _query, _value), do: []
  defp build_opts(:relevant, _context, query, _value), do: [query: query]
  defp build_opts(:hallucination, _context, _query, _value), do: []
  defp build_opts(:correctness, _context, query, _value), do: [query: query]
  defp build_opts(_eval, _context, _query, _value), do: []

  defp run_evaluation(eval, test_case, opts) do
    try do
      Tribunal.Assertions.evaluate(eval, test_case, opts)
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-8">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold tracking-tight">Evaluation Playground</h1>
            <p class="text-base-content/60 mt-1">
              Test LLM outputs against various evaluation criteria
            </p>
          </div>
          <button
            type="button"
            phx-click="clear"
            class="btn btn-ghost btn-sm gap-2 opacity-70 hover:opacity-100"
          >
            <.icon name="hero-arrow-path" class="size-4" /> Reset
          </button>
        </div>

        <div class="grid grid-cols-1 xl:grid-cols-5 gap-6">
          <div class="xl:col-span-3 space-y-6">
            <div class="card bg-base-200 shadow-sm">
              <div class="card-body p-5">
                <div class="flex items-center justify-between mb-3">
                  <h3 class="font-semibold flex items-center gap-2">
                    <.icon name="hero-document-text" class="size-5 text-primary" />
                    Context / Ground Truth
                  </h3>
                  <span class="text-xs text-base-content/50 uppercase tracking-wide">Optional</span>
                </div>
                <textarea
                  id="context-input"
                  class="textarea bg-base-100 border-base-300 w-full h-28 font-mono text-sm leading-relaxed resize-none focus:border-primary focus:ring-1 focus:ring-primary/20"
                  placeholder="The source documents or ground truth that the response should be faithful to..."
                  phx-blur="update_field"
                  phx-value-field="context"
                >{@context}</textarea>
              </div>
            </div>

            <div class="card bg-base-200 shadow-sm">
              <div class="card-body p-5">
                <div class="flex items-center justify-between mb-3">
                  <h3 class="font-semibold flex items-center gap-2">
                    <.icon name="hero-chat-bubble-left-right" class="size-5 text-secondary" />
                    Query / Prompt
                  </h3>
                  <span class="text-xs text-base-content/50 uppercase tracking-wide">
                    For relevance
                  </span>
                </div>
                <input
                  type="text"
                  id="query-input"
                  class="input bg-base-100 border-base-300 w-full font-mono text-sm focus:border-primary focus:ring-1 focus:ring-primary/20"
                  placeholder="What question was asked to the LLM?"
                  value={@query}
                  phx-blur="update_field"
                  phx-value-field="query"
                />
              </div>
            </div>

            <div class="card bg-base-200 shadow-sm border-2 border-primary/20">
              <div class="card-body p-5">
                <div class="flex items-center justify-between mb-3">
                  <h3 class="font-semibold flex items-center gap-2">
                    <.icon name="hero-sparkles" class="size-5 text-accent" /> LLM Response
                  </h3>
                  <span class="badge badge-primary badge-sm">Required</span>
                </div>
                <textarea
                  id="response-input"
                  class="textarea bg-base-100 border-base-300 w-full h-40 font-mono text-sm leading-relaxed resize-none focus:border-primary focus:ring-1 focus:ring-primary/20"
                  placeholder="Paste the LLM response you want to evaluate..."
                  phx-blur="update_field"
                  phx-value-field="response"
                >{@response}</textarea>
              </div>
            </div>
          </div>

          <div class="xl:col-span-2 space-y-6">
            <div class="card bg-base-200 shadow-sm">
              <div class="card-body p-5">
                <h3 class="font-semibold mb-4 flex items-center gap-2">
                  <.icon name="hero-bolt" class="size-5 text-warning" /> Deterministic Checks
                </h3>
                <div class="flex flex-wrap gap-2">
                  <.eval_toggle
                    :for={eval <- @deterministic_evals}
                    eval={eval}
                    selected={@selected_evals}
                  />
                </div>

                <div
                  :if={
                    MapSet.member?(@selected_evals, :contains) or
                      MapSet.member?(@selected_evals, :not_contains)
                  }
                  class="mt-4 pt-4 border-t border-base-300"
                >
                  <label class="text-xs text-base-content/60 uppercase tracking-wide mb-2 block">
                    Search value
                  </label>
                  <input
                    type="text"
                    class="input input-sm bg-base-100 border-base-300 w-full"
                    placeholder="Text to search for..."
                    value={@contains_value}
                    phx-blur="update_field"
                    phx-value-field="contains_value"
                  />
                </div>
              </div>
            </div>

            <div class="card bg-base-200 shadow-sm">
              <div class="card-body p-5">
                <h3 class="font-semibold mb-4 flex items-center gap-2">
                  <.icon name="hero-cpu-chip" class="size-5 text-info" /> LLM-as-Judge
                  <span class="badge badge-warning badge-xs">API</span>
                </h3>
                <div class="flex flex-wrap gap-2">
                  <.eval_toggle
                    :for={eval <- @judge_evals}
                    eval={eval}
                    selected={@selected_evals}
                  />
                </div>
              </div>
            </div>

            <button
              type="button"
              phx-click="run_evaluation"
              class="btn btn-primary w-full btn-lg shadow-lg shadow-primary/20 hover:shadow-primary/30 transition-shadow"
              disabled={@running}
            >
              <span :if={@running} class="loading loading-spinner"></span>
              <.icon :if={!@running} name="hero-play-solid" class="size-5" />
              {if @running, do: "Evaluating...", else: "Run Evaluation"}
            </button>

            <.error_alert :if={@error} message={@error} />
          </div>
        </div>

        <.results_section :if={@results} results={@results} />
      </div>
    </Layouts.app>
    """
  end

  attr :eval, :atom, required: true
  attr :selected, :any, required: true

  defp eval_toggle(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="toggle_eval"
      phx-value-eval={@eval}
      class={[
        "px-3 py-1.5 rounded-lg text-sm font-medium transition-all duration-150",
        if(MapSet.member?(@selected, @eval),
          do: "bg-primary text-primary-content shadow-sm",
          else: "bg-base-300/50 text-base-content/70 hover:bg-base-300 hover:text-base-content"
        )
      ]}
    >
      {format_eval_name(@eval)}
    </button>
    """
  end

  attr :message, :string, required: true

  defp error_alert(assigns) do
    ~H"""
    <div class="alert alert-error">
      <.icon name="hero-exclamation-circle" class="size-5" />
      <span>{@message}</span>
    </div>
    """
  end

  attr :results, :map, required: true

  defp results_section(assigns) do
    passes = Enum.count(assigns.results, fn {_, r} -> match?({:pass, _}, r) end)
    fails = Enum.count(assigns.results, fn {_, r} -> match?({:fail, _}, r) end)
    errors = Enum.count(assigns.results, fn {_, r} -> match?({:error, _}, r) end)
    total = map_size(assigns.results)

    assigns =
      assigns
      |> assign(:passes, passes)
      |> assign(:fails, fails)
      |> assign(:errors, errors)
      |> assign(:total, total)

    ~H"""
    <div class="card bg-base-200 shadow-sm">
      <div class="card-body p-6">
        <div class="flex items-center justify-between mb-6">
          <h2 class="text-xl font-bold flex items-center gap-2">
            <.icon name="hero-clipboard-document-check" class="size-6 text-primary" /> Results
          </h2>
          <div class="flex items-center gap-3">
            <div :if={@passes > 0} class="flex items-center gap-1.5">
              <div class="w-2 h-2 rounded-full bg-success"></div>
              <span class="text-sm font-medium text-success">{@passes} passed</span>
            </div>
            <div :if={@fails > 0} class="flex items-center gap-1.5">
              <div class="w-2 h-2 rounded-full bg-error"></div>
              <span class="text-sm font-medium text-error">{@fails} failed</span>
            </div>
            <div :if={@errors > 0} class="flex items-center gap-1.5">
              <div class="w-2 h-2 rounded-full bg-warning"></div>
              <span class="text-sm font-medium text-warning">{@errors} errors</span>
            </div>
          </div>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-3">
          <.result_card :for={{eval, result} <- @results} eval={eval} result={result} />
        </div>
      </div>
    </div>
    """
  end

  attr :eval, :atom, required: true
  attr :result, :any, required: true

  defp result_card(assigns) do
    ~H"""
    <div class={[
      "rounded-xl p-4 border-2 transition-colors",
      result_card_classes(@result)
    ]}>
      <div class="flex items-center justify-between mb-2">
        <span class="font-semibold">{format_eval_name(@eval)}</span>
        <.result_badge result={@result} />
      </div>
      <.result_details result={@result} />
    </div>
    """
  end

  defp result_card_classes({:pass, _}), do: "bg-success/5 border-success/20"
  defp result_card_classes({:fail, _}), do: "bg-error/5 border-error/20"
  defp result_card_classes({:error, _}), do: "bg-warning/5 border-warning/20"
  defp result_card_classes(_), do: "bg-base-100 border-base-300"

  attr :result, :any, required: true

  defp result_badge(assigns) do
    ~H"""
    <span
      :if={match?({:pass, _}, @result)}
      class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold bg-success/20 text-success"
    >
      <.icon name="hero-check-circle-solid" class="size-3.5" /> PASS
    </span>
    <span
      :if={match?({:fail, _}, @result)}
      class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold bg-error/20 text-error"
    >
      <.icon name="hero-x-circle-solid" class="size-3.5" /> FAIL
    </span>
    <span
      :if={match?({:error, _}, @result)}
      class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold bg-warning/20 text-warning"
    >
      <.icon name="hero-exclamation-triangle-solid" class="size-3.5" /> ERROR
    </span>
    """
  end

  attr :result, :any, required: true

  defp result_details(assigns) do
    ~H"""
    <div :if={match?({:pass, _}, @result)} class="text-sm text-base-content/60">
      <span :if={is_map(elem(@result, 1)) && Map.has_key?(elem(@result, 1), :score)}>
        Score: {Float.round(elem(@result, 1).score, 2)}
      </span>
      <span :if={is_map(elem(@result, 1)) && Map.has_key?(elem(@result, 1), :reason)}>
        {elem(@result, 1).reason}
      </span>
      <span :if={
        !is_map(elem(@result, 1)) or
          (!Map.has_key?(elem(@result, 1), :score) and !Map.has_key?(elem(@result, 1), :reason))
      }>
        Check passed
      </span>
    </div>
    <div :if={match?({:fail, _}, @result)} class="text-sm text-error/80">
      {format_failure(elem(@result, 1))}
    </div>
    <div :if={match?({:error, _}, @result)} class="text-sm text-warning/80">
      {elem(@result, 1)}
    </div>
    """
  end

  defp format_eval_name(eval) do
    eval
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp format_failure(details) when is_map(details) do
    Map.get(details, :reason, inspect(details))
  end

  defp format_failure(details), do: inspect(details)
end
