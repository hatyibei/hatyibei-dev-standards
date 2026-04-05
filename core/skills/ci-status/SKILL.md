---
name: ci-status
description: GitHub Actions の実行状況を確認し、失敗時は原因を分析する
origin: self
allowed-tools: Bash(gh:*), Bash(curl:*), Read, WebFetch
argument-hint: ワークフローURL or run ID (省略時は最新の実行を確認)
---

GitHub Actionsのステータスを確認し、失敗があれば原因を分析する。

## 入力

- 引数なし → `gh run list --limit=3` で最新3件を表示
- GitHub Actions URL → そのURLからrun IDを抽出して詳細確認
- run ID → 直接指定

## 手順

1. **ステータス取得**
   ```bash
   gh run view [RUN_ID] --json status,conclusion,jobs,name,createdAt,updatedAt
   ```

2. **進行中の場合**
   - 現在のステップを表示
   - 推定残り時間（過去の実行時間から）

3. **失敗の場合**
   ```bash
   gh run view [RUN_ID] --log-failed
   ```
   - 失敗したジョブ・ステップを特定
   - エラーログを解析
   - 原因を分類:
     - テスト失敗（unit / e2e）
     - ビルドエラー（TypeScript / lint）
     - 認証エラー（GCP / Firebase）
     - デプロイエラー（Cloud Build / Cloud Run）
     - 依存関係エラー（npm install）

4. **成功の場合**
   - デプロイまで含まれてたかを確認
   - `curl` で本番URLの疎通確認

## 出力

```
## CI ステータス

**リポジトリ**: [owner/repo]
**ワークフロー**: [名前]
**ステータス**: 成功 / 失敗 / 実行中
**実行時間**: [X分Y秒]
**トリガー**: push / PR #XX

### 失敗詳細（該当する場合）
| ジョブ | ステップ | エラー |
|--------|---------|--------|
| ...    | ...     | ...    |

**原因**: ...
**修正方法**: ...
```
