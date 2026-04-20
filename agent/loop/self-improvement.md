# Self-Improvement Loop

hermes-agent の "skills auto-generated from sessions" 思想を、hatyibei-dev-standards に接ぎ木した半自動ループ。
LLM に無人コミットはさせない。常に人間レビューを必須の関門とする。

## ループ全体像

```
┌─────────────────────────────────────────────────────────┐
│  (1) Observe     日々の開発                              │
│  ─────────────   │                                       │
│  セッション中 → .harness/memory/inbox/                    │
│  SessionEnd   → inbox/ → daily/ (post-session.sh)        │
│  importance スコア付与 (memory-score.sh)                  │
│  Haiku 分類     → domains/ (memory-router.sh)            │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│  (2) Mine        頻出パターン抽出                         │
│  ────────                                                │
│  tools/curation/mine-patterns.sh                         │
│  直近 14 日の daily から decisions/errors/tools を集計    │
│  --summarize で Haiku がスキル候補を提案                  │
│  出力: skills/_generated/.candidates/                     │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│  (3) Propose     スキルドラフト生成                       │
│  ────────                                                │
│  tools/curation/propose-skill.sh <slug>                  │
│  Opus が既存 core/skills を few-shot に SKILL.md 生成      │
│  status: proposed でマーク                                │
│  出力: skills/_generated/YYYY-MM-DD-<slug>/               │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│  (4) Review      人間レビュー (必須)                      │
│  ────────                                                │
│  - 既存 skill との重複チェック                            │
│  - アンチパターン記述の妥当性                             │
│  - 例示コマンドの実行確認                                 │
│  - 過剰設計でないか                                       │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│  (5) Promote     extended/ → core/ へ                    │
│  ─────────                                               │
│  tools/curation/promote.sh <slug> --target extended       │
│  チェックリスト表示、手動 git add 必須                     │
│  core/ 昇格は extended/ で 3 ヶ月発火実績後                │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│  (6) Observe     使用実績を再収集                         │
│  ─────────                                               │
│  actually_used.md を四半期ごと更新                        │
│  未発火スキルは extended → _generated/ に降格または削除    │
└─────────────────────────────────────────────────────────┘
```

## 実行頻度

| ステップ | 頻度 | 自動/手動 |
|---------|------|-----------|
| (1) Observe  | 常時 | 自動 (フック) |
| (2) Mine     | 週 1 | 手動 (`mine-patterns.sh`) |
| (3) Propose  | 必要時 | 手動 (`propose-skill.sh <slug>`) |
| (4) Review   | 必要時 | **人間必須** |
| (5) Promote  | 必要時 | 手動 (`promote.sh`) |
| (6) Observe  | 四半期 | 手動 (actually_used.md 更新) |

## 禁則事項

- **LLM による自動コミット禁止**: `_generated/` から `extended/` や `core/` への移動は必ず人間が行う
- **Opus によるループ実行禁止**: `propose-skill.sh` は cron 登録しない (コスト & 品質リスク)
- **既存 Skill の上書き禁止**: 生成スキルが既存と重複したら `_generated/` で止める

## 関連

- Scripts: `tools/curation/{mine-patterns,propose-skill,promote}.sh`
- 共用 lib: `tools/lib/claude-api.sh`
- ADR: [ADR-012](../../docs/adr/ADR-012-hermes-inspired-restructure.md)
- 昇格基準: [ADR-009](../../docs/adr/ADR-009-core-selection-criteria.md)
- hermes 比較: [docs/hermes-parity.md](../../docs/hermes-parity.md)
