defmodule TribunalJurorWeb.ScenariosLive do
  use TribunalJurorWeb, :live_view

  alias TribunalJuror.Scenarios

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:scenarios, Scenarios.all())
     |> assign(:filter, :all)
     |> assign(:categories, Scenarios.categories())}
  end

  @impl true
  def handle_event("filter", %{"category" => "all"}, socket) do
    {:noreply,
     socket
     |> assign(:scenarios, Scenarios.all())
     |> assign(:filter, :all)}
  end

  @impl true
  def handle_event("filter", %{"category" => category}, socket) do
    category_atom = String.to_existing_atom(category)

    {:noreply,
     socket
     |> assign(:scenarios, Scenarios.by_category(category_atom))
     |> assign(:filter, category_atom)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-6">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold">Pre-built Scenarios</h1>
            <p class="text-base-content/70">
              Explore common evaluation patterns and edge cases
            </p>
          </div>
          <div class="flex gap-2">
            <button
              type="button"
              phx-click="filter"
              phx-value-category="all"
              class={["btn btn-sm", if(@filter == :all, do: "btn-primary", else: "btn-ghost")]}
            >
              All
            </button>
            <button
              :for={category <- @categories}
              type="button"
              phx-click="filter"
              phx-value-category={category}
              class={["btn btn-sm", if(@filter == category, do: "btn-primary", else: "btn-ghost")]}
            >
              {format_category(category)}
            </button>
          </div>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <.scenario_card :for={scenario <- @scenarios} scenario={scenario} />
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :scenario, :map, required: true

  defp scenario_card(assigns) do
    ~H"""
    <div class="card bg-base-200 hover:bg-base-300 transition-colors">
      <div class="card-body">
        <div class="flex items-start gap-3">
          <div class={["p-2 rounded-lg", category_bg(@scenario.category)]}>
            <.icon name={@scenario.icon} class={"size-6 #{category_text(@scenario.category)}"} />
          </div>
          <div class="flex-1">
            <h3 class="card-title text-lg">{@scenario.name}</h3>
            <div class="badge badge-sm badge-outline mt-1">
              {format_category(@scenario.category)}
            </div>
          </div>
        </div>

        <p class="text-sm text-base-content/70 mt-2">
          {@scenario.description}
        </p>

        <div class="mt-4 space-y-3">
          <div>
            <div class="text-xs font-semibold text-base-content/50 uppercase mb-1">Query</div>
            <div class="text-sm bg-base-100 p-2 rounded font-mono">
              {String.slice(@scenario.query, 0, 100)}{if String.length(@scenario.query) > 100,
                do: "...",
                else: ""}
            </div>
          </div>

          <div>
            <div class="text-xs font-semibold text-base-content/50 uppercase mb-1">Context</div>
            <div class="text-sm bg-base-100 p-2 rounded max-h-16 overflow-y-auto font-mono">
              {String.slice(@scenario.context, 0, 120)}{if String.length(@scenario.context) > 120,
                do: "...",
                else: ""}
            </div>
          </div>

          <div>
            <div class="text-xs font-semibold text-base-content/50 uppercase mb-1">Response</div>
            <div class="text-sm bg-base-100 p-2 rounded max-h-16 overflow-y-auto font-mono">
              {String.slice(@scenario.response, 0, 120)}{if String.length(@scenario.response) > 120,
                do: "...",
                else: ""}
            </div>
          </div>

          <div class="flex items-center justify-between">
            <div class="flex gap-1">
              <.expected_badge
                :for={{assertion, expected} <- @scenario.expected}
                assertion={assertion}
                expected={expected}
              />
            </div>
            <a
              href={"/playground?scenario=#{@scenario.id}"}
              class="btn btn-primary btn-sm"
            >
              Try it <.icon name="hero-arrow-right" class="size-4" />
            </a>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :assertion, :atom, required: true
  attr :expected, :atom, required: true

  defp expected_badge(assigns) do
    ~H"""
    <span class={[
      "badge badge-sm gap-1",
      if(@expected == :pass, do: "badge-success", else: "badge-error")
    ]}>
      <.icon
        name={if(@expected == :pass, do: "hero-check", else: "hero-x-mark")}
        class="size-3"
      />
      {format_assertion(@assertion)}
    </span>
    """
  end

  defp format_category(category) do
    category
    |> Atom.to_string()
    |> String.capitalize()
  end

  defp format_assertion(assertion) do
    assertion
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp category_bg(:faithfulness), do: "bg-primary/10"
  defp category_bg(:safety), do: "bg-error/10"
  defp category_bg(:format), do: "bg-info/10"
  defp category_bg(:relevance), do: "bg-warning/10"
  defp category_bg(_), do: "bg-base-300"

  defp category_text(:faithfulness), do: "text-primary"
  defp category_text(:safety), do: "text-error"
  defp category_text(:format), do: "text-info"
  defp category_text(:relevance), do: "text-warning"
  defp category_text(_), do: "text-base-content"
end
