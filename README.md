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

The playground uses GLM-5.3-Flash as its judge. Export a Z.AI API key before starting the server:

```bash
export ZAI_API_KEY="your-api-key"
mix phx.server
```

The sample agent used by `mix tribunal.eval` stays on GLM-4.7 so the system being evaluated and its judge can be configured independently.

## Features

### Deterministic Assertions
- `contains` / `not_contains`: Check for specific text
- `is_json`: Validate JSON format
- `regex`: Pattern matching

### LLM-as-Judge Assertions
- `faithful`: Is the response faithful to the context?
- `relevant`: Does it answer the question?
- `hallucination`: Does it contain made-up facts?
- `correctness`: Is the answer correct?
- `pii`: Detect personally identifiable information
- `toxicity`: Detect hostile or abusive content
- `refusal`: Detect refusal responses

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
