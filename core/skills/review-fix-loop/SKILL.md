---
name: review-fix-loop
description: PR/ブランチをレビュー→修正→再レビューのループで自走させ、人間が張り付かなくても完了まで走り切る
origin: self
allowed-tools: Bash(git:*), Bash(npm:*), Bash(pnpm:*), Bash(yarn:*), Read, Edit, Grep, Glob, Skill
argument-hint: PR番号 or ブランチ名（省略時は現在のブランチ）
model: opus
---

# Review-Fix Loop

並列作業で「画面に張り付く」のをやめるための自走型 skill。
PR またはブランチに対して `code-review` → 修正 → 再レビューをループし、
人間の判断が不要な限り最後まで走り切る。

参考: [Claude Codeの並列作業で「画面に張り付く」をやめるためにやったこと](https://zenn.dev/pepabo/articles/claude-code-stop-watching-parallel-work)

## When to Activate

- 夜間に PR を投げて朝には整った状態で戻ってきてほしい
- 5〜6 ペインで並列作業中、1 ペインを review-fix に回したい
- CI/Codex の指摘を一括で潰したい
- 手動レビューの前段として、機械的に潰せる指摘を先に片付けたい

## When NOT to Activate

- アーキテクチャ判断が絡む変更（`advisor-strategy` を使う）
- 初回の設計レビュー（人間が仕様と照合すべき）
- セキュリティ脆弱性の根本対応（`security-audit` skill へ）

## 自走の原則

1. **人間に問い合わせない**: 曖昧な場合は「判断保留」として記録し、処理を続ける
2. **範囲を広げない**: タスク外のリファクタ・機能追加をしない
3. **決定論的な終了条件**: ループは必ず有限回で終わる
4. **証拠を残す**: 各 iteration の findings と fix を append-only で記録

## 入力

- 引数なし → 現在のブランチに紐づく open PR を自動取得
- PR 番号 → `gh pr view <N>` で対象特定
- ブランチ名 → `gh pr list --head <branch>` で紐づく PR を取得

## 実行ループ

```
iteration = 1
MAX_ITERATIONS = 3
findings_log = []
codex_used = false  # cross-check は 1 ループで1回まで (cost制御)

while iteration <= MAX_ITERATIONS:
  1. diff = git diff origin/main...HEAD
  2. findings = run_review(diff)           # code-review skill (Claude)
  3. # Codex cross-check (optional, iteration 2 限定)
     if iteration == 2 && !codex_used && env("REVIEW_FIX_LOOP_CODEX") != "off":
       codex_findings = invoke_skill("codex-task", mode="review", target="origin/main...HEAD")
       findings = merge(findings, codex_findings)  # (rule, file, line) で dedup
       codex_used = true
  4. if no P0/P1 findings:
       break  # 収束
  5. fixable, unfixable = partition(findings)
  6. apply_fixes(fixable)
  7. run_tests()                           # 品質ゲート
  8. if tests fail:
       revert_last_fix()
       mark unfixable
       break
  9. commit(message)                       # Conventional Commits
  10. findings_log.append({iteration, findings, fixes, codex_used})
  iteration += 1

report(findings_log, unfixable)
```

### Codex cross-check の有効化

環境変数 `REVIEW_FIX_LOOP_CODEX` で制御:
- `on` (default): iteration 2 で1回だけCodexにレビュー依頼
- `off`: Claude 単独で完結 (ネットワーク不要、コスト0)
- `always`: 全 iteration で Codex 併用 (コスト高、重大PR向け)

Codex呼び出しは `codex-task` skill ([extended/skills/codex-task/SKILL.md](../../../extended/skills/codex-task/SKILL.md)) 経由。
認証失敗/rate limit 時は自動で Claude 単独にfallback、ループは継続。

### Claude と Codex のfindings マージ戦略

```
dedup_key = (rule_name, file, line_range)

for codex_f in codex_findings:
  if dedup_key(codex_f) in claude_findings:
    # 両者が指摘 → severity max、reviewers=["claude","codex"] で higher confidence
    merged.severity = max(claude_f.severity, codex_f.severity)
    merged.reviewers = ["claude", "codex"]
  else:
    # Codex 独自 → 追加、reviewers=["codex"]
    merged = codex_f
    merged.reviewers = ["codex"]
```

最終 report に **reviewers** 列を加え、両者一致の指摘は高信頼として優先処理する。

## 各ステップの詳細

### 1. Review フェーズ

`core/skills/code-review` の観点で diff をレビュー。以下を優先度付きで抽出:

- **P0** (必ず修正): セキュリティ、型エラー、テスト失敗、ビルドエラー
- **P1** (修正推奨): 命名、DRY 違反、エラーハンドリング漏れ、マジックナンバー
- **P2** (記録のみ): スタイル、コメント不足

### 2. 分類フェーズ (fixable vs unfixable)

**Fixable** — 自動修正してよいもの:
- 命名の一貫性
- 不要な複雑さの削減（`simplify` skill 相当）
- エラーハンドリング追加
- 型アノテーションの修正
- import 順序・未使用 import
- Lint/formatter の指摘

**Unfixable** — 人間判断が必要なため記録だけして続行:
- 仕様の解釈が複数あり得る指摘
- アーキテクチャ変更を要する指摘
- API の破壊的変更
- 認証・認可ロジックの変更

### 3. Fix フェーズ

1. 各 fixable finding ごとに最小 diff で修正
2. 変更は1 論理単位 = 1 コミットに分割
3. Conventional Commits 形式: `fix(scope): ...`, `refactor(scope): ...`

### 4. 品質ゲート

修正を commit する前に必ず:
- `npm test` / `pnpm test` / プロジェクト既定のテストコマンド
- ビルド（設定されていれば）
- Lint（設定されていれば）

いずれかが fail したら:
1. `git reset --soft HEAD~1` で直前の修正を戻す
2. その finding を `unfixable` に格下げして log に記録
3. ループを継続（他の finding はまだ処理できる）

### 5. 終了条件

以下のいずれかで終了:

| 条件 | 終了理由 |
|------|----------|
| P0/P1 findings が 0 件 | 収束（成功） |
| `iteration > MAX_ITERATIONS` | イテレーション上限 |
| 連続 2 回で新規 finding が出ない | 無限ループ防止 |
| テスト/ビルドが修正で復旧不能 | 人間介入要求 |

## 出力レポート

セッション終了時、ループ全体の結果を以下の形式で標準出力に出す。
ユーザーが戻ってきて一目でわかることを優先する。

```markdown
## Review-Fix Loop 完了

**対象**: PR #123 (feat: add payment flow)
**ブランチ**: feature/payment-flow
**Iterations**: 2 / 3
**結果**: 収束 ✓ / 上限到達 / 介入要求
**Codex cross-check**: 有効 (iteration 2 実施)

### 修正サマリ
| # | Iteration | Fixed | Commits | Reviewers |
|---|-----------|-------|---------|-----------|
| 1 | 1         | 4     | 2       | claude    |
| 2 | 2         | 2     | 1       | claude+codex |

### Codex 独自指摘 (Claude が見落としたもの)
- [P1] `src/payment/charge.ts:28` — Error が原因 stack trace を含まずに返される
- [P1] `src/api/webhook.ts:12` — signature 検証前に body を log している

### 両者一致指摘 (高信頼)
- [P0] `src/payment/charge.ts:45` — 認証前に user_id を信頼している

### 未対応（人間判断要求）
- [P1] `src/payment/charge.ts:42` — 3D Secure の扱いが仕様不明
- [P1] `src/api/webhook.ts:15` — Stripe バージョンの更新可否

### 次のアクション
- [ ] 上記 unfixable を人間がレビュー
- [ ] PR に "Ready for human review" ラベルを追加済み
```

## 他 skill との連携

- `code-review` を review フェーズで呼ぶ
- `simplify` を特定カテゴリの fix で呼ぶ
- 収束後に `commit-push-pr` を呼んで PR を最新状態に push

## 既知の落とし穴

- **テストがないプロジェクト**: 品質ゲート fail として扱い、修正は diff 目視で保守的に
- **大量の P2 指摘**: P2 は記録のみ。このループでは修正しない
- **CI の Codex レビューとの競合**: このループが書いた commit が CI 側 Codex Action にも再レビューされる。
  重複指摘は GAN-Style 交差検証の中核であり、それぞれ dedup すること（commit が増えすぎる）
- **ローカル Codex と CI Codex の役割分担**:
  - ローカル (この skill 内 `codex-task`): 機械的に潰せる findings を**マージ前に**解消
  - CI (`codex-review.yml`): マージ可否判断の最終ゲート、人間レビュアーの補助
  - ローカルで収束させれば CI が P0 を返す可能性が減り、merge までの rebase 回数が減る
- **並列 review-fix-loop**: 複数 PR で同時実行する場合は worktree を必ず分ける (
  `git worktree add /tmp/repo-prN feat/branch-N`)。同一 working tree での HEAD 切替は
  他ループの未 commit 変更を巻き込む。

## 記憶への記録

ループ終了時、以下を `.harness/memory/inbox/review-fix-loop-YYYY-MM-DD.md` に append:

```yaml
---
date: <today>
pr: <PR番号>
iterations: <回数>
fixed_count: <修正件数>
unfixable: <未対応件数>
importance: 1.2  # fix 系 +0.2
---

## 今回の学び
- <パターン化できる指摘があれば記録>
- <再発しそうな失敗があれば記録>
```

post-session フックが daily/ に集約する。
