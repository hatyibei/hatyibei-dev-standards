# Harness Skill Prompt Template

ハーネス内 skill の新規作成・大幅改訂時に使うチェックリスト雛形。
既存 ADR、配置規約、実行制約に違反しないことを `[critical]` として固定する。

## Priority Markers

- `[critical]`: 1 つでも落ちたらシナリオ失敗。ADR 整合・安全性・実行可能性の最低ライン。
- `[should]`: skill としての使いやすさや保守性の通常要件。精度計算に含める。
- `[nice-to-have]`: 将来の改善候補。成功/失敗の最低ラインには含めない。

## Checklist

1. `[critical]` 関連 ADR と配置方針に矛盾しない
2. `[critical]` 使用条件、禁止条件、失敗時の扱いが明記されている
3. `[should]` frontmatter description と本文の用途が一致している
4. `[should]` 参照すべきファイルやディレクトリが具体的な相対パスで示されている
5. `[nice-to-have]` 最小の実行例や判定例が含まれている
