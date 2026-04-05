---
name: commit-push-pr
description: コミット、プッシュ、PR作成を一括実行する
origin: plugin (commit-commands)
allowed-tools: Bash(git:*), Bash(gh:*)
---

現在の変更をコミットし、リモートにプッシュし、PRを作成する。

## 手順

1. `git status` と `git diff HEAD` で現在の変更を確認
2. `git branch --show-current` で現在のブランチを確認
3. main ブランチにいる場合は新しいブランチを作成
4. 変更内容に基づいた適切なコミットメッセージで単一コミットを作成
5. ブランチを origin にプッシュ
6. `gh pr create` でプルリクエストを作成

## ルール

- 全ステップを1つのレスポンスで実行する
- コミットメッセージは Conventional Commits 形式
- PR タイトルは70文字以内
