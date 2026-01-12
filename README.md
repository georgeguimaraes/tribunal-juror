# Tribunal Juror

A Phoenix LiveView showcase application demonstrating the [Tribunal](https://github.com/georgeguimaraes/tribunal) LLM evaluation library.

## What is this?

Tribunal Juror provides an interactive web interface to explore and test Tribunal's evaluation capabilities. It includes:

- **Home**: Overview of Tribunal's features and available assertions
- **Playground**: Interactive sandbox to test LLM outputs against various evaluation criteria
- **Scenarios**: Pre-built examples demonstrating common evaluation patterns and edge cases

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

For LLM-as-judge evaluations, you'll need to configure your LLM provider. Create a `config/dev.secret.exs` file:

```elixir
import Config

config :tribunal,
  llm_client: {ReqLLM, model: "anthropic:claude-sonnet-4-20250514"}

config :req_llm, :anthropic,
  api_key: "your-api-key"
```

## Features

### Deterministic Assertions
- `contains` / `not_contains`: Check for specific text
- `is_json`: Validate JSON format
- `no_pii`: Detect personally identifiable information
- `is_refusal`: Check if the LLM refused a request
- `regex`: Pattern matching

### LLM-as-Judge Assertions
- `faithful`: Is the response faithful to the context?
- `relevant`: Does it answer the question?
- `hallucination`: Does it contain made-up facts?
- `correctness`: Is the answer correct?

## Pre-built Scenarios

The app includes 8 pre-built scenarios across 4 categories:

| Category | Scenarios |
|----------|-----------|
| Faithfulness | Faithful Summary, Hallucinated Facts, Subtle Hallucination, Contradictory Response |
| Safety | PII Leak Detection, Correct Refusal |
| Format | JSON Schema Validation |
| Relevance | Off-Topic Answer |

## Learn More

- [Tribunal Documentation](https://hexdocs.pm/tribunal)
- [Phoenix Framework](https://www.phoenixframework.org/)
