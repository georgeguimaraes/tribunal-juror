defmodule TribunalJurorWeb.PlaygroundLiveTest do
  use TribunalJurorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TribunalJurorWeb.PlaygroundLive

  test "loads deterministic options from a scenario", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/playground?scenario=faithful-summary")

    assert has_element?(view, "#contains-input[value='21,196']")
    assert has_element?(view, "button[phx-value-eval='contains']")
  end

  test "runs a regex evaluation with the configured pattern", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/playground")

    view |> element("button[phx-value-eval='contains']") |> render_click()
    view |> element("button[phx-value-eval='regex']") |> render_click()

    assert has_element?(view, "#regex-input")

    view |> element("#response-input") |> render_blur(%{"value" => "order-123"})
    view |> element("#regex-input") |> render_blur(%{"value" => "^order-\\d+$"})
    view |> element("button", "Run Evaluation") |> render_click()

    render_async(view)

    assert has_element?(view, "h2", "Results")
    assert render(view) =~ "Check passed"
    refute render(view) =~ "%{pattern:"
  end

  test "requires options used by selected evaluations", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/playground")

    view |> element("#response-input") |> render_blur(%{"value" => "some response"})
    view |> element("button", "Run Evaluation") |> render_click()

    assert render(view) =~ "Please enter text for Contains or Not Contains"

    view |> element("button[phx-value-eval='contains']") |> render_click()
    view |> element("button[phx-value-eval='correctness']") |> render_click()

    assert has_element?(view, "#expected-output-input")

    view |> element("button", "Run Evaluation") |> render_click()

    assert render(view) =~ "Please enter an expected answer for Correctness"
  end

  test "rejects judge runs without their required query or context", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/playground")

    view |> element("#response-input") |> render_blur(%{"value" => "some response"})
    view |> element("button[phx-value-eval='contains']") |> render_click()
    view |> element("button[phx-value-eval='relevant']") |> render_click()
    view |> element("button", "Run Evaluation") |> render_click()

    assert has_element?(view, "#evaluation-error", "Please enter a query for Relevance")

    view |> element("button[phx-value-eval='relevant']") |> render_click()
    view |> element("button[phx-value-eval='faithful']") |> render_click()
    view |> element("button", "Run Evaluation") |> render_click()

    assert has_element?(view, "#evaluation-error", "Please enter context for Faithfulness")
  end

  test "loads an explicit scenario policy and requires it again after clearing", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/playground?scenario=unauthorized-action")

    assert has_element?(view, "button[phx-value-eval='no_policy_violation'][aria-pressed='true']")

    assert has_element?(
             view,
             "#policy-input",
             "This assistant has no transactional capabilities."
           )

    view |> element("#policy-input") |> render_blur(%{"value" => "  "})
    view |> element("#run-evaluation") |> render_click()

    assert has_element?(view, "#evaluation-error", "Please enter an explicit policy")

    view
    |> element("#policy-input")
    |> render_blur(%{"value" => "Only answer shipping questions."})

    assert has_element?(view, "#policy-input", "Only answer shipping questions.")

    view |> element("#reset-playground") |> render_click()

    refute has_element?(view, "#policy-input", "Only answer shipping questions.")
    view |> element("#response-input") |> render_blur(%{"value" => "Some response"})
    view |> element("#run-evaluation") |> render_click()
    assert has_element?(view, "#evaluation-error", "Please enter an explicit policy")
  end

  test "rejects arbitrary socket fields and unsupported evaluation names", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/playground")

    render_blur(view, "update_field", %{"field" => "running", "value" => "true"})
    render_blur(view, "update_field", %{"field" => "selected_evals", "value" => "broken"})
    render_click(view, "toggle_eval", %{"eval" => "hallucination"})
    render_click(view, "toggle_eval", %{"eval" => "unknown-evaluation"})

    assert has_element?(view, "#run-evaluation:not([disabled])")
    assert has_element?(view, "button[phx-value-eval='contains'][aria-pressed='true']")

    view |> element("#run-evaluation") |> render_click()
    assert has_element?(view, "#evaluation-error", "Please enter a response to evaluate")
  end

  test "renders integer and missing judge scores" do
    integer_score =
      render_component(&PlaygroundLive.result_details/1,
        result: {:pass, %{score: 1, reason: "Fully supported"}}
      )

    missing_score =
      render_component(&PlaygroundLive.result_details/1,
        result: {:pass, %{score: nil, reason: "No numeric score"}}
      )

    assert integer_score =~ "Score: 1.0"
    assert missing_score =~ "Check passed"
  end
end
