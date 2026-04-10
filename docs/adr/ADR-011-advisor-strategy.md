# ADR-011: アドバイザー戦略

## ステータス
accepted

## コンテキスト

既存の dual-model workflow は事後レビューに偏っている:
- Claude Code (executor) がコードを書き、Codex (reviewer) が PR 単位で検査する
- 作業**中**の判断エスカレーションは仕組み化されていない

Anthropic が 2026/4 に発表した advisor tool (`advisor_20260301`) は、executor モデルが作業中に同一 API リクエスト内で advisor モデルに相談するパターン。これにより:
- 小モデル主体で回しつつ、判断コストだけを高性能モデルに寄せられる
- 事後レビューでは拾えない「設計判断の誤り」を作業中に修正できる

既存の SubAgent パターン (ADR-006) とは役割が異なる:
- SubAgent = 作業分割 (並列実行)
- Advisor = 判断エスカレーション (直列相談)
- Reviewer = 事後品質検証 (非同期)

## 決定

advisor strategy を運用パターンとして定義し、`extended/` に配置する。

### 2層構成

**Layer 1 — リアルタイム advisor (Anthropic advisor tool)**

作業中に executor が判断に詰まったとき、同一 API リクエスト内で advisor に相談する。

- モデルペア互換:

| Executor | Advisor |
|----------|---------|
| Haiku 4.5 (`claude-haiku-4-5-20251001`) | Opus 4.6 (`claude-opus-4-6`) |
| Sonnet 4.6 (`claude-sonnet-4-6`) | Opus 4.6 (`claude-opus-4-6`) |
| Opus 4.6 (`claude-opus-4-6`) | Opus 4.6 (`claude-opus-4-6`) |

- `max_uses` 推奨値:
  - コーディングタスク: **2-3** (初回計画 + 完了前確認)
  - 長いエージェントループ: **5** (方針転換判断を含む)
  - 短い Q&A: **不要** (advisor のオーバーヘッドが見合わない)
- caching: 3回以上の advisor 呼び出しが見込まれる会話で有効化
- 夜間自律実行: `max_uses` でコスト上限を制御

**Layer 2 — 非同期 reviewer (Codex 等の cross-vendor 検証)**

作業完了後の PR 単位での品質検証。既存 GAN-Style 交差検証の位置づけを維持する。

- これは「advisor」ではなく「reviewer」
- advisor = 作業中のリアルタイム判断エスカレーション (同期的)
- reviewer = 作業後の品質検証 (非同期的)
- この境界を曖昧にしない

### ADR-006 (SubAgent) との関係

3つは排他ではなく、併用可能:

| パターン | 目的 | タイミング |
|---------|------|----------|
| SubAgent | 作業分割 | 並列実行 |
| Advisor | 判断エスカレーション | 作業中 (同期) |
| Reviewer | 品質検証 | 作業後 (非同期) |

例: SubAgent 内で advisor tool を呼び、完成後に Codex が review する。

### 配置

`extended/` に配置 (ADR-009 基準: 実績なし → extended スタート → 実績で core 昇格)。

## 根拠

- Anthropic advisor tool 公式ドキュメント (beta `advisor-tool-2026-03-01`)
- 既存 Codex review workflow (CLAUDE.md「CI/CD: Codex 連携」セクション)
- ADR-006 (サブエージェント駆動開発) との役割分離
- ADR-009 (Core 選定基準) の 3 層配置ルール

## 影響

- API コスト: advisor 呼び出し 1 回あたり ~1,400-1,800 tokens (thinking 含む)。executor 料金に加算
- 夜間自律実行時: `max_uses` でコスト上限を制御可能
- 実績が出たら core/ 昇格を検討 (ADR-009 の昇格パス)
- `extended/skills/` ディレクトリの新設に伴い、CLAUDE.md のファイル構造を更新
