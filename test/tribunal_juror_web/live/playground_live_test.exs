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

    assert render(view) =~ "Please enter a query for Relevance or Correctness"

    view |> element("button[phx-value-eval='relevant']") |> render_click()
    view |> element("button[phx-value-eval='faithful']") |> render_click()
    view |> element("button", "Run Evaluation") |> render_click()

    assert render(view) =~ "Please enter context for Faithfulness or Hallucination"
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
