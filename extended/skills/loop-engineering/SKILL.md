---
name: loop-engineering
description: 固定SPECに向けてエージェントを反復自走させるループの設営・運用・停止設計 (Ralph系)
origin: mofutalk SPEC-000 較正 (2026-08-12, 8 iterations) + loop-engineering 2026-08 調査
status: extended (実績が付いたら core/ 昇格)
---


エージェントを固定スペックに向けて反復自走させる開発手法（Ralph 系）の hatyibei 標準。
適用範囲: **greenfield / PoC / 自動検証が効く領域**。レガシー・本番デバッグ・
判断が本質のタスクには適用しない（原典 Huntley と 2026 実勢の一致見解）。

## 原理（3つだけ）

1. **記憶はディスク、コンテキストは使い捨て** — SPEC（北極星・不変）/ PROGRESS.md（外部記憶・
   append-only）/ git（チェックポイント）。どの周も「ディスクを読めば再開できる」
2. **fitness は機械が判定** — 単一 `check.sh`（syntax→unit→可能なら E2E smoke の層構造）。
   これが green 以外で「done」と言わせない。**check.sh とテストはエージェントの攻撃面**
   （METR 実証）なので、緩和・削除による green 化は周ごと無効とする
3. **迷ったら止まる > 推測で進む** — オーナー決定（DECISIONS.md の PENDING）は推測で
   埋めさせない。停止はループの失敗ではなく正常な出力

## プロトコル骨格

```
iteration 0:  ハーネス自己検証 (check.sh を red→green 往復、fitness の信頼性確認)
iteration N:  読む(SPEC/PROGRESS/DECISIONS) → check観測 → 最小1ギャップ選択
              → 実装+テスト → check → green時のみ git -C commit → PROGRESS追記 → 停止判定
```

### 停止条件（多層・上から評価）

| 条件 | 種別 | 人間の次アクション |
|---|---|---|
| 全AC green + `<promise>SPEC-COMPLETE</promise>` 宣言 | 正常完了（二重ゲート） | 受け入れ確認 |
| 残ACが全部オーナー決定待ち | 正常エスカレーション | DECISIONS.md に決定を記入して再start |
| 同一AC・同種エラー red 3連続 | 詰まり | 「再開」でなくギャップ分割 / SPEC 加筆 |
| 進捗なし3周（コミットもAC変化もなし） | circuit breaker | 空転原因の調査 |
| MAX_ITERATIONS (default 25) | 絶対上限 | 予算と成果の突き合わせ |

### ガードレール

- 差分上限 400行/周（超過 = 分割 or レビュー要請。レビュー不能な差分はループの失敗）
- 証拠義務: 完了主張には check.sh の exit code + pass/fail 実測値を必ず添付
- 完了前の最終検証は **fresh context の別エージェント**で（自己評価バイアス対策。
  「gap を探せ」とは指示しない — 健全でも gap を報告してくるため）
- `git -C <repo>` 必須（シェル cwd はターン間で信用しない）
- レートリミット接近時は usage-guard フック（95%検知 → 状態保存 → CronCreate 再開予約）

### SPEC の書き方（ループの品質は SPEC の質で決まる）

- AC は**スクリプトで検証可能な形**で書く（constraint）。検証不可能な願望（wish）は
  AC にせずオーナーレビュー項目として分離する
- 決まっていないことは **DECISIONS.md に PENDING で登録して AC から参照**する
  （エージェントに埋めさせない構造をSPEC側で作る）
- スコープ外を明記。placeholder 実装禁止・既存コード検索必須を指示に含める

## 教訓ログ（この標準の根拠になった実事例）

- check.sh 自体のバグをループ1周目が検出（→ iteration 0 の由来）
- cwd が別リポジトリに残ったまま git commit 未遂（→ git -C 必須の由来）
- セッション上限でワークフロー全滅 ×2（→ usage-guard フックの由来）
- 「アニメn本同梱」表記で1Action ベタ置きだった商品（→ 証拠義務・実物検品の由来）

## 参照

- 調査 raw: `mofutalk/harness/research-loop-engineering-2026-08.json`（出典URL付き）
- 実走記録: `mofutalk/PROGRESS.md`（SPEC-000, 8 iterations）
- 上位互換の外部文献: Anthropic "Effective harnesses" (2025-11) / "Harness design" (2026-03) /
  Osmani "Loop Engineering" (2026-06)
