---
atom: A1_41_meta_worktree_proposal
phase: "1"
intent: >
  回路2 第二颗（"与 Meta AI 沟通"步）：新增 WorktreeResearch（只读 git gatherer：
  当前分支 / 分支列表(按提交时间排序) / 近期提交 / dirty 状态；复用 A1_40 的
  RepoGitRunner，只跑只读 verb：rev-parse/for-each-ref/log/status）+
  MetaDrafting.proposeWorktreeTask —— 把 git 研究上下文喂给 Meta 模型
  （DeepSeek v4-pro，thinking on），产出"小型、可测试、范围明确的新 worktree 任务"
  提议（任务目标 / 建议基分支 / 建议新分支名 / 理由）。提案 ONLY（红线4：不写 wizard/spec、
  不执行；模型文本仅入 summary_card body 字符串，红线1）。失败 fail-visible 落确定性
  unavailable 文档。这正是用户要的"问 Meta AI：你研究整个项目 git 后，建议新开什么样的
  小 worktree 作为测试"。下一颗（A1_40 provision）消费这个提议建 worktree。
allowlist:
  - "app/Sources/TuringOS/WorktreeResearch.swift"
  - "app/Sources/TuringOS/MetaDrafting.swift"
  - "app/Tests/TuringOSTests/WorktreeResearchTests.swift"
  - "app/Tests/TuringOSTests/MetaDraftingTests.swift"
  - "scripts/build_app.sh"
  - "specs/atoms/A1_41_meta_worktree_proposal.md"
  - "specs/atoms/CURRENT"
max_new_files: 2
predicates:
  - "bash scripts/build_app.sh 全绿（executed >= MIN_TESTS）"
  - "真跑测 WorktreeResearch.gather：fixture repo（≥2 分支 + 提交）→ context.currentBranch 正确、branches 含两分支、recentCommits 非空、dirty 反映工作树"
  - "golden 线测 proposeWorktreeTask：mock 网关 → ViewIRDocument kind==meta_worktree_proposal；捕获请求体 model==deepseek-v4-pro + thinking enabled + user content 含 git 研究（当前分支/分支名/近期提交）+ 用户 ask；红线1：模型文本仅入 summary_card body"
  - "失败线：GatewayError → meta_unavailable 确定性文档（固定原因串）"
verified_external_facts: []
ux_touchpoints: >
  Orb 主屏：用户问"建议开什么 worktree" → Meta 研究该项目 git → 提议卡（提案，未执行）。
  失败显示"Meta AI 暂不可用 + 固定中文原因"。
gate: "bash scripts/shipgate.sh p1"

# 代码思路
WorktreeResearch.gather(projectRepo,runner) 跑只读 git → WorktreeResearchContext；
contextString() 确定性序列化。MetaDrafting 加 worktreeSystemPrompt +
worktreeProposalMessage(research,projectId,userAsk) + proposeWorktreeTask() —— 镜像
现有 draft()（同 preset/config/失败映射），kind=meta_worktree_proposal。
