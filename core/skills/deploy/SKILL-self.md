---
name: deploy
description: Cloud Run / Firebase へのデプロイ＆反映確認を自動化
origin: self
allowed-tools: Bash(gcloud:*), Bash(gh:*), Bash(git:*), Bash(curl:*), Read, Glob, Grep
argument-hint: 対象 (例: cloud-run, firebase, auto) デフォルト: auto
---

プロジェクトをデプロイし、本番環境への反映を確認する。

## プロジェクト判定

カレントディレクトリから自動判定:
- `cloudbuild.yaml` がある → Cloud Run デプロイ
- `firebase.json` がある → Firebase デプロイ
- 引数で `cloud-run` / `firebase` を明示指定可能

## Cloud Run デプロイフロー

1. **事前チェック**
   - `git status` でコミット漏れがないか確認（未コミットがあれば警告）
   - `npm run typecheck && npm run lint` でビルドエラーチェック

2. **ビルド送信**
   ```bash
   gcloud builds submit --config=cloudbuild.yaml --project=scale-webcoding-service
   ```

3. **ビルド監視**
   - `gcloud builds list --limit=1 --project=scale-webcoding-service` でポーリング
   - SUCCESS / FAILURE を検出するまで30秒間隔で監視（最大10分）

4. **反映確認**
   - `curl -s -o /dev/null -w "%{http_code}" https://gen-diag.com/` でステータスコード確認
   - 200が返ればデプロイ成功

5. **GitHub Actions 経由の場合**
   - `gh run list --limit=1` で最新のワークフロー実行を確認
   - `gh run watch` で完了まで監視

## Firebase デプロイフロー

1. `firebase deploy --only hosting`
2. `curl -s https://gen-diag.com/` で確認

## 結果レポート

```
## デプロイ結果

**プロジェクト**: [プロジェクト名]
**方式**: Cloud Run / Firebase
**ステータス**: 成功 / 失敗
**本番URL**: https://gen-diag.com/
**レスポンス**: HTTP [ステータスコード]
**所要時間**: [X分Y秒]

### 失敗時の詳細（該当する場合）
- エラーログ: ...
- 推定原因: ...
- 修正提案: ...
```
