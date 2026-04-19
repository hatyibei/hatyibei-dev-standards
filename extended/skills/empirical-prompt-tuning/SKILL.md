---
name: empirical-prompt-tuning
description: 新規/大幅改訂した skill・プロンプトを両面評価（自己申告+指示側メトリクス）で反復 tuning する。バイアス排除のため評価は別 subagent に委譲。harness adaptation: config.yaml で閾値制御 / robustness_required フラグ対応 / SCC 案件別テンプレート
origin: upstream (mizchi/chezmoi-dotfiles) + harness adaptations
license_note: upstream はライセンス明記なし（要確認 → 判明次第追記）。利用時は upstream リポジトリの最新 LICENSE を参照
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
model: opus
---

# Empirical Prompt Tuning

## Upstream 参照 URL + 差分注記

- Upstream: https://github.com/mizchi/chezmoi-dotfiles/blob/main/dot_claude/skills/empirical-prompt-tuning/SKILL.md
- 本 harness では upstream の「別 subagent に実行させ、自己申告と指示側メトリクスの両面で改善する」構造を採用する。
- 差分: 収束閾値は `config.yaml` 参照に変更し、`robustness_required` フラグ、SCC 案件テンプレート、ADR-006 / ADR-011 / ADR-012 との境界を追加する。

プロンプトの品質は書き手自身では判断しにくい。書き手が明瞭だと思う指示ほど、別の実行者には暗黙知や未定義の判断が残る。新規 skill、slash command、タスクプロンプト、CLAUDE.md 節、コード生成プロンプトを作成・大幅改訂した直後は、別 subagent に実際のシナリオで動かしてもらい、成果とメトリクスを見て反復する。

## いつ使うか

- skill / slash command / タスクプロンプトを新規作成・大幅改訂した直後
- エージェントが期待通りに動かず、原因を指示側の曖昧さに求めたいとき
- 重要度の高い指示、チーム配布プロンプト、自動化の中核プロンプトを堅牢化したいとき

使わない場面:

- 一回限りの使い捨てプロンプト
- 成功率改善ではなく、書き手の主観的な表現好みだけを反映したいとき
- 新規 subagent を dispatch できない環境

## ワークフロー

### Iteration 0: description と body の整合チェック

静的チェックなので dispatch は不要。

1. frontmatter `description` が謳う trigger / 用途を読む。
2. body が実際にカバーしている範囲を読む。
3. 乖離があれば iter 1 に入る前に description か body を合わせる。

ここを飛ばすと、subagent が description を根拠に body を好意的に補完し、実際には skill が要件を満たしていないのに評価が通る false positive が起きる。

### 1. ベースライン準備

対象プロンプトを確定し、次を用意する。

- 評価シナリオ: `config.yaml` の `scenarios.min` 以上、原則 `scenarios.recommended` 本。中央値 1 本、edge 1-2 本。
- 要件チェックリスト: シナリオごとに成果物が満たすべき要件を 3-7 項目で列挙する。精度 % = 満たした項目数 / 全項目数。

チェックリストには `[critical]` を最低 1 つ含める。成功/失敗判定が vacuous にならないよう、評価開始後に `[critical]` の付け外しをしない。

### 2. バイアス排除読み

Task tool で新規 subagent を dispatch し、白紙の実行者として対象プロンプトを読ませる。自己再読で代替しない。複数シナリオを同時実行する場合は、単一メッセージ内で複数 Agent 呼び出しを並べる。

### 3. 実行

後述の subagent 起動契約に従って、対象プロンプト、シナリオ、固定済みチェックリストを渡す。実行者は成果物を生成し、最後に自己申告レポートを返す。

### 4. 両面評価

戻り値から次を記録する。

- 実行者の自己申告: 不明瞭点、裁量補完、テンプレート適用で詰まった箇所
- 指示側の計測: 成功/失敗、精度、ステップ数、所要時間、再試行回数

判定規則:

- 成功/失敗: `[critical]` タグ付き項目が全て ○ のときのみ成功。1 つでも × または部分的なら失敗。
- 精度: ○ = 1、部分的 = 0.5、× = 0 として全項目数で割る。
- ステップ数: Task tool の usage メタ `tool_uses` をそのまま使う。Read / Grep も除外しない。
- 所要時間: Task tool の usage メタ `duration_ms` を使う。
- 再試行回数: subagent の自己申告レポートから抽出する。
- 失敗時は、どの `[critical]` 項目が落ちたかを提示フォーマットの「不明瞭点」節に 1 行添える。

### 5. 差分適用

不明瞭点を潰す最小修正を入れる。1 イテレーション 1 テーマを原則にする。関連する微修正はまとめてよいが、無関係な修正は次回に回す。

### 6. 再評価

新しい subagent で 2-5 を回す。同一 agent は前回の文脈を学習しているため再利用しない。`config.yaml` の `max_iterations` を超えない。

### 7. 収束判定

停止条件は `config.yaml` の `convergence` を参照する。

- 新規不明瞭点: 0 件
- 精度の前回比改善: `convergence.accuracy_delta_max` ポイント以下
- ステップ数の前回比変動: `convergence.steps_variation_max` % 以内
- duration の前回比変動: `convergence.duration_variation_max` % 以内
- 連続クリア回数: `convergence.consecutive_clears`

重要プロンプトや `robustness_required: true` の対象は、hold-out 条件を Harness-specific adaptations に従って強化する。

## tool_uses の相対値による構造的欠陥診断

精度だけを見ると、skill の構造欠陥が隠れる。`tool_uses` はシナリオ間の相対値として読む。

- 1 シナリオだけ他より 3-5 倍以上大きい場合、そのシナリオ向け recipe が skill 内に不足している可能性が高い。
- 全体が 1-3 tool uses なのに 1 つだけ 15+ なら、実行者が references descent や横断探索を強いられている。
- 対処は、最小完成例の inline 化、references を読む条件の明記、decision tree の整理。

精度 100% でも `tool_uses` の偏りがあれば、追加 iteration の根拠になる。

## 構造審査モード

empirical 評価ではなく、skill / プロンプトの記述整合性と明瞭性だけを確認したい場合は、構造審査モードとして明示的に分ける。

subagent への依頼には「今回は構造審査モード: 実行ではなくテキスト整合性チェック」と書く。構造審査は empirical の代替ではなく補助であり、連続クリア判定には使わない。

## subagent 起動契約

実行者に渡すプロンプトは次の形にする。

```text
あなたは <対象プロンプト名> を白紙で読む実行者です。

## 対象プロンプト
<対象プロンプトの本文を全文貼る or Read で読ませるパスを指定>

## シナリオ
<現実に起こりうる状況設定 1 段落>

## 要件チェックリスト（成果物が満たすべき項目）
1. [critical] <最低ラインに含む項目>
2. [should] <通常項目>
3. [nice-to-have] <任意項目>

## タスク
1. 対象プロンプトに従ってシナリオを実行し、成果物を生成する。
2. 終了時に下記レポート構造で返答する。

## レポート構造
- 成果物: <生成物 or 実行結果サマリ>
- 要件達成: 各項目について ○ / × / 部分的（理由付き）
- 不明瞭点: 対象プロンプトで詰まった箇所、解釈に迷った文言
- 裁量補完: 指示で決まっておらず自分の判断で埋めた箇所
- 再試行: 同じ判断をやり直した回数とその理由
```

呼び出し側はレポートから自己申告部分を抽出し、`tool_uses` / `duration_ms` を Agent tool の usage メタから取得して評価表を埋める。

## 環境制約

新規 subagent を dispatch できない環境では、本 skill は適用しない。

- 代替案 1: 親セッションのユーザーに別 Claude Code セッションを起動して依頼してもらう。
- 代替案 2: 評価を諦め、`empirical evaluation skipped: dispatch unavailable` と明示報告する。
- NG: 自己再読で代替する。

## 反復の打ち切り基準

- 収束: `config.yaml` の `convergence` に従い、連続クリアする。
- 過適合チェック: 収束判定時に hold-out シナリオを追加する。通常は `holdout.scenarios_default` 本、`robustness_required: true` は `holdout.scenarios_robustness_required` 本。
- 発散: 3 回以上 iteration しても新規不明瞭点が減らない場合、局所修正ではなく構造を書き直す。
- リソース打ち切り: `max_iterations` に達したら止め、未解決点と残リスクを出す。

## 提示フォーマット

各 iteration で次の形で記録する。

```markdown
## Iteration N

### 変更点（前回差分）
- <修正内容 1 行>

### 実行結果（シナリオ別）
| シナリオ | 成功/失敗 | 精度 | steps | duration | retries |
|---|---|---|---|---|---|
| A | ○ | 90% | 4 | 20s | 0 |
| B | × | 60% | 9 | 41s | 2 |

### 不明瞭点（今回新出）
- <シナリオ B>: [critical] 項目 N が × — <落ちた理由 1 行>
- <シナリオ A>: （新出なし）

### 裁量補完（今回新出）
- <シナリオ B>: <補完内容>

### 次の修正案
- <最小修正 1 行>

（収束判定: 連続 X 回クリア / 停止条件まであと Y 回）
```

## Red flags

| 合理化 | 実態 |
|---|---|
| 自分で読み直せば同じ効果がある | 直前に書いた文章は客観視できない。新規 subagent を dispatch する。 |
| 1 シナリオで充分 | 1 シナリオは過適合する。最低 2、できれば 3。 |
| 不明瞭点ゼロが 1 回出たから終わり | 偶然の可能性がある。連続クリアで判定する。 |
| 複数の不明瞭点を一気に潰そう | 何が効いたか分からなくなる。1 iteration 1 テーマ。 |
| メトリクスが良いから質的フィードバックは無視 | 時間短縮は説明不足のサインにもなる。質的フィードバックを主にする。 |
| 同じ subagent を使い回そう | 前回の改善を学習している。毎回新規に dispatch する。 |

## よくある失敗

- シナリオが楽すぎる / 難しすぎる: シグナルが出ない。現実の中央値 1 つ、edge 1 つを置く。
- メトリクスだけ見る: 重要な説明が削られて脆くなる。
- iteration ごとに変更多すぎ: どの修正が効いたか追えない。
- シナリオを修正に合わせて簡単にする: プロンプト改善ではなく評価のすり替えになる。

## Harness-specific adaptations

### 収束閾値の config 化

upstream では収束条件が本文に固定されている。本 harness では `extended/skills/empirical-prompt-tuning/config.yaml` を参照する。

- `convergence.accuracy_delta_max`
- `convergence.steps_variation_max`
- `convergence.duration_variation_max`
- `convergence.consecutive_clears`
- `max_iterations`

デフォルト値は upstream と一致させる。変更する場合は、プロジェクト特性に応じた tuning として扱い、値変更の根拠を iteration ログに残す。

### robustness_required フラグ

対象プロンプトまたは評価計画に `robustness_required: true` が付く場合:

- hold-out シナリオは `holdout.scenarios_robustness_required` 本必須。
- hold-out の連続クリアは `holdout.consecutive_clears_robustness_required` 回。
- SCC 案件、クライアント配布、権限・金銭・機密情報に関わるプロンプトは原則 true とする。

それ以外は `holdout.scenarios_default` 本、連続クリアは `convergence.consecutive_clears` を使う。

### SCC 案件テンプレート

SCC 案件では `extended/skills/empirical-prompt-tuning/templates/` の雛形を使い、`[critical]` / `[should]` / `[nice-to-have]` を事前固定する。

- `templates/scc-client-facing.md`: クライアント向けプロンプト
- `templates/scc-internal-tool.md`: 社内ツール向けプロンプト
- `templates/harness-skill.md`: ハーネス内 skill

### 既存 skill との使い分け

| 目的 | パターン | ADR |
|---|---|---|
| 作業を分割したい | SubAgent | ADR-006 |
| 実行時の判断を仰ぎたい | Advisor | ADR-011 Layer 1 |
| 実行時成果をレビュー | Cross-vendor Reviewer | ADR-011 Layer 2 |
| prompt/skill 自体の品質 tuning | Empirical Prompt Tuning | ADR-012 |

本 skill 内部の subagent dispatch は ADR-006 の機構を流用する。現在の参照先は `archive/unused-skills/subagent-driven-development/`。

## 関連

- upstream 参照 skill: `superpowers:writing-skills`
- upstream 参照 skill: `retrospective-codify`
- upstream 参照 skill: `superpowers:dispatching-parallel-agents`
- ハーネス内 ADR: `docs/adr/ADR-006-subagent-driven-development.md`
- ハーネス内 ADR: `docs/adr/ADR-011-advisor-strategy.md`
- ハーネス内 ADR: `docs/adr/ADR-012-empirical-prompt-tuning.md`
- subagent 機構参照: `archive/unused-skills/subagent-driven-development/`
