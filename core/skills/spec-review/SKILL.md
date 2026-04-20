---
name: spec-review
description: Audit the product's completeness and monetization readiness
origin: self
allowed-tools: Read, Glob, Grep, Bash(curl:*), Bash(gh:*), WebSearch
argument-hint: "focus (e.g. billing, ux, security, all) default: all"
---

Systematically audit whether the product is at a "charge-worthy" level.

## Audit items

Use the argument to narrow focus. Default is all items.

### 1. Billing flow (billing)
- [ ] Stripe Webhook is configured correctly (endpoint, event types)
- [ ] Plan purchase -> Firestore user document update works
- [ ] Per-plan feature gating works correctly (turns, answer count, image generation)
- [ ] Cancellation flow (Webhook `customer.subscription.deleted`) is handled
- [ ] Test vs production prices are separated

### 2. UX / feature completeness (ux)
- [ ] Profile screen: edit, icon change, external links (X, YouTube, Instagram, TikTok, Twitch)
- [ ] Follow feature: follow/unfollow, follower count display, follow list, notifications
- [ ] Diagnosis authoring: create -> AI dialogue -> result-type generation -> image setup -> publish
- [ ] Diagnosis taking: answer questions -> show result (show result even when unauthenticated)
- [ ] Responsive / mobile
- [ ] Analytics screen works

### 3. Error handling (errors)
- [ ] "Thinking" indicator does not drop during AI responses
- [ ] Fallback for image generation errors
- [ ] API 502/504 retry / display
- [ ] User feedback on network errors

### 4. Security (security)
- [ ] Auth-required API routes are protected
- [ ] Stripe Webhook signature verification
- [ ] Prompt injection defenses (`validatePromptContent`)
- [ ] Vertex AI safety settings (ban on celebrity / medical-diagnosis / negative-labeling output)

### 5. Admin (admin)
- [ ] Grant plans from admin screen
- [ ] User management
- [ ] Manage operator-authored diagnosis content

## Procedure

1. Scan the whole codebase with `Glob` + `Grep`
2. Verify each item at the code level (existence of implementation, edge cases)
3. If an argument like `billing` is passed, deep-dive only that item

## Output format

```
## Spec review result

**Target**: [project name]
**Overall**: Ship / Ship with conditions / Not ready

### Per-category score
| Category | Status | Completion | Blockers |
|---------|-----------|--------|------------|
| Billing | ...       | X/Y    | yes/no     |
| UX      | ...       | X/Y    | yes/no     |
| ...     | ...       | ...    | ...        |

### Blockers (release-blocking)
1. ...

### Recommended improvements (ok post-release)
1. ...

### Monetization verdict
- Can we say "worth paying for"?: yes/no
- Reason: ...
- Recommended action: ...
```
