# ループプロトコル v2

> v1 からの改訂 (2026-08-12): SPEC-000 較正の実走知見 + loop-engineering 2026-08 調査
> (`research-loop-engineering-2026-08.json`) を反映。v1 は git 履歴参照。

/loop（自己ペーシング）で回す。1回の発火 = 1イテレーション。
**1周 = fresh context 前提**: 記憶はコンテキストではなくディスク (PROGRESS.md / git / SPEC)。
コンテキストが生きていても「ディスクを読めば再開できる」状態を毎周維持する。

## 不変条件（違反したら周を無効とする）

- **I1 SPEC不変**: `specs/*.md` の AC 本文をエージェントが変更・弱体化しない（[x]化と Completion 記入のみ可）
- **I2 テスト・check.sh 改変禁止でgreen化しない**: テストの削除・弱体化・skip、check.sh の
  緩和による green は無効。green 遷移周では `git diff --stat` に tests/ と check.sh の
  緩和方向の変更が含まれないことを確認して PROGRESS に明記（テスト追加は可）
- **I3 証拠なき完了宣言禁止**: 「done」には check.sh の exit code + pass/fail 数の実測値を添える
- **I4 PENDING 決定の推測禁止**: DECISIONS.md で PENDING の事項に依存する実装はしない
- **I5 git は `git -C <repo>` で対象明示**（cwd 不信原則）。コミットは check green の周のみ

## イテレーション手順

0. （初周のみ）**ハーネス自己検証**: check.sh を一度 red→green で往復させ、fitness 自体の
   信頼性を確認する（較正 iter1 で check.sh のバグを検出した教訓）
1. PROGRESS.md・現行 SPEC・DECISIONS.md を読む
2. `./check.sh` で現状観測
3. 未達 AC から**最小の1個**を選ぶ（粒度はデフォルト1ギャップ。モデル/タスクにより緩和可、
   緩和したら PROGRESS に理由を書く）。PENDING 依存はスキップし独立 AC へ（全部 PENDING なら停止へ）
4. 実装 + その AC を検証するテスト（両方揃って1ギャップ）
5. `./check.sh` → green なら I2 確認の上 `git -C <repo> commit`（`loop(N): AC-X <要約>`）
   / red なら敗因を PROGRESS に記録
6. PROGRESS.md 追記（append-only）:
   `| N | AC-X | green/red | check秒 | 一言 |` + 必要なら Learnings / Harness Notes
7. 停止判定（上から評価）:
   - **全 AC green** → SPEC の Completion 記入 → 最終検証（下記）→ stop
   - **残 AC が全部 PENDING 待ち** → Escalations に質問を書いて stop
   - **同一 AC・同種エラーで3周連続 red** → Escalations に状況 + 試行ログ → stop
     （異種エラーは別カウント。停止後の人間アクションは「再開」でなく「ギャップ分割/SPEC加筆」）
   - **進捗なし3周**（コミットも AC 状態変化もない周が3連続）→ circuit breaker で stop
   - **周回数が MAX_ITERATIONS(25) 到達** → stop（安全機構の第一線）
   - 続行 → ScheduleWakeup（60〜120秒 / reason に次の AC）

## ガードレール

- **差分上限**: 1周の diff が 400 行を超えたら分割するか、オーナーレビュー要請を PROGRESS に書く。
  レビュー不能な巨大差分はループの失敗と定義する
- **完了の二重ゲート**: 全 AC green（機械判定）AND 最終報告に `<promise>SPEC-COMPLETE</promise>`
  を明示（宣言判定）。片方だけでは完了扱いしない
- **最終検証の分離**: 完了宣言の前に fresh context のサブエージェントで
  「正しさと要件充足のみ」を検証させる（自己評価バイアス対策。gap 探しは指示しない）
- **usage-guard 連携**: レートリミット接近通知を受けたら、状態保存 → CronCreate 再開予約 → 静止
  （~/.claude/hooks/usage-guard.sh が検知を担う）

## ハーネス改善のフィードバック

各周で「ループ自体のやりにくさ」を Harness Notes に書く。Notes が次の LOOP.md 改訂の材料。
コードの完成と同格の成果物として扱う。
