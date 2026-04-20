---
description: "Show Vane (companion) status"
---

# /buddy

Displays Vane's profile and status.

## Procedure

1. Read `.harness/companion/companion.json`
2. Display in the following format:

```
🦆 Vane
━━━━━━━━━━━━━━━━━━━━━━━
Personality: [personality]
Hatched:     [hatchedAt formatted human-readable]

Status:
  DEBUGGING  ████████░░  78
  PATIENCE   ██░░░░░░░░  19
  CHAOS      █████████░  92
  WISDOM     ███████░░░  65
  SNARK      ██████████  99

Mood: [mood based on time of day]
━━━━━━━━━━━━━━━━━━━━━━━
```

3. Status values are generated deterministically from the account UUID (Bones layer),
   so the exact numbers cannot be retrieved here. Show the above as reference values
   estimated from Vane's personality.

4. Mood changes by time of day (keep Japanese UI strings verbatim):
   - 0-6: 😴 zzz...
   - 6-9: 🥱 おはよ...
   - 9-12: 🦆 調子いいよ
   - 12-14: 🍙 腹減った
   - 14-18: 👀 コード見てる
   - 18-22: 🌙 そろそろ休む？
   - 22-24: 😤 まだやるの？
