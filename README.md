# TuringOS.app

> **The app is not the truth. The app is the sovereign projection and control surface over truth.**

真相在 Git-backed ChainTape/CAS（上游 [turingosv4](https://github.com/gretjia/turingosv4)）；工作空间在 git worktree；执行发生在 Claude Code / Codex / Cursor；**人类通过本 macOS App 看见、分配、签名、否决、回放**。

## 这是什么

TuringOS.app 是 **macOS 原生 Agentic Mission Control**——宪法约束下的 agent 群体治理界面：

- **Worktree Radar**：所有项目、所有 worktree、所有 agent 会话的实时态势。
- **Identity & Wallet**：agent manifest 注册、签名验证、Secure Enclave 人类根钱包。fail-closed：无身份即 observe-only。
- **Proposal Gate**：diff → 签名提案 → Predicate {PASS,FAIL} + Veto {PASS,VETO} 双闸 → 裁决上 tape。拒绝也是状态。
- **Ratification Center**：Class-4 宪法级动作的签名仪式（canonical payload + signed tag），受 [RATIFICATION_POLICY](docs/RATIFICATION_POLICY.md) 五级分层约束，防签名疲劳。
- **Replay**：从 tape 重放任意历史区间。一切 UI 状态都是可删可重建的投影。
- **Market Signals**（observe-only）：Price is a signal, not predicate truth.

## 这不是什么

不是 IDE，不是 agent wrapper，不是第二套账本。它不重定义 runtime truth（[UPSTREAM_CONTRACT](docs/UPSTREAM_CONTRACT.md)），不把 advisory 混进 predicate，不把市场价格当真理。

## 仓库法律

`scripts/shipgate.sh` + `contracts/*.schema.json` + `fixtures/**` 是 repo law，任何贡献者（人类、Claude、Codex、CI）一视同仁；`.claude/` 只是开发者体验层。开发协议见 [PLAN.md](PLAN.md)（R→D→S），价值观见 [MANIFESTO.md](MANIFESTO.md)，裁决见 [ADR.md](ADR.md)。

## 状态

Phase 0（护栏与契约）。尚无应用代码——这是设计使然：先钉死错误不能发生，再写第一行 Swift/Rust。
