---
name: stripe-debug
description: Stripe Webhook・課金問題をデバッグする
origin: self
allowed-tools: Bash(stripe:*), Bash(curl:*), Read, Glob, Grep
argument-hint: "対象 (例: webhook, subscription, plan) デフォルト: webhook"
---

Stripeの課金フロー（Webhook、サブスクリプション、プラン反映）の問題を調査・デバッグする。

## 既知の設定情報

- Webhookエンドポイント: `https://gen-diag.com/api/stripe/webhook`
- リッスンイベント: `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`, `invoice.payment_succeeded`, `invoice.payment_failed`, `customer.subscription.created`

## デバッグフロー

### Webhook デバッグ (webhook)

1. **最近のイベント確認**
   ```bash
   stripe events list --limit=10
   ```

2. **Webhook配信状況**
   ```bash
   stripe webhook_endpoints list
   ```

3. **失敗イベントの詳細**
   ```bash
   stripe events retrieve [EVENT_ID]
   ```

4. **コード側の確認**
   - `src/app/api/stripe/webhook/route.ts` を読む
   - 署名検証ロジック（`STRIPE_WEBHOOK_SECRET`）の確認
   - イベントハンドラの実装確認

5. **ローカルテスト**
   ```bash
   stripe listen --forward-to localhost:3000/api/stripe/webhook
   stripe trigger checkout.session.completed
   ```

### サブスクリプション確認 (subscription)

1. **顧客のサブスク状態**
   ```bash
   stripe subscriptions list --customer=[CUSTOMER_ID] --limit=5
   ```

2. **Firestoreとの整合性チェック**
   - Stripe側のプランとFirestore側のユーザードキュメントのプラン情報を比較

### プラン反映 (plan)

1. **商品・価格一覧**
   ```bash
   stripe products list --limit=10
   stripe prices list --limit=10
   ```

2. **コード側のプラン定義との整合性**
   - `src/types/billing.ts` のプラン定義を読む
   - Stripe側のPrice IDとコード側の定義が一致しているか

## 出力

```
## Stripe デバッグ結果

**調査対象**: [webhook / subscription / plan]

### 現在の状態
- Webhookエンドポイント: [正常 / エラー]
- 最新イベント: [イベント名] ([成功 / 失敗])
- サブスクリプション: [アクティブ数]

### 発見された問題
1. ...
   - 原因: ...
   - 修正方法: ...

### 推奨アクション
1. ...
```
