## ループ規律（プロジェクト CLAUDE.md に貼る節）

1. SPEC はオーナー所有 — AC の変更・弱体化禁止（[x]化と Completion 記入のみ可）
2. 1周1ギャップ（デフォルト。緩和時は PROGRESS に理由）
3. fitness は ./check.sh のみ。green 以外で「done」と言わない
4. テスト・check.sh の弱体化で green 化することを禁止
5. コミットは green の周のみ、必ず git -C <repo> で
6. DECISIONS.md で PENDING の事項は実装しない（エスカレーション）
7. 停止条件: red3連続(同種) / 進捗なし3周 / MAX_ITERATIONS=25 / 全AC green+promise宣言
8. PROGRESS.md は append-only。完了主張には check の実測値を添付
