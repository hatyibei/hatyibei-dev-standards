# Validation Report — Post-Refactor Smoke Test

> 実行日: 2026-04-05
> 対象コミット: dc0ce7a (refactor: 3層分離リファクタ + Codex連携レイヤー追加)

## 検証結果

| # | チェック項目 | 結果 | 修復 |
|---|-------------|------|------|
| 1 | CLAUDE.md 内の全パス参照が実在するか | PASS | — |
| 2 | hooks 関連ファイルが全て存在するか | PASS | chmod +x を適用（実行権限が欠落していた） |
| 3 | commands/*.md 内で参照している agents/*.md が存在するか | PASS | tdd.md の `agents/tdd-guide.md` 参照を削除（archive 済みのため） |
| 4 | skills/*/SKILL.md の frontmatter が正しい YAML か | PASS | 3件の `argument-hint` 値をクォートで囲む（`:` を含む値が未クォート） |
| 5 | rg で壊れた相対パス参照を全検出 | PASS | — |

## 修復した問題

### 2-1. hooks 実行権限 (severity: medium)

```
core/hooks/block-no-verify.sh   644 → 755
core/hooks/config-protection.sh 644 → 755
core/hooks/console-warn.sh      644 → 755
```

原因: Write tool でファイルを作成した際にデフォルト 644 が適用された。
`chmod +x` で修復。

### 3-1. tdd.md の壊れた agent 参照 (severity: low)

```
Before: "This command invokes the `tdd-guide` agent ... agents/tdd-guide.md"
After:  general-purpose サブエージェントへの委譲を推奨する記述に変更
```

原因: `tdd-guide` agent は actually_used.md の調査で「代替あり（general-purpose で代替）」と判定され archive/ に退避済み。
tdd.md 内の参照が残存していた。

### 4-1. YAML frontmatter の構文エラー (severity: high)

```
BROKEN: core/skills/spec-review/SKILL.md
BROKEN: core/skills/stripe-debug/SKILL.md
BROKEN: core/skills/deploy/SKILL-self.md
```

原因: `argument-hint` の値に YAML の特殊文字 `:` が含まれていたが、クォートされていなかった。

```yaml
# Before (invalid)
argument-hint: フォーカス (例: billing, ux, security, all) デフォルト: all

# After (valid)
argument-hint: "フォーカス (例: billing, ux, security, all) デフォルト: all"
```

## 検証済みファイル一覧

### CLAUDE.md パス参照 (3件)
- `./docs/adr/ADR-009-core-selection-criteria.md` — OK
- `./core/rules/core-rules.md` — OK

### Hooks (3件)
- `core/hooks/block-no-verify.sh` — exists + executable
- `core/hooks/config-protection.sh` — exists + executable
- `core/hooks/console-warn.sh` — exists + executable

### Command → Agent 参照 (1件)
- `core/commands/plan.md` → `core/agents/planner.md` — OK

### YAML Frontmatter (11件)
- `core/skills/ci-status/SKILL.md` — VALID
- `core/skills/code-review/SKILL.md` — VALID
- `core/skills/commit-push-pr/SKILL.md` — VALID
- `core/skills/deploy/SKILL.md` — VALID
- `core/skills/deploy/SKILL-self.md` — VALID
- `core/skills/e2e-test/SKILL.md` — VALID
- `core/skills/security-audit/SKILL.md` — VALID
- `core/skills/simplify/SKILL.md` — VALID
- `core/skills/spec-review/SKILL.md` — VALID
- `core/skills/stripe-debug/SKILL.md` — VALID
- `core/skills/ux-audit/SKILL.md` — VALID

### 相対パス参照 (core/ + extended/ + CLAUDE.md + AGENTS.md)
- 壊れた参照: 0件
