---
name: atom-open
description: Open an atom card as CURRENT after verifying its phase R-stage memo exists. Use before starting any development work on an atom.
---

# /atom-open <atom-card-path>

工序（顺序执行，任何一步失败即停止并报告）：

1. 读取目标 Atom 卡（`specs/atoms/A<phase>_<nn>_<slug>.md`），确认 frontmatter 含 `intent` / `allowlist` / `predicates` / `gate`；缺项 → 先补卡，不开工。
2. 校验 R-stage 门禁：`research/R<phase>_memo.md` 必须存在（hook 也会机械拦截，但先自查能给出更好的错误信息）。
3. 将 Atom 卡路径写入 `specs/atoms/CURRENT`。
4. 向用户复述：intent 一句话、allowlist 范围、过闸命令。开始编码。

纪律：一次只开一颗 Atom；要扩 allowlist 就修订 Atom 卡（留痕），不要绕过 hook。
