# hatyibei 開発標準 — Core Harness

> このハーネスは actually_used.md に基づき、12ヶ月間の使用実績があるもののみで構成されている。
> 詳細な選定根拠: [ADR-009](./docs/adr/ADR-009-core-selection-criteria.md)
>
> **二刀流構成**: Claude Code（書く側）× Codex（検査する側）
> - `CLAUDE.md` → Claude Code CLI 用（ローカル開発・夜間自律実行）
> - `AGENTS.md` → Codex 用（CI/CD レビュー・PR 自動検査）

## 基本原則

1. **Plan Before Execute**: コードを書く前に計画を立てる
2. **Test First**: テストを先に書く (RED-GREEN-REFACTOR)
3. **Verify Before Complete**: 完了宣言前にテスト通過を確認
4. **Evidence Over Claims**: 「動くはず」ではなく「動いた証拠」

## 適応的深度

タスクの複雑さで深度を判定:
- **minimal** (typo/設定変更): 直接修正 → テスト → コミット
- **standard** (機能追加/バグ修正): 計画 → TDD → レビュー → コミット
- **comprehensive** (アーキテクチャ変更): ブレスト → 設計 → 計画 → TDD → 2段階レビュー → コミット

## サブエージェント活用

- 独立タスクは並列でサブエージェントに委譲
- **推奨: `general-purpose` に具体的な指示を渡す**（専門agent定義より実績あり）
- `Explore` エージェント: 調査・検索
- `planner` エージェント: 設計・計画（唯一 agentType 指定で実績あり）
- Worktree: 隔離環境での実験
- 「調査結果に基づいて修正して」は禁止 — 具体的なファイルパス・変更内容を渡す

## コーディング規約

→ [core/rules/core-rules.md](./core/rules/core-rules.md)

## 品質ゲート（必須）

全てのコード変更で以下を通過:
1. 既存テストが全てパス
2. セキュリティチェック（認証情報の混入なし）
3. ビルド成功
4. 変更の動作確認

## 夜間自律実行モード

`--dangerously-skip-permissions` での実行時の安全設定:
- Hook 3本が自動で発火し、危険操作をブロック/警告する
- `block-no-verify.sh`: `--no-verify`, `--no-gpg-sign` を hard fail
- `config-protection.sh`: linter/formatter 設定変更を soft warn
- `console-warn.sh`: console.log 残留を soft warn
- コミットは必ず Conventional Commits 形式
- force push to main/master は禁止

## CI/CD: Codex 連携

Claude Code が書いたコードを Codex が自動レビューする GAN-Style 交差検証:

```
夜間: Claude Code → feature branch にコード → commit-push-pr で PR 作成
  ↓
CI: Codex Action 自動起動 → AGENTS.md の基準でレビュー
  ↓
朝: P0 → Request Changes / P0 なし → Approve → レビュー済み PR が待っている
```

- 認証: Codex Cloud のアカウント連携（API Key 不要、ChatGPT Plus/Pro に含まれる）
- レビュー基準: `AGENTS.md` の Review guidelines セクション（P0/P1/P2）
- 設定: `.codex/config.toml`
- 起動: PR コメントで `@codex review` or 自動レビュー ON

**各repoへの導入（1コマンド）:**
```bash
cd ~/Claude/対象プロジェクト && bash ~/Claude/hatyibei-dev-standards/install.sh
```
→ `AGENTS.md` + `.codex/config.toml` を配置。あとは Codex Cloud の設定画面でリポジトリを有効化するだけ。

## ファイル構造

```
core/                          ← 常時ロード（18ファイル）
  skills/                      ← 実発火実績のある10 skill
    deploy/                    ← 6 Skill calls, commit 22件
    ux-audit/                  ← 4 Skill + 9 手入力, Playwright巡回
    security-audit/            ← 2 Skill + 7 手入力, Round 1-5監査
    spec-review/               ← 2 Skill + 6 手入力, リリース前ゲート
    e2e-test/                  ← 1 Skill + 5 手入力
    code-review/               ← 1 Skill + subagent, XSS検出実績
    simplify/                  ← 1 Skill + 3 subagent, 3並列レビュー
    ci-status/                 ← CI障害時の原因分析
    stripe-debug/              ← Stripe Webhook障害デバッグ
    commit-push-pr/            ← PR作成・リリース時
  commands/                    ← 実発火実績のある4 command
    plan.md                    ← PlanMode 11セッション
    tdd.md                     ← TDD workflow shim
    build-fix.md               ← ビルド修復
    onboard.md                 ← 新リポジトリ探索
  agents/
    planner.md                 ← agentType指定で発火実績あり
  hooks/                       ← 自作3本（1,700+ events で稼働確認済み）
    block-no-verify.sh         ← PreToolUse:Bash (hard fail)
    config-protection.sh       ← PreToolUse:Edit|Write (soft warn)
    console-warn.sh            ← PostToolUse:Edit (soft warn)
  rules/
    core-rules.md              ← ECC guardrails + コミット規約統合

extended/                      ← 明示的に呼んだときだけロード
  commands/
    verify.md                  ← quality-gate + CI で代替可能
    refactor-clean.md          ← simplify で代替可能
    quality-gate.md            ← CI設定の判断材料
    image-prompts.md           ← 画像生成プロンプト設計
    architecture.md            ← ADR作成の文脈で参照
  agents/
    architect.md               ← planner で代替されているが参照実績あり

archive/                       ← 退避（git history 保持、削除ではない）
  unused-agents/               ← 35 agents
  unused-commands/             ← 69 commands
  unused-skills/               ← 160+ skills
  unused-hooks/                ← 41 hooks + ecc-scripts
  unused-configs/              ← 5 configs + ecc-rules
  reference-docs/              ← claude-mem, aidlc, superpowers

AGENTS.md                      ← Codex 用レビュー基準（P0/P1/P2 + セキュリティ）
.codex/config.toml             ← Codex プロジェクト設定
templates/
  AGENTS.md                    ← 各repo配布用テンプレート
install.sh                     ← 1コマンドインストーラー

docs/adr/                      ← ADR-001〜009（変更なし）
actually_used.md               ← 使用実態レポート（選定の根拠データ）
```

## extended/ の使い方

extended/ のスキルを使いたいときは、該当ファイルのパスを直接 Claude に読ませる:
```
このファイルを読んで従って: extended/commands/architecture.md
```

## 参考ADR

- ADR-001〜008: 開発ライフサイクル・TDD・メモリ・スキル・フック・サブエージェント・レビュー・品質ゲート
- [ADR-009: Core選定基準](./docs/adr/ADR-009-core-selection-criteria.md) ← **3層分離の判断根拠**
