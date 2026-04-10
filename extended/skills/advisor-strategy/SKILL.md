---
name: advisor-strategy
description: 判断エスカレーション — Anthropic advisor tool + cross-vendor reviewer の運用パターン
origin: self
---

# Advisor Strategy

executor モデルが主体的に動き、判断に詰まったときだけ advisor にエスカレーションする運用パターン。

## SubAgent / Advisor / Reviewer の使い分け

| 目的 | パターン | 使うもの |
|------|---------|---------|
| 作業を分割したい | SubAgent | Agent tool (Explore/Plan/General) |
| 判断を仰ぎたい（作業中） | Advisor | advisor tool (API, 同期) |
| 品質を検証したい（作業後） | Reviewer | Codex / code-review skill (非同期) |
| 分割 + 判断 | SubAgent + Advisor | SubAgent 内で advisor を呼ぶ |

**境界ルール**: advisor = 作業中のリアルタイム判断。reviewer = 作業後の品質検証。この2つを混同しない。

## Layer 1: Anthropic Advisor Tool

### API 呼び出しパターン

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

### モデルペア互換表

advisor は **Opus 4.6 のみ**。Sonnet を advisor にすることはできない。

| Executor | Advisor |
|----------|---------|
| `claude-haiku-4-5-20251001` | `claude-opus-4-6` |
| `claude-sonnet-4-6` | `claude-opus-4-6` |
| `claude-opus-4-6` | `claude-opus-4-6` |

### max_uses 推奨値

| ユースケース | max_uses | 根拠 |
|------------|----------|------|
| コーディング | 2-3 | 初回計画 + 完了前確認。公式ベンチマークで最高効率 |
| 長いエージェントループ | 5 | 方針転換判断を含む |
| 短い Q&A | 設定不要 | advisor のオーバーヘッドが見合わない |

### caching 設定

3回以上の advisor 呼び出しが見込まれる会話で有効化。2回以下では書き込みコストが読み取り節約を上回る。

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

会話途中で caching を on/off 切り替えるとキャッシュミスが発生する。最初から設定して変えない。

### Executor システムプロンプトテンプレート

以下を executor のシステムプロンプト冒頭に配置する（公式推奨）:

```text
You have access to an `advisor` tool backed by a stronger reviewer model. It takes NO parameters — when you call advisor(), your entire conversation history is automatically forwarded.

Call advisor BEFORE substantive work — before writing, before committing to an interpretation, before building on an assumption. If the task requires orientation first (finding files, fetching a source, seeing what's there), do that, then call advisor.

Also call advisor:
- When you believe the task is complete. BEFORE this call, make your deliverable durable: write the file, save the result, commit the change.
- When stuck — errors recurring, approach not converging, results that don't fit.
- When considering a change of approach.
```

advice の扱い方（上記の直後に配置）:

```text
Give the advice serious weight. If you follow a step and it fails empirically, or you have primary-source evidence that contradicts a specific claim, adapt.

If you've already retrieved data pointing one way and the advisor points another: don't silently switch. Surface the conflict in one more advisor call.
```

コスト削減オプション（advisor 出力を ~35-45% 削減）:

```text
The advisor should respond in under 100 words and use enumerated steps, not explanations.
```

### レスポンス構造

advisor 呼び出し成功時:

```json
{
  "type": "server_tool_use",
  "id": "srvtoolu_abc123",
  "name": "advisor",
  "input": {}
}
```

→ `advisor_tool_result` が返る。`input` は常に空。executor が何を入れても advisor には届かない。

multi-turn では `advisor_tool_result` ブロックをそのまま次のリクエストに含める。advisor tool を `tools` から外す場合は `advisor_tool_result` ブロックも履歴から除去すること（400 エラー回避）。

## Beta 期間の注意

> **このセクションは GA 移行時にセクションごと削除する。**

- Beta header: `advisor-tool-2026-03-01`
- API 呼び出し: `client.beta.messages.create()` を使用
- betas パラメータ: `["advisor-tool-2026-03-01"]`
- tool type: `"advisor_20260301"`

**GA 移行時のチェックリスト:**
1. `client.beta.messages.create()` → `client.messages.create()` に変更
2. `betas` パラメータを削除
3. tool type の `_20260301` サフィックスが変更されるか確認
4. このセクションを削除

## Layer 2: Cross-vendor Reviewer

既存の GAN-Style 交差検証 (Claude Code → Codex review) の位置づけ。

```
夜間: Claude Code → feature branch にコード → PR 作成
  ↓
CI: Codex Action 自動起動 → AGENTS.md の基準でレビュー
  ↓
朝: P0 → Request Changes / P0 なし → Approve
```

これは **reviewer** であり advisor ではない。作業後の非同期品質検証。

参照: CLAUDE.md「CI/CD: Codex 連携」セクション、`.github/workflows/codex-review.yml`

## コスト見積もり

### 計算式

```
総コスト = executor コスト + advisor コスト × 呼び出し回数

executor コスト = input_tokens × executor_input_rate + output_tokens × executor_output_rate
advisor コスト  = advisor_input_tokens × opus_input_rate + advisor_output_tokens × opus_output_rate
```

advisor 出力は通常 **400-700 text tokens** (thinking 含め **1,400-1,800 tokens**)。

### ユースケース別推奨構成

| ユースケース | Executor | Advisor | Reviewer | 特徴 |
|------------|----------|---------|----------|------|
| ドキュメント処理 | Haiku | Opus | — | 低コスト、大量処理向き |
| コーディング | Sonnet | Opus | — | 品質とコストのバランス |
| コスト重視 | Haiku | なし | Codex | API advisor なし、事後レビューのみ |
| 最高品質 | Sonnet | Opus | Codex | 三重防御: 作業中 advisor + 事後 review |
| 夜間自律実行 | Sonnet | Opus (max_uses: 3) | Codex | コスト制御付き三重防御 |
