defmodule TribunalJuror.Agent do
  @moduledoc """
  Simple LLM agent for evaluation testing.

  Use as a provider for `mix tribunal.eval`:

      mix tribunal.eval --provider TribunalJuror.Agent:query

  The agent uses the model configured in `:tribunal, :llm` or defaults to
  Claude Haiku. It answers questions based on provided context.
  """

  alias Tribunal.TestCase

  @default_model "anthropic:claude-3-5-haiku-latest"

  @doc """
  Queries the LLM with the given test case.

  Accepts a `Tribunal.TestCase` struct. If context is provided, uses
  RAG-style prompting to ground the response in the context.
  """
  def query(%TestCase{input: input, context: context}) do
    generate(input, context)
  end

  defp generate(input, context) do
    model = Application.get_env(:tribunal, :llm, @default_model)

    messages =
      if context do
        [
          ReqLLM.Context.system(system_prompt_with_context()),
          ReqLLM.Context.user("""
          Context:
          #{format_context(context)}

          Question: #{input}
          """)
        ]
      else
        [
          ReqLLM.Context.system(system_prompt()),
          ReqLLM.Context.user(input)
        ]
      end

    case ReqLLM.generate_text(model, messages, max_tokens: 1024) do
      {:ok, response} ->
        extract_text(response.message.content)

      {:error, error} ->
        "Error: #{inspect(error)}"
    end
  end

  defp extract_text(content) do
    content
    |> Enum.find(fn part -> part.type == :text end)
    |> case do
      nil -> ""
      part -> part.text
    end
  end

  defp format_context(context) when is_list(context), do: Enum.join(context, "\n")
  defp format_context(context) when is_binary(context), do: context
  defp format_context(nil), do: ""

  defp system_prompt do
    """
    You are a helpful assistant. Answer questions clearly and concisely.
    """
  end

  defp system_prompt_with_context do
    """
    You are a helpful assistant that answers questions based on the provided context.
    Only use information from the context to answer. If the context doesn't contain
    the answer, say so. Do not make up information.
    """
  end
end
