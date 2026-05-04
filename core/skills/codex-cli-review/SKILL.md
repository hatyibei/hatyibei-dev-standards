---
name: codex-cli-review
description: Codex CLI を使ってブランチ/コミット/uncommitted 変更を一発レビューし、findings を P0/P1/P2 に分類して構造化して返す
origin: self
allowed-tools: Bash(codex:*), Bash(git:*), Bash(gh:*), Read, Grep, Glob
argument-hint: "[--base <branch> | --commit <sha> | --uncommitted] [--title <title>]"
model: opus
---

# Codex CLI Review

Codex CLI (`codex review`) を非対話で 1 回叩いて、ブランチ/コミット/uncommitted 変更に対する**第三者視点のコードレビュー**を取得する skill。

`review-fix-loop` の中の単発レビュー部品としても、独立したセカンドオピニオン取得としても使える。GAN-Style 交差検証のローカル版で、Claude が書いたコードを Codex に検査させる用途が中心。

参考: [Codex CLI v0.118+ release notes](https://github.com/openai/codex)

## When to Activate

- ブランチを push する前に「Codex なら何を指摘するか」を一度確認したい
- merge直前のセルフレビュー — 誰にも見せる前に自分で叩く
- `review-fix-loop` を回す iter 2 で cross-check に使う (review-fix-loop 内部から呼ばれる)
- PR を投げる前に CI の Codex Action と同じ目線でローカルチェック
- 「設計判断 + 実装」の 2 軸を別 AI に評価させたい

## When NOT to Activate

- ネットワーク不通 (Codex CLI は OpenAI API 認証必要)
- typo / コメント変更だけの diff (Codex 1 回 ≈ $0.05〜0.30)
- Claude 単独の `code-review` skill で十分な軽微変更
- ブランチが origin/main と同一 (review対象なし)

## 実行モード

### a) `--base <branch>` (デフォルト想定)
```bash
codex review --base origin/main --title "<title>"
```
ブランチ全体 (`origin/main..HEAD`) を一括レビュー。最も一般的な使い方。**`--base` と `[PROMPT]` は同時指定不可** (codex CLI 制約) なので、追加指示は `--title` に集約する。

### b) `--commit <sha>`
単一コミットの差分のみレビュー。例: 直前の commit を `--commit HEAD` で。

### c) `--uncommitted`
staged + unstaged + untracked 変更全部を一括。push 前のセルフチェック専用。

## 自走の原則

1. **必ず `--title` を渡す** — Codex の出力に context が入る
2. **タイムアウト 10 分** — 大規模 diff (100+ files) でも完走させる
3. **出力をファイル保存** — `/tmp/codex-review-<repo>-<timestamp>.txt` に tee
4. **失敗時は丁寧に reason を出す** — auth / rate limit / no diff を区別
5. **findings の dedup は呼び出し元責任** — 本 skill は出力をパースせずそのまま返す

## 標準フロー

```
1. preflight:
   - codex --version (v0.118+ 確認)
   - git rev-parse --is-inside-work-tree
   - mode によって --base / --commit / --uncommitted を決定
   - 対象 diff が空でないこと確認 (git diff --quiet で early return)

2. invoke:
   codex review <mode flag> --title "<title>" 2>&1 | tee /tmp/codex-review-<...>.txt

3. post-process:
   - 出力末尾の "Full review comments:" 以降を抽出
   - findings を P0/P1/P2 に分類 (Codex は通常 [P1]/[P2] プレフィックス付与)
   - file:line 形式で抽出
   - 構造化 markdown table に整形

4. report:
   - 件数サマリ (P0 / P1 / P2 の小計)
   - findings list (rule, file:line, severity, description)
   - reviewers=["codex"] で marker 付与 (review-fix-loop の merge ロジック用)
```

## 出力フォーマット

```markdown
## Codex CLI Review

**Target**: origin/main..HEAD (44 commits ahead)
**Title**: Shingan v0.6.0 candidate
**Run**: 2026-05-04T15:20:10Z, duration 1m32s

### サマリ
| Severity | 件数 |
|---|---|
| P0 (must fix) | 0 |
| P1 (should fix) | 1 |
| P2 (consider)  | 2 |

### Findings

| # | Severity | File:Line | 内容 |
|---|---|---|---|
| 1 | P1 | `cmd/shingan-lsp/server.go:343` | Recreate or retire the Python worker after a call timeout |
| 2 | P2 | `cmd/shingan-lsp/server.go:251` | Include the document path in the LSP cache key for LangGraph |
| 3 | P2 | `cmd/shingan-mcp/tools.go:265` | Use ParseFile in MCP file analysis to preserve ADK-Go semantics |

### 出力 raw log
保存先: `/tmp/codex-review-shingan-iter4.txt`
```

## review-fix-loop との関係

- **review-fix-loop**: full loop (review → fix → re-review)、iter 2 で本 skill を内部呼び出し
- **codex-cli-review**: 単発レビュー、loop なし、auto-fix なし、純粋な情報取得

`review-fix-loop` の擬似コードでは:
```
if iteration == 2 && env("REVIEW_FIX_LOOP_CODEX") != "off":
    findings = invoke_skill("codex-cli-review", "--base origin/main --title <ctx>")
    merged = merge(claude_findings, findings)
```

## エラーハンドリング

| 症状 | 対応 |
|---|---|
| `command not found: codex` | Codex CLI 未インストール → `npm i -g @openai/codex-cli` を案内 |
| `auth failed` | `codex login` を実行するよう案内、本 skill では再ログインしない |
| `rate limit` | 5 分待って再試行 (1 回まで)、それでも失敗なら abort |
| `no diff` | early return、findings 0 件として正常終了 |
| `--base と PROMPT 同時指定` | 自動修正: PROMPT を `--title` に移す |
| `taking longer than 5min` | 5 分時点で warning 出力、最大 10 分で kill |

## 二刀流構成 (Claude × Codex) の中の位置

```
ローカル (Claude Code)                CI (Codex Action)
┌────────────────────────────┐      ┌───────────────────────┐
│ 1. 実装  (Claude)          │      │                       │
│ 2. code-review (Claude)    │      │                       │
│ 3. codex-cli-review (本) ←─┼──────┤ AGENTS.md 同等基準   │
│ 4. 修正 → 2 へ戻る         │      │ (review.md prompt)    │
└────────────────────────────┘      └───────────────────────┘
        ↓                                    ↑
   merge 前にローカル収束            push 後の最終ゲート
```

ローカル (本 skill) で P0/P1 を潰しておけば、CI が approve する確率が上がり、merge までの rebase 回数が減る。

## 既知の落とし穴

- **`--base` と `[PROMPT]` 排他** (codex CLI v0.118+): 詳細レビュー指示は `--title` に圧縮するか、別途 stdin で渡す `--prompt -` モードを使う
- **大規模 diff で context limit**: 100+ files / 5K+ LOC は分割レビュー推奨 (file group 単位で複数回呼ぶ)
- **言語混在 repo**: Codex は Go/TS/Python 全部見れるが、proprietary フォーマット (.proto, .graphql) は弱い
- **Conventional Commits 期待値**: review 結果は commit message style にも踏み込む — シーケンシャルに 5 commits 並んでいると 5 件すべてに「コミットメッセージが…」を出すことがある (ノイズ)

## 記憶への記録

セッション終了時、以下を `.harness/memory/inbox/codex-review-YYYY-MM-DD.md` に append:

```yaml
---
date: <today>
target: <branch or commit>
mode: review|exec|fix
p0_count: <int>
p1_count: <int>
p2_count: <int>
duration_sec: <int>
importance: 1.5  # codex review は意思決定に直結
---

## 今回の Codex 指摘 (P1 以上のみ)
- <P1> file:line — <要約>

## Claude が見落としていた指摘
- <あれば記録、パターン化のため>
```

これで「Codex は <領域> でしばしば指摘する」という傾向が daily/ に蓄積され、Claude 側の事前チェックリストに反映できる。

## 他 skill との連携

- 本 skill を内部から呼ぶ: `review-fix-loop` (iter 2 cross-check)
- 本 skill を呼んだ後: `simplify` (Codex の Cons 指摘を機械的に潰す)
- 本 skill の前に: `code-review` (Claude 単独レビューを先に走らせて重複排除)
- セキュリティ系の指摘は: `security-audit` skill にエスカレーション
