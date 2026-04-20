---
name: stripe-debug
description: Debug Stripe Webhook and billing issues
origin: self
allowed-tools: Bash(stripe:*), Bash(curl:*), Read, Glob, Grep
argument-hint: "target (e.g. webhook, subscription, plan) default: webhook"
---

Investigate and debug the Stripe billing flow (Webhook, subscriptions, plan propagation).

## Known configuration

- Webhook endpoint: `https://gen-diag.com/api/stripe/webhook`
- Listened events: `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`, `invoice.payment_succeeded`, `invoice.payment_failed`, `customer.subscription.created`

## Debug flow

### Webhook debugging (webhook)

1. **Check recent events**
   ```bash
   stripe events list --limit=10
   ```

2. **Webhook delivery status**
   ```bash
   stripe webhook_endpoints list
   ```

3. **Failed event details**
   ```bash
   stripe events retrieve [EVENT_ID]
   ```

4. **Code-side check**
   - Read `src/app/api/stripe/webhook/route.ts`
   - Verify signature validation logic (`STRIPE_WEBHOOK_SECRET`)
   - Verify event handler implementation

5. **Local test**
   ```bash
   stripe listen --forward-to localhost:3000/api/stripe/webhook
   stripe trigger checkout.session.completed
   ```

### Subscription check (subscription)

1. **Customer's subscription status**
   ```bash
   stripe subscriptions list --customer=[CUSTOMER_ID] --limit=5
   ```

2. **Consistency check with Firestore**
   - Compare the plan on the Stripe side with the plan info in the Firestore user document

### Plan propagation (plan)

1. **Products & prices**
   ```bash
   stripe products list --limit=10
   stripe prices list --limit=10
   ```

2. **Consistency with code-side plan definitions**
   - Read plan definitions in `src/types/billing.ts`
   - Confirm Stripe Price IDs match the code definitions

## Output

```
## Stripe debug result

**Target**: [webhook / subscription / plan]

### Current state
- Webhook endpoint: [OK / error]
- Latest event: [event name] ([success / failure])
- Subscriptions: [active count]

### Issues found
1. ...
   - Cause: ...
   - Fix: ...

### Recommended actions
1. ...
```
