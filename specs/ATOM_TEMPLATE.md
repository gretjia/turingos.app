---
atom: A<phase>_<nn>_<slug>            # 例: A1_03_worktree_list_provider；phase 0.5 写作 A0_5_<nn>_<slug>
phase: "<N>"
intent: >
  一段自然语言：这颗 Atom 完成后，世界发生了什么可验证的变化。
allowlist:                            # guard_spec_alignment 据此拦截越界编辑（fnmatch 模式）
  - "path/or/glob/**"
max_new_files: 3                      # M4 扁平预算；超限是 minimalism RiskFinding
predicates:                           # 全部 0/1；advisory 不写在这里
  - "bash scripts/shipgate.sh p<N>"
verified_external_facts:              # M7：外部 API/框架事实必须实证且带日期；无外部依赖写 []
  - fact: "<一句话事实>"
    source: "<官方 URL>"
    verified_on: "YYYY-MM-DD"
ux_touchpoints: >
  哪些视图/时刻消费这颗 Atom；失败时用户看到什么（M8：证据不是黑箱）。纯内核 Atom 写 none + 理由。
gate: "bash scripts/shipgate.sh p<N>"
---

# 代码思路（给执行 agent 的非强制草图）

简述实现路径、关键数据结构、与 contracts/ 的对接点。执行中发现草图错误：更新本卡（留痕）再继续。
