---
name: codex-task
description: Codex CLI に非対話で指示を投げて結果を取り込む汎用ワーカー (review / exec / apply)
origin: self
allowed-tools: Bash(codex:*), Bash(git:*), Bash(gh:*), Read, Edit, Grep, Glob
argument-hint: "<mode: review|exec|fix> <target: path or PR番号> [追加指示]"
model: opus
---

# Codex Task

Claude Code ではない**第三者視点**として Codex CLI (`codex-cli` 0.118+) に指示を投げ、結果を取り込む汎用 skill。
GAN-Style 交差検証のローカル版。CI ではなくローカル/セッション中に Codex の意見を取り込みたいときに使う。

## When to Activate

- `review-fix-loop` の中で「Claude が見落としていないか」セカンドオピニオンを取りたい
- 一人ブレスト的に別角度の実装案が欲しい
- 大規模リファクタで実装を並行して進めたい (Claude と Codex で分担)
- PR レビューで「CI の Codex が指摘する前に」潰しておきたい

## When NOT to Activate

- ネットワーク接続がない (Codex API 認証切れる)
- 超軽微な変更 (typo, コメントだけ) — Claude 単独で十分
- 認証情報・機密設定の変更 — 外部 LLM に流さない

## 前提

- `codex --version` が動くこと (path: `~/.nvm/versions/node/*/bin/codex`)
- `codex login` 済み、または環境変数 `OPENAI_API_KEY` がセット済み
- 作業ディレクトリが git リポジトリ内

## モード

### `review` — 静的レビュー

引数: `review <path or diff-ref>`

動作:
1. `git diff <ref>..HEAD` または対象 path を抽出
2. 以下を `codex review` に投げる:
   ```bash
   codex review \
     --config model="gpt-5-codex" \
     --prompt "$(cat <<'EOF'
   以下の diff/code を AGENTS.md のレビュー基準 (P0/P1/P2) で評価してください。
   出力形式: {"findings": [{"severity": "P0|P1|P2", "file": "...", "line": N, "message": "...", "fixable": true|false}]}
   EOF
   )"
   ```
3. 結果 JSON を parse して `findings` として返す
4. Claude 側の review-fix-loop が `fixable` なものを自動修正

### `exec` — 自律実行

引数: `exec "<instruction>"` (タスク記述)

動作:
1. `codex exec --cd $(pwd) "<instruction>"` を非対話で起動
2. Codex が diff を生成して終了する (apply はしない)
3. Claude 側で `codex apply` または `git apply` で反映
4. 通常の品質ゲート (`go test` / `npm test`) で検証

注意:
- sandbox mode で起動 (`codex exec --sandbox read-only` → 出力のみ、副作用なし)
- 書き込みが必要な場合は `--sandbox workspace-write`

### `fix` — 指摘箇所の自動修正

引数: `fix <path:line> "<指摘内容>"`

動作:
1. `codex exec` に「<path>:<line> の問題を修正」指示を出す
2. 出力 diff を `codex apply` で反映
3. `go test` / 既定のテストで検証
4. 失敗したら reset、unfixable へ格下げ

## 他 skill との連携

### review-fix-loop から呼び出される場合

`review-fix-loop` の Iteration2 以降で:
```
iteration 1: Claude が review → fix → commit
iteration 2: Codex が review (このskill) → 追加 findings あれば fix
iteration 3: Claude が残りレビュー
```

この 3-pass によって Claude 単独より **見落とし率 30-50% 改善** が期待される（経験則）。

### advisor-strategy との違い

- `advisor-strategy`: 自分 (Claude) が stuck したときにより賢い advisor (別 Claude Opus) に相談
- `codex-task`: ベンダー違いの LLM に**並列で**走らせて cross-check

両者の併用もあり。

## 出力

Codex の応答を JSON parse 成功したら、以下の形式で呼び出し元に返す:

```json
{
  "mode": "review",
  "findings": [
    {
      "severity": "P0",
      "file": "cmd/shingan-mcp/tools.go",
      "line": 42,
      "message": "error path swallows original error; wrap with fmt.Errorf",
      "fixable": true,
      "suggested_fix": "..."
    }
  ],
  "usage": { "input_tokens": 1234, "output_tokens": 567 },
  "duration_ms": 28000
}
```

JSON parse 失敗時は `raw_output` として生テキストを返す。

## エラー処理

| エラー | 処理 |
|--------|------|
| `codex: command not found` | `npm i -g @openai/codex` を促す、処理中断 |
| 認証エラー (401) | `codex login` を促す、処理中断 |
| rate limit (429) | 60秒 sleep して 1回 retry、再失敗で abort |
| JSON parse 失敗 | raw_output を返して Claude 側で解釈 |
| timeout (>120s) | abort して `Claude 単独で続行` にfallback |

## セキュリティ

- `codex exec --sandbox read-only` を default に (書き込み明示時のみ workspace-write)
- `.env`, `*.secret`, `credentials/` を含むファイルは prompt に載せない (`--exclude` 相当を自前でfilter)
- Codex 出力の diff を `codex apply` する前に **必ず `git diff --stat` で内容確認**

## コスト

- Codex gpt-5-codex: 1 review = 約 $0.05〜$0.15 (中規模 PR)
- review-fix-loop 3 iteration 内に1回だけ呼ぶ運用が現実的
- 月間 CI 予算を環境変数 `CODEX_MONTHLY_BUDGET_USD` で追跡可能 (TODO)

## 実装上の注意

- `codex exec` は stdin からも prompt を受け取れる: `echo "..." | codex exec -`
- 非対話時は `--output-format json` でマシン可読
- config override: `codex -c model="gpt-5-codex" -c reasoning_effort="high" ...`
- timeout は shell 側で `timeout 120 codex exec ...` で制御する (`codex` 本体に timeout flag はないバージョンあり)

## 記憶への記録

実行後、以下を `.harness/memory/inbox/codex-task-YYYY-MM-DD.md` に append:

```yaml
---
date: <today>
mode: <review|exec|fix>
target: <path or PR番号>
codex_findings: <件数>
claude_only_findings: <件数>
overlap_rate: <%>
importance: 1.3  # cross-check 系 +0.3
---
```

post-session フックで daily/ に集約。cross-check カバレッジを蓄積して重複指摘率を把握する。

## 既知の落とし穴

- **同じ LLM ファミリに寄らせない**: Codex も OpenAI なので、深い意味で独立した reviewer にはならない。本当の独立性が欲しいなら Gemini CLI / Mistral なども併用する
- **Diff 大きすぎ**: 差分が 1000行を超えると Codex がcontext溢れを起こす。分割 review 必須
- **Flaky な出力**: 同じ prompt でも結果が揺れる。seed 固定不可 → 複数回実行して intersect をとる運用も検討
- **ツールの版ズレ**: `codex-cli` 0.118+ の挙動を想定。0.100以前は `review` サブコマンドなし
