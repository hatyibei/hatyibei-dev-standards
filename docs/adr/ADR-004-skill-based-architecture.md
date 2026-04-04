# ADR-004: スキルベースアーキテクチャ

## ステータス
accepted

## コンテキスト

AI エージェントの振る舞いを一貫させるには、再利用可能な「スキル」として知識と手順を構造化する必要がある。スキルは散文ではなく、振る舞いを形成するコードとして設計すべき。

## 決定

Superpowers と Everything Claude Code のスキルシステムを参考に、Markdown ベースのスキル定義を採用する。

### スキルの構造

```
skills/
  ├── <skill-name>/
  │   ├── SKILL.md          # スキル定義本体
  │   └── (補助ファイル)
```

### SKILL.md の形式

```markdown
# スキル名

## いつ使うか
トリガー条件の明示的な記述

## ワークフロー
ステップバイステップの手順

## アンチパターン
避けるべき行動

## 完了条件
このスキルが完了したとみなす基準
```

### スキルカテゴリ

| カテゴリ | 例 |
|---------|---|
| ワークフロー | brainstorming, writing-plans, executing-plans |
| 技術 | test-driven-development, systematic-debugging |
| レビュー | requesting-code-review, receiving-code-review |
| メタ | writing-skills, using-git-worktrees |

### スキルの品質基準

1. **ゼロ依存**: 外部ライブラリに依存しない
2. **コンテキストアウェア**: トリガー条件で自動活性化
3. **検証可能**: 完了条件が明確
4. **単一責務**: 1スキル = 1つの明確な目的

### スキルの出所管理

- `skills/` : キュレートされた標準スキル
- `~/.claude/skills/learned/` : 使用中に学習・進化したスキル（provenance付き）

## 根拠

- **obra/superpowers**: 14スキルの体系、SKILL.md形式、トリガーベースの自動活性化
- **affaan-m/everything-claude-code**: 156スキル、YAML frontmatter、学習スキルの出所管理
- **awslabs/aidlc-workflows**: ルールベースガバナンス、拡張可能なルールシステム

## 影響

- エージェントの振る舞いが予測可能かつ一貫する
- スキルの数が増えるとコンテキスト消費が増大（必要なスキルだけロード）
- 新規スキル追加時はレビューと実証が必要（Superpowersの94% PR拒否率に学ぶ）
