---
name: atom-ship
description: Ship the CURRENT atom - run repo law (shipgate), write the receipt, reset CURRENT to NONE. Use when atom implementation is complete.
---

# /atom-ship

工序（顺序执行）：

1. 读 `specs/atoms/CURRENT` 取得 Atom 卡，跑卡内 `gate` 命令（默认 `bash scripts/shipgate.sh <phase>`）。
2. **如有 FAIL：原文呈报用户，不粉饰、不豁免**；修复后重跑。全绿才继续。
3. 写回执 `specs/atoms/receipts/<atom-id>.receipt`：shipgate 完整输出 + UTC 时间戳 + git HEAD。
4. `specs/atoms/CURRENT` 置为 `NONE`。
5. 提交（提交信息引用 atom id），提醒用户可触发 Veto-AI 清洁审计（S-stage 终审）。

纪律：回执是证据不是装饰——Stop gate 凭它放行收工。
