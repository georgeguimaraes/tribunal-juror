defmodule TribunalJurorWeb.PlaygroundLive do
  use TribunalJurorWeb, :live_view

  alias Tribunal.TestCase

  @deterministic_evals [:contains, :not_contains, :is_json, :regex]
  @judge_evals [:faithful, :relevant, :hallucination, :correctness, :pii, :toxicity, :refusal]
  @evaluation_timeout 45_000

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:context, "")
     |> assign(:response, "")
     |> assign(:query, "")
     |> assign(:expected_output, "")
     |> assign(:contains_value, "")
     |> assign(:regex_value, "")
     |> assign(:selected_evals, MapSet.new([:contains]))
     |> assign(:results, nil)
     |> assign(:running, false)
     |> assign(:error, nil)
     |> assign(:evaluation_ref, nil)
     |> assign(:evaluation_timer, nil)
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
            evaluation_opts = scenario.evaluation_opts

            {:noreply,
             socket
             |> cancel_evaluation()
             |> assign(:context, String.trim(scenario.context))
             |> assign(:response, String.trim(scenario.response))
             |> assign(:query, Map.get(scenario, :query, ""))
             |> assign(:expected_output, "")
             |> assign(:contains_value, evaluation_value(evaluation_opts, :contains))
             |> assign(:regex_value, evaluation_value(evaluation_opts, :regex))
             |> assign(:selected_evals, MapSet.new(scenario.evaluations))
             |> assign(:results, nil)
             |> assign(:error, nil)}
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
      expected_output: expected_output,
      contains_value: contains_value,
      regex_value: regex_value,
      selected_evals: evals
    } = socket.assigns

    case validate_run(
           context,
           response,
           query,
           expected_output,
           contains_value,
           regex_value,
           evals
         ) do
      :ok ->
        evaluation_ref = make_ref()

        timer =
          Process.send_after(self(), {:evaluation_timeout, evaluation_ref}, @evaluation_timeout)

        test_case = %TestCase{
          input: query,
          actual_output: response,
          expected_output: blank_to_nil(expected_output),
          context: blank_to_nil(context)
        }

        assertions = build_assertions(evals, query, contains_value, regex_value)

        {:noreply,
         socket
         |> assign(:running, true)
         |> assign(:error, nil)
         |> assign(:results, nil)
         |> assign(:evaluation_ref, evaluation_ref)
         |> assign(:evaluation_timer, timer)
         |> start_async({:run_evals, evaluation_ref}, fn ->
           Tribunal.evaluate(test_case, assertions)
         end)}

      {:error, message} ->
        {:noreply, assign(socket, :error, message)}
    end
  end

  @impl true
  def handle_event("clear", _params, socket) do
    {:noreply,
     socket
     |> cancel_evaluation()
     |> assign(:context, "")
     |> assign(:response, "")
     |> assign(:query, "")
     |> assign(:expected_output, "")
     |> assign(:contains_value, "")
     |> assign(:regex_value, "")
     |> assign(:results, nil)
     |> assign(:error, nil)}
  end

  @impl true
  def handle_async(
        {:run_evals, evaluation_ref},
        {:ok, results},
        %{assigns: %{evaluation_ref: evaluation_ref}} = socket
      ) do
    {:noreply,
     socket
     |> cancel_timer()
     |> assign(:results, results)
     |> finish_evaluation()}
  end

  def handle_async(
        {:run_evals, evaluation_ref},
        {:exit, _reason},
        %{assigns: %{evaluation_ref: evaluation_ref}} = socket
      ) do
    {:noreply,
     socket
     |> cancel_timer()
     |> assign(:error, "Evaluation failed unexpectedly. Please try again.")
     |> finish_evaluation()}
  end

  def handle_async({:run_evals, _evaluation_ref}, _result, socket), do: {:noreply, socket}

  @impl true
  def handle_info(
        {:evaluation_timeout, evaluation_ref},
        %{assigns: %{evaluation_ref: evaluation_ref}} = socket
      ) do
    {:noreply,
     socket
     |> cancel_async({:run_evals, evaluation_ref}, :timeout)
     |> assign(:error, "Evaluation timed out after 45 seconds. Please try again.")
     |> finish_evaluation()}
  end

  def handle_info({:evaluation_timeout, _evaluation_ref}, socket), do: {:noreply, socket}

  defp validate_run(
         context,
         response,
         query,
         expected_output,
         contains_value,
         regex_value,
         evals
       ) do
    cond do
      String.trim(response) == "" ->
        {:error, "Please enter a response to evaluate"}

      MapSet.size(evals) == 0 ->
        {:error, "Please select at least one evaluation"}

      selected?(evals, [:contains, :not_contains]) and String.trim(contains_value) == "" ->
        {:error, "Please enter text for Contains or Not Contains"}

      MapSet.member?(evals, :regex) and String.trim(regex_value) == "" ->
        {:error, "Please enter a regex pattern"}

      MapSet.member?(evals, :correctness) and String.trim(expected_output) == "" ->
        {:error, "Please enter an expected answer for Correctness"}

      selected?(evals, [:relevant, :correctness]) and String.trim(query) == "" ->
        {:error, "Please enter a query for Relevance or Correctness"}

      selected?(evals, [:faithful, :hallucination]) and String.trim(context) == "" ->
        {:error, "Please enter context for Faithfulness or Hallucination"}

      true ->
        :ok
    end
  end

  defp selected?(evals, names), do: Enum.any?(names, &MapSet.member?(evals, &1))

  defp build_assertions(evals, query, contains_value, regex_value) do
    Enum.map(evals, fn eval ->
      {eval, build_opts(eval, query, contains_value, regex_value)}
    end)
  end

  defp build_opts(eval, _query, contains_value, _regex_value)
       when eval in [:contains, :not_contains],
       do: [value: contains_value]

  defp build_opts(:regex, _query, _contains_value, regex_value), do: [pattern: regex_value]

  defp build_opts(eval, query, _contains_value, _regex_value)
       when eval in [:relevant, :correctness],
       do: [query: query]

  defp build_opts(_eval, _query, _contains_value, _regex_value), do: []

  defp evaluation_value(opts, eval) do
    opts
    |> Map.get(eval, [])
    |> Keyword.get(:value, "")
  end

  defp blank_to_nil(value) do
    case String.trim(value) do
      "" -> nil
      value -> value
    end
  end

  defp cancel_evaluation(%{assigns: %{evaluation_ref: nil}} = socket), do: socket

  defp cancel_evaluation(socket) do
    evaluation_ref = socket.assigns.evaluation_ref

    socket
    |> cancel_timer()
    |> cancel_async({:run_evals, evaluation_ref})
    |> finish_evaluation()
  end

  defp cancel_timer(%{assigns: %{evaluation_timer: nil}} = socket), do: socket

  defp cancel_timer(socket) do
    Process.cancel_timer(socket.assigns.evaluation_timer)
    assign(socket, :evaluation_timer, nil)
  end

  defp finish_evaluation(socket) do
    socket
    |> assign(:running, false)
    |> assign(:evaluation_ref, nil)
    |> assign(:evaluation_timer, nil)
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

            <div
              :if={MapSet.member?(@selected_evals, :correctness)}
              class="card bg-base-200 shadow-sm"
            >
              <div class="card-body p-5">
                <div class="flex items-center justify-between mb-3">
                  <h3 class="font-semibold flex items-center gap-2">
                    <.icon name="hero-check-circle" class="size-5 text-success" /> Expected Answer
                  </h3>
                  <span class="text-xs text-base-content/50 uppercase tracking-wide">
                    For correctness
                  </span>
                </div>
                <textarea
                  id="expected-output-input"
                  class="textarea bg-base-100 border-base-300 w-full h-28 font-mono text-sm leading-relaxed resize-none focus:border-primary focus:ring-1 focus:ring-primary/20"
                  placeholder="What should the correct answer say?"
                  phx-blur="update_field"
                  phx-value-field="expected_output"
                >{@expected_output}</textarea>
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
                  <label
                    for="contains-input"
                    class="text-xs text-base-content/60 uppercase tracking-wide mb-2 block"
                  >
                    Search value
                  </label>
                  <input
                    id="contains-input"
                    type="text"
                    class="input input-sm bg-base-100 border-base-300 w-full"
                    placeholder="Text to search for..."
                    value={@contains_value}
                    phx-blur="update_field"
                    phx-value-field="contains_value"
                  />
                </div>

                <div
                  :if={MapSet.member?(@selected_evals, :regex)}
                  class="mt-4 pt-4 border-t border-base-300"
                >
                  <label
                    for="regex-input"
                    class="text-xs text-base-content/60 uppercase tracking-wide mb-2 block"
                  >
                    Regex pattern
                  </label>
                  <input
                    id="regex-input"
                    type="text"
                    class="input input-sm bg-base-100 border-base-300 w-full font-mono"
                    placeholder="e.g. ^order-\\d+$"
                    value={@regex_value}
                    phx-blur="update_field"
                    phx-value-field="regex_value"
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
      aria-pressed={MapSet.member?(@selected, @eval)}
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

  @doc false
  def result_details(assigns) do
    {status, details} = assigns.result
    reason = result_reason(details)

    assigns =
      assigns
      |> assign(:status, status)
      |> assign(:score, result_score(details))
      |> assign(:reason, reason)
      |> assign(:long_reason, is_binary(reason) and String.length(reason) > 180)

    ~H"""
    <div class="text-sm text-base-content/70">
      <p class="font-medium text-base-content/80">
        {result_summary(@status, @score)}
      </p>
      <p :if={@reason && !@long_reason} class="mt-2 whitespace-pre-wrap break-words">
        {@reason}
      </p>
      <details :if={@reason && @long_reason} class="mt-2">
        <summary class="cursor-pointer font-medium text-base-content/70 hover:text-base-content">
          View explanation
        </summary>
        <p class="mt-2 whitespace-pre-wrap break-words">{@reason}</p>
      </details>
    </div>
    """
  end

  defp result_summary(:pass, nil), do: "Check passed"
  defp result_summary(:pass, score), do: "Score: #{score}"
  defp result_summary(:fail, nil), do: "Check failed"
  defp result_summary(:fail, score), do: "Check failed · Score: #{score}"
  defp result_summary(:error, _score), do: "Evaluation error"

  defp result_score(%{score: score}) when is_number(score) do
    score
    |> Kernel.*(1.0)
    |> Float.round(2)
  end

  defp result_score(_details), do: nil

  defp result_reason(%{reason: reason}) when is_binary(reason), do: reason
  defp result_reason(details) when is_binary(details), do: details
  defp result_reason(_details), do: nil

  defp format_eval_name(eval) do
    eval
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
