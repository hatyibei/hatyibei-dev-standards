# ADR-012: Empirical Prompt Tuning

## ステータス
accepted

## コンテキスト
- 新規作成・大幅改訂した skill / プロンプトは書き手自身では客観的に品質評価できない
- 既存ハーネスには skill 品質の反復評価手段がない（AI-DLC overnight 結果からの事後判定のみ）
- SCC 案件のチーム配布プロンプトでは配布前の堅牢化プロセスが必要
- mizchi/chezmoi-dotfiles の empirical-prompt-tuning skill が両面評価パターンを提供

## 決定
empirical-prompt-tuning skill を extended/skills/ に導入する。

### 配置と昇格方針（ADR-009 準拠）
- 初期配置: `extended/skills/empirical-prompt-tuning/`（実績ゼロ → extended スタート）
- 起動条件: 新規 skill 作成直後 / 大幅改訂直後 / チーム配布前
- 使用頻度 low × 失敗時コスト high → 実績次第で core/ 昇格を再評価

### Upstream からの主要 adaptation
1. **収束閾値の config 外出し**
   - upstream: +3pt / ±10% / ±15% / 連続 2 回をハードコード
   - harness: `extended/skills/empirical-prompt-tuning/config.yaml` に分離
   - プロジェクト特性で可変（SCC 案件は厳しめ、個人用 skill は緩め）
2. **hold-out シナリオの強化**
   - `robustness_required: true` フラグ付きは 3 本必須 / 連続クリア 3 回
   - それ以外は upstream 通り 1 本 / 連続 2 回
3. **SCC 案件別テンプレート**
   - `extended/skills/empirical-prompt-tuning/templates/` に `[critical]` チェックリスト雛形を配置

### ADR-006 (SubAgent) / ADR-011 (Advisor Strategy) との境界

| 目的 | パターン | ADR |
|------|---------|-----|
| 作業を分割したい | SubAgent | ADR-006 |
| 実行時の判断を仰ぎたい | Advisor | ADR-011 Layer 1 |
| 実行時成果をレビュー | Cross-vendor Reviewer | ADR-011 Layer 2 |
| **prompt/skill 自体の品質 tuning** | **Empirical Prompt Tuning** | **ADR-012** |

併用: 本 skill 内部の subagent dispatch は ADR-006 の機構を流用する（現在 `archive/unused-skills/subagent-driven-development/` に格納されている内容を参照）。

### AI-DLC との統合
- 新規/大幅改訂 skill の mainline マージ前 pre-merge gate として位置づける
- overnight run での利用可（ただし `max_iterations` でコスト上限制御）

## 根拠
- Upstream: mizchi/chezmoi-dotfiles（2026-04 時点）
- 既存 ADR-006 / ADR-009 / ADR-011 との整合
- SCC 案件のチーム配布プロンプト品質要件

## 影響
- API コスト: 1 イテレーションあたり (subagent dispatch × scenarios) 回の消費 → 重要プロンプトに限定
- 運用負荷: イテレーションログが蓄積 → skill 内にログフォーマット規定
- 実績次第で core/ 昇格判断

## Deferred Work
- 本 skill を自分自身に適用する dogfooding は別タスク（初期導入後に実施）
