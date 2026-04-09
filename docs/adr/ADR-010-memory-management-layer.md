# ADR-010: 記憶管理レイヤー

## ステータス
accepted

## コンテキスト

ハーネスは静的コンテキスト（CLAUDE.md, SKILL.md）のみで構成されており、セッション間の学習が蓄積しない。Claude Code 組み込みの `~/.claude/projects/*/memory/` はファイルベースだが、鮮度・重要度の概念がなく、時間経過で陳腐化する。

必要なもの:
1. セッション中の学びを確実にキャプチャする仕組み
2. 時間経過に応じた圧縮・アーカイブ（コンテキスト節約）
3. 階層的なコンテキスト注入（毎回全部読むのは非効率）

## 決定

`.harness/memory/` 配下にファイルベースの記憶管理レイヤーを追加する。

### 記憶のライフサイクル

```
inbox/ (生データ)
  │  post-session.sh (SessionEnd)
  ▼
daily/ (日次ログ, Tier 2)
  │  memory-freshen.sh (cron 毎日06:00, 7日超)
  ▼
summaries/ (要約, Tier 3)
  │  memory-compost.sh (cron 90日ごと)
  ▼
compost/ (削除候補)
  │  memory-compost.sh (365日超)
  ▼
(完全削除)
```

### コンテキスト注入の階層化 (Tier 0-4)

| Tier | 対象 | 注入タイミング |
|------|------|--------------|
| 0 | 週次要約 + 昨日のログ | 朝初回のみ (Morning Briefing) |
| 1 | CLAUDE.md, skills, rules | 毎回 |
| 2 | 今日の daily/ | 毎回 |
| 3 | 直近7日の summaries/ | 毎回 |
| 4 | domains/ のオンデマンド検索 | キーワードトリガー |

### 要約生成

- Claude Haiku (claude-haiku-4-5-20251001) で日次ログを3-5箇条書きに圧縮
- API キー未設定時はヘッダ抽出のフォールバック
- 月曜に週次要約を自動生成

### 分野別記憶 (domains/)

将来のPhase 4-5で活用:
- `dev/`: 技術パターン、アーキテクチャ判断、学び
- `product/`: プロダクト固有の知識 (Versonova, gen-diag等)
- `biz/`: ビジネス・組織の知識 (SCC業務, 戦略)

## 根拠

- **thedotmack/claude-mem**: 観測キャプチャ → 要約 → 検索の3層アーキテクチャ。プログレッシブ・ディスクロージャで10xトークン節約
- **affaan-m/everything-claude-code**: 学習スキルの出所管理、continuous-learning-v2
- **ADR-003 (永続メモリシステム)**: ファイルベースメモリの基本設計。本ADRはその動的拡張
- **ADR-005 (フック駆動自動化)**: SessionEnd, cron でのバッチ処理

## 実装フェーズ

- **Phase 1-3** (本ADR): ディレクトリ構造 + フック3本 + Tier構造 ← **実装済み**
- **Phase 4** (将来): importance スコアリング (YAML frontmatter, 減衰関数)
- **Phase 5** (将来): Haiku→Opus ルーティング (confidence < 0.7 でエスカレーション)

## 影響

- メモリの実データは `.gitignore` で除外（個人の記憶はリポジトリに入れない）
- cron の設定はユーザー責任（install.sh に将来追加可能）
- Haiku API コスト: 1日あたり約$0.01-0.05（日次要約のみ）
- 記憶の陳腐化リスクは 7日→90日→365日 の段階的圧縮で緩和
