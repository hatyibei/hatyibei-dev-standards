-- SQLite FTS5 schema for .harness/memory/** content
-- Built by tools/search/fts-build.sh, queried by tools/search/recall.sh

CREATE VIRTUAL TABLE IF NOT EXISTS memory_fts USING fts5(
  path UNINDEXED,
  layer UNINDEXED,            -- daily | summaries | domains
  domain UNINDEXED,           -- dev | product | biz (domains/ のみ)
  date UNINDEXED,             -- YYYY-MM-DD
  importance UNINDEXED,       -- 0.0-3.0+ (memory-score.sh 準拠)
  freshness UNINDEXED,        -- fresh | summarized | composted
  content,
  tokenize = 'unicode61 remove_diacritics 2'
);

-- 再構築用: インデックス全削除
-- DELETE FROM memory_fts;
