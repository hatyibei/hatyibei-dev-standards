---
allowed-tools: Read, Glob, Grep, Bash(git:*), WebSearch
description: Architecture analysis, design, and ADR authoring (read-only)
argument-hint: target (e.g., "auth flow", "DB design", overview) default: overview
---

Perform architecture analysis and design. Do not write code.

## Modes

- `overview` (default) → produce an architecture map for the whole project
- topic specified → deep-dive analysis on a specific area

## Overview Mode

1. Grasp the directory structure
2. Map dependencies among major modules
3. Trace data flows
4. Identify integrations with external services

Output:
```
## Architecture Overview: [project name]

### Component Diagram
[text-based diagram]

### Data Flow
1. user request → ...

### External Dependencies
- [service name]: [purpose]

### Tech Stack
- Frontend: ...
- Backend: ...
- DB: ...
- Infra: ...
```

## Topic Mode

1. Read the current implementation of the target area
2. Compare options with Pros/Cons
3. Present a recommendation
4. Document significant decisions as ADRs

ADR format:
```
## ADR: [title]

### Context
What is the problem/challenge

### Options
1. **Option A** — Pros: ... / Cons: ...
2. **Option B** — Pros: ... / Cons: ...

### Decision
Which option and why

### Consequences
What changes as a result of this decision
```

## Rules

- Read-only. Do not create or modify source code.
- Recommendations must be grounded in observations of the actual codebase.
- Quantify trade-offs wherever possible.
