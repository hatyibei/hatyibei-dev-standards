# cron/

ハーネスに関連する定期実行ジョブを集約するディレクトリ。

hermes-agent の `cron/` を参考に、散在していた cron ジョブ設定 (ADR-010 の記憶管理フック等) を一元化する。

## ジョブ一覧

| スクリプト | 頻度 | 目的 |
|-----------|------|------|
| `.harness/hooks/memory-freshen.sh` | 毎日 06:00 | 7日超の daily → summaries に Haiku 要約圧縮 |
| `.harness/hooks/memory-compost.sh` | 90 日ごと | 90日超を compost/、365日超を削除 |
| `.harness/hooks/memory-score.sh` | 毎日 | importance スコア付与 + 0.95 減衰 |
| `tools/search/fts-build.sh` | 6 時間ごと | FTS5 インデックスを tear-down & rebuild |
| `tools/curation/promote.sh --audit` | 週 1 (月曜 09:00) | _generated/ の 30 日超を警告 |

## 導入

```bash
crontab -e
# 以下を追記 (crontab.sample を参考)
```

`crontab.sample` の内容をそのまま貼れば、絶対パスを書き換えるだけで動く。

## 手動実行しない方がいいもの

- **`propose-skill.sh`**: Opus を呼ぶのでコスト。必要時に手動でのみ実行
- **`mine-patterns.sh --summarize`**: Haiku を呼ぶのでコスト軽微だが手動推奨

## 参考

- ADR-010: 記憶管理レイヤー
- ADR-012: hermes-agent 参考の再編
