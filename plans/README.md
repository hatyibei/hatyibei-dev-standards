# plans/

Claude Code の PlanMode で生成された実装計画のアーカイブ。
hermes-agent の `plans/` を参考にした置き場。

## 目的

- PlanMode 実行結果を git で追跡可能にする
- 後から「あのときの判断」を recall.sh で検索できるようにする
- 失敗計画も残して、再現回避の教材にする

## 命名規則

```
plans/
├── YYYY-MM-DD-<slug>.md        実行済み計画
├── YYYY-MM-DD-<slug>.md.draft  未実行のドラフト
└── archived/                   実行完了から 90 日超
```

## ライフサイクル

```
draft  → active  → executed  → archived (90日超)
  ↓         ↓          ↓
削除OK   修正可   修正禁止
```

- **draft**: まだ承認前。自由に編集可
- **active**: 実行中。修正履歴は git log で追う
- **executed**: 実行完了。原則修正禁止 (追記は OK)
- **archived**: 90 日超で `archived/` に移動。`.harness/memory/compost/` と同じ思想

## 書式 (最低限)

```markdown
---
slug: refactor-auth-layer
status: draft | active | executed | archived
created: 2026-04-20
executed_at: null
---

# <Title>

## Context
なぜこの変更が必要か

## Goals / Non-Goals

## 実装フェーズ

## 検証方法
```

## recall.sh との連携

`plans/` も将来 fts-build.sh の対象に加える予定。現状は grep ベース。

```bash
grep -rn "keyword" plans/
```

## 昇格パス

計画の中で繰り返し現れる手順は、`mine-patterns.sh` → `propose-skill.sh` で Skill 化できる。

## 関連

- `agent/loop/self-improvement.md`
- `/plan` コマンド: `core/commands/plan.md`
- ADR-012: hermes-agent 参考の再編
