# CLAUDE.md — 执行 Agent 入口（目录，不是百科全书）

> **The app is not the truth. The app is the sovereign projection and control surface over truth.**

## 开工前必读（按需渐进披露，不要一次读完）

| 你要做什么 | 读 |
|---|---|
| 任何工作之前 | `specs/atoms/CURRENT` → 对应 Atom 卡（你的唯一授权范围） |
| 理解价值观与红线 | `MANIFESTO.md`（M1-M8 + 开工四问） |
| 理解当前 Phase 与门禁 | `PLAN.md`（R→D→S 协议；当前 Phase 的 Atom 表） |
| 查既定裁决 | `ADR.md`（ADR-001~011，推翻须走新 ADR，不得默改） |
| 写/改任何事件、投影、回执 | `contracts/*.schema.json` + `docs/UPSTREAM_CONTRACT.md` |
| 调 turingos CLI | `docs/CLI_ABI.md` |
| 画任何界面 | `DESIGN.md` + `docs/NAVIGATION_MODEL.md` + `docs/VISUAL_SEMANTICS.md` |
| 涉及身份/信任徽章 | `docs/TRUST_STATES.md`（唯一枚举，禁止自造红黄绿） |
| 涉及签名/审批 | `docs/RATIFICATION_POLICY.md`（L0-L4） |
| 接入 agent 工具 | `docs/ADAPTER_CAPABILITY_MATRIX.md` |
| 安全敏感改动 | `docs/THREAT_MODEL.md` |
| 收工 | `bash scripts/shipgate.sh p0` 全绿 + 回执落盘（`/atom-ship`） |

## 铁律（违反即门禁红，详见各文档）

1. `constitution/constitution.md` 只读。hook 会拒绝一切写入（含 Bash 旁路）。
2. 只能编辑 CURRENT Atom 卡 allowlist 内的文件。要扩范围：改 Atom 卡留痕，不要绕。
3. Phase N 的 R-stage memo（`research/RN_memo.md`）不存在 → 不许开 Phase N 的任何 Atom。
4. Predicate 输出域 = {PASS,FAIL}；主观意见走 RiskFinding 通道。
5. 不确定的外部 API/框架事实：WebFetch 实证 + 写进 Atom 卡 `verified_external_facts`（带日期）。
6. 报忧是宪法义务。门禁 FAIL 原文上报，不粉饰。

## 仓库法律 vs 开发者体验

`scripts/shipgate.sh`、`contracts/`、`fixtures/` 对所有贡献者生效（无 Claude 依赖）；`.claude/` 的 hooks/skills/agents 只是给 Claude Code 贡献者的加速层。两层都在，以前者为准。
