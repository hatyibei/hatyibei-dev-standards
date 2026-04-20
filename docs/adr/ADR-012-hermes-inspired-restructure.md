# ADR-012: hermes-agent 参考の再編

## ステータス
accepted (2026-04-20)

## コンテキスト

本リポジトリは 12 ヶ月の使用実績に基づき 330+ ファイルを 18 に絞り込んだ実績主義のハーネス (ADR-009)。
一方、参考先の [nousresearch/hermes-agent](https://github.com/nousresearch/hermes-agent) は「自己改善する AI エージェント」を志向する Python ランタイムで、次の設計美点がある:

- **責務分離**: `agent/`, `tools/`, `skills/`, `plans/`, `cron/`, `gateway/` がそれぞれ明確な役割
- **自己改善ループ**: セッションログから新 Skill が生成・改善される仕組み
- **検索**: FTS5 によるセッション横断想起
- **Personality System**: エージェント個性のパラメータ化

本リポジトリはマークダウン + シェル中心の Claude Code ハーネスであり、Python ランタイムごと移植する意味は薄い。
一方で hermes の **構造的美点と自己改善思想** は、既存の実績ベース装備を壊さずに接ぎ木できる。

## 決定

hermes-agent の構造的美点を、**既存 core/extended/archive を不可侵としたまま周辺に追加**する形で取り込む。
Python ランタイム・RL 学習基盤・ゲートウェイは移植しない。

### 4 フェーズの追加

**Phase A: 検索 / 記憶の強化**
- SQLite FTS5 で `.harness/memory/{daily,summaries,domains}` を索引化
- `tools/search/{fts-build,recall}.sh` を新設
- sqlite3 未インストール環境では grep フォールバック
- `CLAUDE.md` の Tier 4 想起を `recall.sh` 経由に改訂

**Phase B: スキル自動生成ループ**
- `tools/curation/{mine-patterns,propose-skill,promote}.sh` を新設
- `skills/_generated/` を **未検証置き場** として設置 (PR マージは P0 ブロック)
- Opus による SKILL.md ドラフト生成 → 人間レビュー → 手動昇格の semi-auto パス
- 詳細ループ定義は `agent/loop/self-improvement.md`

**Phase C: Personality / Companion 深化**
- `agent/personality/` に vane.md / traits.yml / quips/ を配置
- 既存 `.harness/companion/companion.json` は互換保持 (hatchedAt 基点)
- `tools/personality/quip.sh` で文脈依存コメント発行 (success / fail / review-p0/p1/p2 / idle)

**Phase D: 構造整理**
- `plans/`, `cron/` を新設 (hermes の対応ディレクトリを模倣)
- ADR-012 (本文書), `docs/hermes-parity.md` で意図と境界を明文化
- 共用 lib `tools/lib/claude-api.sh` を抽出し、`.harness/hooks/memory-router.sh` からも source

### 新ディレクトリ責務表

| ディレクトリ | 責務 | 不可侵 |
|-------------|------|--------|
| `core/` | 実績ベースの常時ロード装備 | ✅ 不可侵 |
| `extended/` | 参照専用の補助装備 | ✅ 不可侵 |
| `archive/` | 退避 (git history 保持) | ✅ 不可侵 |
| `.harness/hooks/` | 稼働中フック 3 本 + 記憶管理 5 本 | ✅ 不可侵 |
| `.harness/memory/` | 実データ (inbox/daily/summaries/domains/compost) | ✅ データ層不可侵 |
| `agent/` | 🆕 エージェントの振る舞い定義 (personality, loop) |  |
| `tools/` | 🆕 再利用可能な shell ユーティリティ (search/curation/personality/lib) |  |
| `skills/_generated/` | 🆕 未検証スキル候補の置き場 (PR マージ P0 ブロック) |  |
| `plans/` | 🆕 PlanMode 実装計画のアーカイブ |  |
| `cron/` | 🆕 定期実行ジョブの集約 (README + crontab.sample) |  |

## 検討した代替案

### A. 何もしない (現状維持)

- 利点: 変更コストゼロ、リスクなし
- 欠点: hermes の美点 (FTS5 検索、自己改善ループ、構造分離) を取り込めない
- 却下理由: 記憶が育っても想起が grep のままで検索性が頭打ち。スキル設計も手動オンリーで属人化

### B. hermes を丸ごと移植

- 利点: 機能最大
- 欠点: Python ランタイム、6 ゲートウェイ、Atropos RL、527 contributor の保守を引き受けることになる
- 却下理由: 本リポジトリのドメイン (Claude Code ハーネス) を超える。bash + md の軽量性が失われる

### C. 今回の採用: 接ぎ木

- 利点: 既存 core を壊さず、hermes の美点だけを吸収
- 欠点: 責務の重複 (例: `.harness/hooks/` と `tools/` の境界が一見曖昧)
- 緩和: 責務表で明文化、`.harness/` はデータ/フック層、`tools/` は CLI 層とする

## 設計制約

1. **不可侵領域**: `core/`, `extended/`, `archive/`, `.harness/hooks/`, `.harness/memory/*/` (実データ) は **内容変更禁止**
2. **ランタイム中立**: 追加スクリプトは bash + jq + sqlite3 + curl で完結。Python / Node 依存禁止
3. **LLM 自動コミット禁止**: スキル自動生成は `_generated/` で止め、人間レビュー必須
4. **Opus 呼び出しは手動のみ**: `propose-skill.sh` は cron 登録しない (コスト管理)
5. **後方互換**: `memory-router.sh` の既存挙動は変えない。lib 抽出は thin wrapper 化のみ

## 影響範囲

**新規追加 (25 ファイル)**
- `agent/personality/{vane.md, traits.yml}`
- `agent/personality/quips/{on-success, on-fail, on-review}.md`
- `agent/loop/self-improvement.md`
- `tools/lib/claude-api.sh`
- `tools/search/{fts-build.sh, recall.sh, index.schema.sql}`
- `tools/curation/{mine-patterns, propose-skill, promote}.sh`
- `tools/personality/quip.sh`
- `skills/_generated/.gitkeep`
- `plans/README.md`
- `cron/{README.md, crontab.sample}`
- `docs/adr/ADR-012-hermes-inspired-restructure.md`
- `docs/hermes-parity.md`

**更新 (6 ファイル)**
- `CLAUDE.md` — Tier 4 改訂、新ディレクトリセクション追加
- `README.md` — 新構造紹介、ADR-012 リンク
- `AGENTS.md` — `_generated/` の P0 ルール追記
- `actually_used.md` — 再編時点の不可侵領域注記
- `.gitignore` — `.harness/memory/.index/` 追加
- `.harness/hooks/memory-router.sh` — `call_claude` を `tools/lib/claude-api.sh` 経由に (動作不変)
- `.harness/companion/buddy-status.sh` — quip.sh 呼び出しをフォールバック 1 に追加

## 検証

1. **Phase A**: `bash tools/search/recall.sh "ADR-010"` で結果が出ること (grep fallback でも可)
2. **Phase B**: `bash tools/curation/mine-patterns.sh` → `.candidates/patterns-*.json` が生成、`promote.sh --audit` が動くこと
3. **Phase C**: `bash tools/personality/quip.sh {success,fail,review-p0,review-p1,review-p2,idle}` が全コンテキストで 1 行出力
4. **Phase D**: `docs/adr/ADR-012` と `docs/hermes-parity.md` が存在、`README.md` からリンクされていること
5. **回帰**: `bash .harness/hooks/memory-router.sh once` が lib 抽出後も動作すること (ANTHROPIC_API_KEY 未設定時のエラー表示含め)

## 関連 ADR

- ADR-009: Core 選定基準 — 不可侵領域の根拠
- ADR-010: 記憶管理レイヤー — FTS5 が索引化する対象
- ADR-011: アドバイザー戦略 — Haiku→Opus エスカレーションの先行実装
