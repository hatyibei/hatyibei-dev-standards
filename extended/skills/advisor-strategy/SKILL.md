---
name: advisor-strategy
description: Decision escalation — operational pattern for Anthropic advisor tool + cross-vendor reviewer
origin: self
---

# Advisor Strategy

An operational pattern where the executor model drives the work autonomously and escalates to an advisor only when stuck on a decision.

## When to Use SubAgent / Advisor / Reviewer

| Purpose | Pattern | What to Use |
|---------|---------|-------------|
| Split up work | SubAgent | Agent tool (Explore/Plan/General) |
| Seek judgment (mid-work) | Advisor | advisor tool (API, synchronous) |
| Verify quality (post-work) | Reviewer | Codex / code-review skill (asynchronous) |
| Split + judgment | SubAgent + Advisor | Call advisor from inside a SubAgent |

**Boundary rule**: advisor = real-time judgment during work. reviewer = quality verification after work. Do not conflate the two.

## Layer 1: Anthropic Advisor Tool

### API Call Pattern

**Python:**

```python
import anthropic

client = anthropic.Anthropic()

response = client.beta.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=4096,
    betas=["advisor-tool-2026-03-01"],
    tools=[
        {
            "type": "advisor_20260301",
            "name": "advisor",
            "model": "claude-opus-4-6",
        }
    ],
    messages=[
        {"role": "user", "content": "タスクの指示..."}
    ],
)
```

**TypeScript:**

```typescript
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

const response = await client.beta.messages.create({
  model: "claude-sonnet-4-6",
  max_tokens: 4096,
  betas: ["advisor-tool-2026-03-01"],
  tools: [
    {
      type: "advisor_20260301",
      name: "advisor",
      model: "claude-opus-4-6",
    }
  ],
  messages: [
    { role: "user", content: "タスクの指示..." }
  ],
});
```

### Model Pair Compatibility

The advisor must be **Opus 4.6 only**. Sonnet cannot be used as the advisor.

| Executor | Advisor |
|----------|---------|
| `claude-haiku-4-5-20251001` | `claude-opus-4-6` |
| `claude-sonnet-4-6` | `claude-opus-4-6` |
| `claude-opus-4-6` | `claude-opus-4-6` |

### Recommended max_uses

| Use Case | max_uses | Rationale |
|----------|----------|-----------|
| Coding | 2-3 | Initial plan + pre-completion check. Highest efficiency in official benchmarks |
| Long agent loops | 5 | Includes course-correction judgments |
| Short Q&A | Not needed | Advisor overhead does not pay off |

### Caching Configuration

Enable when three or more advisor calls are expected in the conversation. With two or fewer, write cost exceeds read savings.

```python
tools=[
    {
        "type": "advisor_20260301",
        "name": "advisor",
        "model": "claude-opus-4-6",
        "caching": {"type": "ephemeral", "ttl": "5m"},
    }
]
```

Toggling caching on/off mid-conversation causes cache misses. Set it up front and do not change it.

### Executor System Prompt Template

Place the following at the top of the executor's system prompt (officially recommended):

```text
You have access to an `advisor` tool backed by a stronger reviewer model. It takes NO parameters — when you call advisor(), your entire conversation history is automatically forwarded.

Call advisor BEFORE substantive work — before writing, before committing to an interpretation, before building on an assumption. If the task requires orientation first (finding files, fetching a source, seeing what's there), do that, then call advisor.

Also call advisor:
- When you believe the task is complete. BEFORE this call, make your deliverable durable: write the file, save the result, commit the change.
- When stuck — errors recurring, approach not converging, results that don't fit.
- When considering a change of approach.
```

How to handle advice (place immediately after the above):

```text
Give the advice serious weight. If you follow a step and it fails empirically, or you have primary-source evidence that contradicts a specific claim, adapt.

If you've already retrieved data pointing one way and the advisor points another: don't silently switch. Surface the conflict in one more advisor call.
```

Cost-reduction option (cuts advisor output ~35-45%):

```text
The advisor should respond in under 100 words and use enumerated steps, not explanations.
```

### Response Structure

On a successful advisor call:

```json
{
  "type": "server_tool_use",
  "id": "srvtoolu_abc123",
  "name": "advisor",
  "input": {}
}
```

→ An `advisor_tool_result` is returned. `input` is always empty. Whatever the executor puts in will not reach the advisor.

In multi-turn flows, include the `advisor_tool_result` block as-is in the next request. If you remove the advisor tool from `tools`, also remove the `advisor_tool_result` block from history (to avoid 400 errors).

## Beta Period Notes

> **Delete this entire section upon GA transition.**

- Beta header: `advisor-tool-2026-03-01`
- API call: use `client.beta.messages.create()`
- betas parameter: `["advisor-tool-2026-03-01"]`
- tool type: `"advisor_20260301"`

**GA transition checklist:**
1. Change `client.beta.messages.create()` → `client.messages.create()`
2. Remove the `betas` parameter
3. Check whether the `_20260301` suffix on tool type changes
4. Delete this section

## Layer 2: Cross-vendor Reviewer

Position of the existing GAN-Style cross-verification (Claude Code → Codex review).

```
Night: Claude Code → code on feature branch → PR created
  ↓
CI: Codex Action auto-triggers → review per AGENTS.md criteria
  ↓
Morning: P0 → Request Changes / no P0 → Approve
```

This is a **reviewer**, not an advisor. Asynchronous quality verification after work.

Reference: CLAUDE.md "CI/CD: Codex Integration" section, `.github/workflows/codex-review.yml`

## Cost Estimation

### Formula

```
total cost = executor cost + advisor cost × number of calls

executor cost = input_tokens × executor_input_rate + output_tokens × executor_output_rate
advisor cost  = advisor_input_tokens × opus_input_rate + advisor_output_tokens × opus_output_rate
```

Advisor output is typically **400-700 text tokens** (including thinking, **1,400-1,800 tokens**).

### Recommended Configurations by Use Case

| Use Case | Executor | Advisor | Reviewer | Characteristics |
|----------|----------|---------|----------|-----------------|
| Document processing | Haiku | Opus | — | Low cost, suited for bulk processing |
| Coding | Sonnet | Opus | — | Balance of quality and cost |
| Cost-focused | Haiku | None | Codex | No API advisor, post-hoc review only |
| Highest quality | Sonnet | Opus | Codex | Triple defense: in-work advisor + post-hoc review |
| Overnight autonomous run | Sonnet | Opus (max_uses: 3) | Codex | Triple defense with cost control |
