# hermes-agent Parity Map

[nousresearch/hermes-agent](https://github.com/nousresearch/hermes-agent) の構成要素と、本リポジトリの対応表。
**採用 / 見送り / 代替** を分類し、「なぜ採用しないか」も明記する。

詳細な採択根拠: [ADR-012](./adr/ADR-012-hermes-inspired-restructure.md)

## 対応表

| hermes 側 | 本リポジトリ | 判定 | 備考 |
|-----------|-------------|------|------|
| `agent/` (core reasoning) | `agent/` (personality, loop) | **採用** | Python ランタイムは無し、振る舞い定義のみ |
| `skills/` (auto-generated) | `skills/_generated/` + `core/skills/` + `extended/skills/` | **採用** | 3 段階の信頼度。自動マージはしない |
| `tools/` (40+ utilities) | `tools/{lib,search,curation,personality}/` | **採用 (軽量)** | shell + sqlite のみ。Python RPC は作らない |
| `plans/` | `plans/` | **採用** | PlanMode の出力を git で追跡 |
| `cron/` | `cron/` (README + sample) | **採用 (軽量)** | ジョブ設定の一覧化のみ。スケジューラ本体は OS cron に委譲 |
| Memory (FTS5) | `.harness/memory/.index/` + `tools/search/` | **採用** | `recall.sh` で統一 CLI。grep フォールバックあり |
| MEMORY.md / USER.md | `.harness/memory/daily/` + `domains/` | **代替** | Tier 構造で層別化済み (ADR-010) |
| Personality system | `agent/personality/` + `tools/personality/quip.sh` | **採用** | "Vane" を JSON 1 ファイルから拡張 |
| Self-improvement loop | `agent/loop/self-improvement.md` + `tools/curation/` | **採用 (semi-auto)** | 人間レビュー必須。LLM 自動コミット禁止 |
| `hermes_cli/` (CLI) | Claude Code CLI | **代替** | Anthropic 公式 CLI に委ねる |
| `gateway/` (Telegram/Discord/...) | — | **見送り** | Claude Code ハーネスの責務外。Codex GitHub Action が外部連携点 |
| `tui_gateway/` | — | **見送り** | 同上 |
| `web/` | — | **見送り** | 同上 |
| `environments/` (Docker/SSH/Daytona) | — | **見送り** | ハーネス自体はユーザ環境に寄生する設計 |
| `acp_adapter/` / `acp_registry/` | — | **見送り** | Agent Communication Protocol は本スコープ外 |
| `tinker-atropos/` (RL) | — | **見送り** | 学習データ生成は hermes の研究用途特有 |
| `batch_runner.py` | — | **見送り** | 本ハーネスは対話型。バッチは CI で十分 |
| `trajectory_compressor.py` | `.harness/hooks/memory-freshen.sh` | **代替** | Haiku 要約による Tier 圧縮で実装済み |
| MCP integration | Claude Code ネイティブ | **代替** | `mcp__github__*` 等、ハーネス側で実装不要 |
| Toolset distribution | `install.sh` | **代替 (軽量)** | 他リポジトリへの Codex レイヤー導入で対応 |
| `model_tools.py` / `toolsets.py` | `core/skills/*/SKILL.md` | **代替** | Claude Code の Skill 機構で実現 |

## 採用率サマリ

- **採用 / 採用 (軽量)**: 8 項目
- **代替**: 6 項目
- **見送り**: 7 項目

## 見送り理由 (まとめ)

1. **Python ランタイム不要**: 本ハーネスは bash + md で完結する軽量性が価値
2. **ゲートウェイは範囲外**: Claude Code と Codex GitHub Action を窓口に限定
3. **RL 学習基盤不要**: モデル訓練は Anthropic 側の責務
4. **マルチ実行環境不要**: ユーザ環境に依存する設計 (これはメリット)

## 将来の再検討候補

- **ベクトル検索**: FTS5 で不十分になったら `sqlite-vss` / `hnswlib` を tools/search に追加
- **gateway 軽量版**: Slack 通知だけなら GitHub Actions + webhook で接続可能
- **trajectory analysis**: daily/ の構造化が進めば、hermes 風の自動分析を作れる

## 参考

- ADR-012: hermes-agent 参考の再編
- ADR-009: Core 選定基準 (不可侵領域の根拠)
- ADR-010: 記憶管理レイヤー
- `agent/loop/self-improvement.md`: 自己改善ループの設計
