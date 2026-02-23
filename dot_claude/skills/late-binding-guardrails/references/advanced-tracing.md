# Advanced Tracing (Appendix)

> **Note:** This is aspirational reference material. The patterns here are industry standards worth knowing about, but **not required** for Quinlan today. The Core 5 primitives (immutable ledgers, explicit scope, run envelopes, projections, judgements) can be implemented without full tracing infrastructure.

---

## Why This Matters (Eventually)

As the system grows, you'll want:

- **Distributed tracing** across services (backend → Snowflake → LLM → search)
- **LLM observability** (token usage, latency, model versions)
- **Cross-session correlation** (link agent runs across conversations)

The patterns below let you adopt these capabilities incrementally.

---

## W3C Trace Context

The [W3C Trace Context](https://www.w3.org/TR/trace-context/) standard defines how to propagate trace IDs across service boundaries.

### The `traceparent` Header

```
traceparent: 00-{trace_id}-{span_id}-{flags}
             │   │          │         │
             │   │          │         └─ 01 = sampled
             │   │          └─ 16 hex chars (this span)
             │   └─ 32 hex chars (entire trace)
             └─ version (always 00)
```

**Example:**
```
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
```

### Why It's Useful

- **Standard format** — works with any observability tool (Jaeger, Zipkin, Datadog)
- **Correlation** — link a user request to the LLM call to the Snowflake query
- **Sampling** — control what gets recorded without code changes

### Minimal Implementation (For Later)

```python
import uuid

def generate_traceparent(
    trace_id: str | None = None,
    parent_span_id: str | None = None,
) -> tuple[str, str]:
    """Generate a traceparent header and extract the span_id."""
    trace_id = trace_id or uuid.uuid4().hex
    span_id = uuid.uuid4().hex[:16]
    traceparent = f"00-{trace_id}-{span_id}-01"
    return traceparent, span_id

def parse_traceparent(header: str) -> dict:
    """Parse a traceparent header."""
    parts = header.split("-")
    return {
        "version": parts[0],
        "trace_id": parts[1],
        "span_id": parts[2],
        "flags": parts[3],
    }
```

---

## OpenTelemetry GenAI Semantic Conventions

[OpenTelemetry](https://opentelemetry.io/) has emerging conventions for LLM/GenAI operations.

### Key Attributes

| Attribute | Description |
|-----------|-------------|
| `gen_ai.system` | The AI system (e.g., "anthropic", "openai") |
| `gen_ai.request.model` | Model ID (e.g., "claude-opus-4-5") |
| `gen_ai.request.max_tokens` | Max tokens requested |
| `gen_ai.response.model` | Model that actually responded |
| `gen_ai.usage.input_tokens` | Tokens in prompt |
| `gen_ai.usage.output_tokens` | Tokens in response |

### Example Span

```json
{
  "name": "llm.chat",
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "span_id": "00f067aa0ba902b7",
  "start_time": "2025-01-13T14:30:00Z",
  "end_time": "2025-01-13T14:30:05Z",
  "attributes": {
    "gen_ai.system": "anthropic",
    "gen_ai.request.model": "claude-opus-4-5-20251101",
    "gen_ai.response.model": "claude-opus-4-5-20251101",
    "gen_ai.usage.input_tokens": 1500,
    "gen_ai.usage.output_tokens": 800
  }
}
```

### Why This Matters

- **Standardised schema** — any OTel-compatible tool can visualise your LLM calls
- **Cost tracking** — aggregate token usage across sessions
- **Debugging** — see exactly what prompt produced what response

---

## Simpler Alternative: Run Linkage

If full OTel is overkill, you can get 80% of the value with simple parent/child linkage:

```json
{
  "run_id": "run_abc123",
  "parent_run_id": "run_xyz789",
  "run_type": "llm_call",
  "inputs": {...},
  "outputs": {...}
}
```

### Query Pattern

"Show me all runs in this chain":

```python
def get_run_chain(run_id: str, runs: list[dict]) -> list[dict]:
    """Get all runs in the same chain (ancestors + descendants)."""
    runs_by_id = {r["run_id"]: r for r in runs}

    # Find root
    current = runs_by_id.get(run_id)
    while current and current.get("parent_run_id"):
        current = runs_by_id.get(current["parent_run_id"])
    root_id = current["run_id"] if current else run_id

    # Collect descendants
    chain = []
    queue = [root_id]
    while queue:
        rid = queue.pop(0)
        if rid in runs_by_id:
            chain.append(runs_by_id[rid])
            children = [r["run_id"] for r in runs if r.get("parent_run_id") == rid]
            queue.extend(children)

    return chain
```

This is sufficient for debugging without adopting full distributed tracing.

---

## Evaluation Frameworks

Several frameworks exist for LLM evaluation. These are worth knowing about when you need more than manual review:

### Categories

| Type | Purpose | Examples |
|------|---------|----------|
| **Benchmark registries** | Standardised test suites | [OpenAI Evals](https://github.com/openai/evals), [HELM](https://crfm.stanford.edu/helm/) |
| **RAG evaluation** | Retrieval + generation quality | [Ragas](https://docs.ragas.io/), [LlamaIndex evaluators](https://docs.llamaindex.ai/en/stable/module_guides/evaluating/) |
| **Observability + eval** | Combined tracing and testing | [Langfuse](https://langfuse.com/), [Braintrust](https://www.braintrust.dev/) |

### Minimum Viable Eval (For Quinlan)

You don't need a framework to start. Record eval results as events:

```json
{
  "event_type": "eval_completed",
  "subject_ref": "run:run_abc123",
  "payload": {
    "eval_type": "relevance",
    "score": 0.85,
    "evaluator": "claude-haiku",
    "criteria": "Does the response address the user's question?"
  }
}
```

This gives you:
- Queryable eval history
- Ability to compare across time
- Foundation for automated regression detection

---

## When to Adopt What

| Stage | Tracing | Eval |
|-------|---------|------|
| **Now** | `run_id` + `parent_run_id` linkage | Manual review, recorded as events |
| **10 users** | Consider W3C traceparent for cross-service | Record eval events, basic assertions |
| **100 users** | Full OTel instrumentation | Framework (Ragas, Langfuse) |
| **Production** | Distributed tracing + sampling | Continuous eval pipeline |

---

## Summary

**For now:** Use simple `run_id` + `parent_run_id` linkage. Record evals as events.

**For later:** The industry is converging on W3C Trace Context + OTel GenAI conventions. When you need distributed tracing or LLM observability dashboards, these standards will be waiting.

**The principle:** Store the right shapes now (run envelopes with linkage) so you can plug into these standards later without data migration.
