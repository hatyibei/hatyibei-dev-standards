# ADR-009: Core選定基準

## ステータス
accepted

## コンテキスト
hatyibei-dev-standards は4つの外部リポジトリ（everything-claude-code, claude-mem, aidlc-workflows, superpowers）から170+ skills, 40 agents, 75 commands, 41 hooks を統合した。しかし12ヶ月間の使用実態調査（actually_used.md）により、実使用率は約5%であることが判明した。

## 決定
使用実態に基づき、リポジトリを core / extended / archive の3層に分離する。

### 選定基準
core に入れる基準は「失敗時コスト × 使用頻度」。

- 高頻度（月1回以上の発火実績）→ core
- 低頻度だが高損失（使えないと作業が止まる / 課金に直結）→ core
- 参照専用（発火なし、判断材料として機能）→ extended
- 代替あり（他のcoreアイテムで機能カバー可能）→ archive
- 未使用（発火・参照・言及なし）→ archive

### core 構成
Skills: 10, Commands: 4, Agents: 1, Hooks: 3 (自作), Rules: 1

### 制約の性質
行数・ファイル数制約は認知負荷削減の経験的ガードレールであり、機能欠落を招く場合は例外を認める。

## 根拠
- 12ヶ月間の使用実態データ（actually_used.md）
- セッションログ (JSONL)、git log (263 commits)、rg横断検索の3ソース照合
- 専門agentは general-purpose で代替されている実績（agentType指定発火は planner の1件のみ）
- dev-standards の hook は全41個が未使用、自作3本が稼働中（1,700+ hook events）
- 84.4% のコミットがAI Co-Authored-By 付き（Opus 152件, Sonnet 47件, Copilot 21件）

## 影響
- 初期コンテキスト量が大幅に削減される（330+ → 18 ファイル）
- 夜間自律実行時のノイズが減少する
- archive は削除ではなく退避のため、可逆性を保持する
- 新しいskillの追加は extended → core への昇格パスを経る
- プロジェクト固有のカスタマイズ（日本語化、スタック特化）は各プロジェクトの .claude/ に配置する方針を維持
