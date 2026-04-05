# actually_used.md — 使用実態レポート

> 調査日: 2026-04-05
> 調査対象: ~/.claude/ セッションログ (JSONL), history.jsonl, settings.json, git log (12ヶ月, 263 commits)
> 対象リポジトリ: AI-Driven-Diagnosis-Platform, Versonova, Zero-Config-CLI-Bridge, Raid-Boss-Injection

---

## 高頻度で使う（エビデンスあり）

直接invocation + ユーザー手入力 + git commitでの言及、いずれかで複数回の発火を確認。

### Skills / Commands

| 名前 | 種別 | 発火回数 | エビデンス |
|------|------|----------|-----------|
| `deploy` | Skill | 6 Skill calls + commit 22件言及 | ADDP×3, Versonova×1 で実発火。コミットに `deploy` 言及22回 |
| `ux-audit` | Skill | 4 Skill + 9 手入力 | ADDP・Claude-root で繰り返し使用。Playwright巡回の実行ログあり |
| `security-audit` | Skill | 2 Skill + 7 手入力 | ADDP で5回, git に `fix(security):` 50件。Round 1-5の連続監査サイクル |
| `spec-review` | Skill | 2 Skill + 6 手入力 | ADDP リリース前ゲートとして使用。commit 8件言及 |
| `e2e-test` | Skill | 1 Skill + 5 手入力 | ADDP・Raid-Boss で使用。E2E commit 6件 |
| `plan` | Command | 1 手入力 + PlanMode 11セッション | `/plan` 手入力1回 + EnterPlanMode多数。5つのplanファイル生成済み |
| `code-review` | Skill | 1 Skill + subagent | `/loop 60m /code-review` でXSS検出の実績あり（commit記載: 信頼度95+90） |
| `simplify` | Skill(plugin) | 1 Skill + 3 subagent | Code Quality / Efficiency / Reuse の3並列レビュー実行 |

### Agents

| 名前 | 種別 | 発火回数 | エビデンス |
|------|------|----------|-----------|
| `planner` | Agent | 1 (agentType指定) | Versonova で "Plan 3D universe migration" に使用 |
| `Explore` | Agent(組込) | 13 | 全プロジェクトでファイル探索に常用 |
| `general-purpose` | Agent(組込) | 79 | 最も多用。skill相当のタスクもこれで実行 |

### Hooks

| 名前 | イベント | 発火回数 | エビデンス |
|------|---------|----------|-----------|
| `block-no-verify` | PreToolUse:Bash | 実発火確認 | BLOCKED メッセージがセッション `610f341e` に記録 |
| `config-protection` | PreToolUse:Edit\|Write | 480+ events | WARNING 出力確認。ADDP で特に高頻度 |
| `console-warn` | PostToolUse:Edit | 480+ events | NOTE 出力確認。Edit 操作ごとに発火 |

---

## 低頻度だが重要（障害対応・初回構築・年次作業等）

月1未満だが、使えないと作業が止まる / 他に代替がないもの。

| 名前 | 種別 | 発火証拠 | 重要な理由 |
|------|------|----------|-----------|
| `ci-status` | Skill | 1 Skill call | CI失敗時の原因分析。GitHub Actionsが落ちたときにしか使わないが、代替がない |
| `stripe-debug` | Skill | 1 Skill call | Stripe Webhook障害のデバッグ。障害時にしか使わないが課金に直結 |
| `tdd` | Command | subagent "TDD" + commit 2件 | Versonova guardrails TDDで使用。新機能の初回構築時に発動 |
| `build-fix` | Command | subagent経由 + commit内 `build-fix` 48参照 | ビルド壊れたときの修復。日常では不要だが壊れたら必須 |
| `commit-push-pr` | Skill(plugin) | 1 Skill call | ADDP でPR作成に使用。リリース時のみ |
| `onboard` | Command | 0 直接発火 | 新リポジトリの初回探索。年数回だが最初の理解構築に不可欠 |

---

## 参照専用（読んで判断に使ったが発火はしていない）

ユーザーメッセージやsubagent descriptionで言及されるが、Skill toolとしての発火記録なし。
CLAUDE.mdやメモリから参照され、判断材料として機能している。

| 名前 | 種別 | 参照回数 | 参照の形態 |
|------|------|----------|-----------|
| `verify` | Command | subagent "Versonova /verify実行" | general-purposeエージェント経由で実行。Skill発火ではない |
| `refactor` | Command | subagent "gen-diag /refactor-clean実行" | 同上。リファクタ指示の文脈で参照 |
| `review` | Command | subagent "コードレビュー" + 16参照 | code-review と重複。review 単体での発火なし |
| `quality-gate` | Command | 30参照 | Versonova feedback で言及。CI設定の判断材料として使用 |
| `image-prompts` | Command | 26参照 | 画像生成プロンプト設計の参考として言及。実発火なし（画像生成はNanobanana2で実施） |
| `architecture` | Command | 5参照 | ADR作成の文脈で言及。architect agentとして独立定義あるが agentType指定での発火なし |
| `checkpoint` | Command | 9参照 | メモリに記載あるが commit での言及0、Skill発火0。概念として知っているが使っていない |
| `pr` | Command | 29参照 | commit-push-pr plugin で代替されている |

---

## 代替があるため不要（別skill/既存コマンドで代替可能）

| 名前 | 種別 | 代替手段 | 根拠 |
|------|------|----------|------|
| `review` (command) | Command | `code-review` skill + `/loop code-review` | code-review の方が信頼度スコア付きで高機能。review は発火実績なし |
| `pr` (command) | Command | `commit-push-pr` plugin + `gh pr create` 直接実行 | plugin のほうが実際に使われた。`gh` 直接実行も多い |
| `verify` (command) | Command | `quality-gate` + CI パイプライン | verify の内容は quality-gate と CI でカバー済み |
| `refactor` (command) | Command | `simplify` plugin + `refactor-cleaner` agent | simplify の3並列レビューが実際に使われた |
| `checkpoint` (command) | Command | `git stash` / `git tag` 直接実行 | 発火0。git の標準機能で十分 |
| `architect` (agent) | Agent | `planner` agent + `architecture` command | architect は read-only 制約があり planner で代替。agentType 発火0 |
| `code-reviewer` (agent) | Agent | `code-review` skill + `general-purpose` agent | agentType 指定での発火0。general-purpose で同等タスク実行 |
| `security-reviewer` (agent) | Agent | `security-audit` skill | skill の方が直接発火実績あり。agent 単体では未使用 |
| `tdd-guide` (agent) | Agent | `tdd` command + `general-purpose` agent | agentType 指定での発火0 |
| `build-error-resolver` (agent) | Agent | `build-fix` command + `general-purpose` agent | agentType 指定での発火0 |
| `refactor-cleaner` (agent) | Agent | `simplify` plugin | agentType 指定での発火0 |

---

## 未使用（上記いずれにも該当しない）

### dev-standards 内で完全未参照（プロジェクト横断で参照・発火・言及なし）

**Agents (35/40 未使用):**
`chief-of-staff`, `cpp-build-resolver`, `cpp-reviewer`, `csharp-reviewer`, `dart-build-resolver`, `database-reviewer`, `docs-lookup`, `e2e-runner`, `ecc-code-reviewer`, `flutter-reviewer`, `gan-evaluator`, `gan-generator`, `gan-planner`, `go-build-resolver`, `go-reviewer`, `harness-optimizer`, `healthcare-reviewer`, `java-build-resolver`, `java-reviewer`, `kotlin-build-resolver`, `kotlin-reviewer`, `loop-operator`, `opensource-forker`, `opensource-packager`, `opensource-sanitizer`, `performance-optimizer`, `python-reviewer`, `pytorch-build-resolver`, `refactor-cleaner`, `rust-build-resolver`, `rust-reviewer`, `typescript-reviewer`

**Commands (69/76 未使用):**
`aside`, `brainstorm`, `checkpoint`, `claw`, `context-budget`, `cpp-review`, `devfleet`, `docs`, `evolve`, `execute-plan`, `flutter-review`, `gan-build`, `gan-design`, `go-review`, `harness-audit`*, `instinct-export`, `instinct-import`, `instinct-status`, `kotlin-review`, `learn-eval`, `loop-start`, `loop-status`, `model-route`, `multi-backend`, `multi-execute`, `multi-frontend`, `multi-plan`, `multi-workflow`, `orchestrate`, `pm2`, `projects`, `prompt-optimize`, `promote`, `prp-commit`, `prp-implement`, `prp-plan`, `prp-pr`, `prp-prd`, `prune`, `python-review`, `refactor-clean`, `resume-session`, `rules-distill`, `rust-review`, `santa-loop`, `save-session`, `sessions`, `setup-pm`, `skill-create`, `skill-health`, `test-coverage`, `update-codemaps`, `update-docs`, `verify`, `write-plan`

> *`harness-audit` は commit 内で5回言及されているが、dev-standards 内の command としての発火ではなく、Claude セッション内でのアドホック実行。

**Skills (165+/170+ 未使用):**
言語別パターン (`golang-patterns`, `rust-patterns`, `python-patterns` 等)、フレームワーク別 (`django-*`, `laravel-*`, `springboot-*`, `nestjs-*`, `nuxt4-*` 等)、ドメイン別 (`healthcare-*`, `logistics-*`, `energy-procurement`, `customs-trade-compliance` 等)、エージェント制御 (`autonomous-loops`, `continuous-agent-loop`, `dispatching-parallel-agents` 等)、コンテンツ生成 (`article-writing`, `brand-voice`, `manim-video`, `remotion-video-creation` 等) — すべて発火・参照なし。

**Hooks (41/41 dev-standards版は未使用):**
`hooks.json`, `ecc-hooks.json`, `session-start.sh`, `post-edit-format.sh`, `pre-bash-safety.sh`, `session-summary.sh`, 全35 `ecc-scripts/*.js` — プロジェクトは独自の `settings.json` inline hooks を使用しており、dev-standards の hook ファイルは一切参照されていない。

**Configs (5/5 未使用):**
`ecc-mcp.json`, `ecc-hooks.json`, `claude-mem-plugin/` (3ファイル) — 全て未参照。

---

## 実際のhook結線状況（settings.json <-> スクリプト実在の照合）

### settings.json に定義されたhooks

```
~/.claude/settings.json
├── PreToolUse
│   ├── Bash       → ~/.claude/hooks/block-no-verify.sh  ✅ 実在・発火確認済み
│   └── Edit|Write → ~/.claude/hooks/config-protection.sh ✅ 実在・発火確認済み
└── PostToolUse
    └── Edit       → ~/.claude/hooks/console-warn.sh      ✅ 実在・発火確認済み
```

| Hook | スクリプト実在 | 設定との整合 | 発火実績 | 備考 |
|------|-------------|-------------|----------|------|
| `block-no-verify.sh` | ✅ | ✅ matcher=Bash | ✅ BLOCKED出力確認 | `--no-verify`, `--no-gpg-sign` をブロック |
| `config-protection.sh` | ✅ | ✅ matcher=Edit\|Write | ✅ WARNING出力確認 (480+ events) | linter/formatter設定ファイルの変更を警告 |
| `console-warn.sh` | ✅ | ✅ matcher=Edit | ✅ NOTE出力確認 (480+ events) | JS/TS の console.log 残留を警告 |

**結線の問題: なし。** 3つとも設定→スクリプト→発火が完全に一致している。

### dev-standards の hooks との比較

| dev-standards hook | ~/.claude/hooks/ に存在 | settings.json に結線 |
|---|---|---|
| `hooks.json` | ❌ | ❌ — 独自 settings.json を使用 |
| `ecc-hooks.json` | ❌ | ❌ |
| `session-start.sh` | ❌ | ❌ |
| `post-edit-format.sh` | ❌ | ❌ |
| `pre-bash-safety.sh` | ❌ | ❌ — block-no-verify.sh が類似機能を担当 |
| `session-summary.sh` | ❌ | ❌ |
| `ecc-scripts/*.js` (35個) | ❌ | ❌ |

**結論:** 実際に結線・稼働しているのは自作の3 hookのみ。dev-standards の hook は一切使われていない。

---

## 補足: 数値サマリー

| カテゴリ | dev-standards 総数 | 高頻度 | 低頻度重要 | 参照専用 | 代替不要 | 未使用 |
|---------|-------------------|--------|-----------|---------|---------|--------|
| Skills/Commands | 246+ | 8 | 6 | 8 | 11 | 234+ |
| Agents | 40 | 1(+2組込) | 0 | 1 | 6 | 35 |
| Hooks | 41 | 0 | 0 | 0 | 0 | 41 |
| 自作Hooks | 3 | 3 | 0 | 0 | 0 | 0 |

> **実使用率: dev-standards全体の約5%。** 残り95%はユーザーの現在のスタック (Next.js/Firebase/Stripe) と開発フローに合致しない汎用・他言語・他ドメイン向け定義。
