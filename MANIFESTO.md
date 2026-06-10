# MANIFESTO — Software 3.0 价值观宣言（操作性文档）

收录标准：每条必须有**机械执行点**。没有执行点的价值观只是装饰（宪法 Art.I.1：自然语言是软约束，谓词才是硬约束）。

| # | Software 1.0/2.0 反射 | Software 3.0 纠正 | 机械执行点 |
|---|---|---|---|
| M1 | 遇复杂先建抽象层 / Manager / Factory | 先写自然语言 Atom Spec；**第二个真实调用方出现前禁止抽象** | `guard_minimalism` 回灌 + minimalism-auditor 清洁审计（advisory 通道） |
| M2 | 防御式编程、沉默兜底 | **fail-closed**：让谓词拦截，不写隐藏 fallback | 负面模式谓词：空 catch / 默认放行 → shipgate FAIL |
| M3 | 状态藏进对象/单例/私有 DB | **状态上 tape；一切 UI/DB 是可删可重建的投影** | projection schema 强制 `derive_source`/`rebuild_command`（shipgate #3）；投影守恒测试 |
| M4 | 写给人类维护者的间接层 | 写给 LLM 一次跑通的扁平上下文：**函数>类、文件>服务** | Atom 卡 `max_new_files` 预算；超限 Stop gate 拒收工 |
| M5 | 文档与代码两张皮 | **Spec 即门禁输入**：Atom 卡 frontmatter 机器可读 | `guard_spec_alignment` 以 allowlist 拦截越界编辑 |
| M6 | 把 advisory 混进门禁 | **Predicate 输出域 = {PASS,FAIL}**；主观意见归 RiskFinding 通道 | predicate_result schema verdict 枚举锁死（shipgate #4） |
| M7 | 相信旧权重、相信旧验证 | 外部事实必须 WebFetch 实证**且带验证日期**——本仓 R0 已有活教材：一次"已验证"的 hooks 结论数月后被官方文档推翻（见 research/R0_memo.md §4） | Atom 卡 `verified_external_facts[].verified_on` 必填；R-stage memo 强制溯源 |
| M8 | UI 是最后刷的皮肤 | **UX 是治理界面**：用户看到的必须是证据（签名/回执/溯源），不是黑箱按钮 | 快照金标 + 可达性 0/1 谓词（P1 起）；R-stage 设计评审；主观美学走 RiskFinding，绝不冒充谓词 |

## 开工四问（SessionStart 自动注入）

1. 这个抽象有**第二个调用方**吗？没有就别建。
2. 这个状态能**从 tape 重建**吗？不能就别存。
3. 这个判断是 **0/1 谓词**还是 advisory？分轨，别混。
4. 用户在这一步看到的是**证据还是黑箱**？黑箱就重画。

## 反 Goodhart 附则

评分函数与隐藏政策对被评测的 agent 不可读（宪法 Art.III）。任何"让门禁变绿"的捷径（改测试、改谓词、加豁免）本身是 Class-3+ 动作，须走 RATIFICATION_POLICY 对应层级。
