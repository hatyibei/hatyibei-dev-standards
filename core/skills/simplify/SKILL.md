---
name: simplify
description: Review changed code for reuse, quality, and efficiency, then fix any issues found
origin: plugin (code-simplifier)
model: opus
---

Analyze recently changed code to improve clarity, consistency, and maintainability. Do not change behavior at all.

## Review lenses

1. **Preserve behavior**: don't change how the code runs; only improve structure
2. **Follow project conventions**: follow the coding rules in CLAUDE.md
3. **Improve clarity**:
   - Reduce unneeded complexity / nesting
   - Remove redundant code / abstractions
   - Clear variable and function names
   - Consolidate related logic
   - No nested ternaries (use switch/if-else)
   - Prefer clarity over brevity
4. **Keep balance**: avoid over-simplification
   - Don't write overly clever code that hurts maintainability
   - Keep useful abstractions
   - Prefer readability over line-count reduction

## Process

1. Identify recently changed code sections
2. Analyze room for improvement (reuse / quality / efficiency)
3. Apply best practices based on project conventions
4. Verify all behavior is unchanged
5. Document only material changes
