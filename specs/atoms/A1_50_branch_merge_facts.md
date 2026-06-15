---
atom: A1_50_branch_merge_facts
phase: "1"
intent: >
  Git 观测机制建实第一颗（daemon 观测侧，回路2/galaxy 节点的诚实底座）：让 A1_47 起的
  branch poller 对每个非默认分支算出诚实的**关系观测**——把一直占位为 "unknown" 的 merge_status
  变成真值，并新增 ahead / behind / merge_base / contained_in_default。这是用户 2026-06-14 裁决的
  3→2→1 顺序里的轨3：先把可 sound 的 Git 关系数据建实，再做 A1_51 逐分支节点渲染、A1_52 回路2 真机。

  **范围收敛的依据（对抗复核 2026-06-14，workflow wf_ee716a30，本地真跑 git 实证）**：原计划的
  「PR 可证 merged-green」被对抗复核推翻为**不 sound**——廉价 gh 信号无法证明「这条分支的工作此刻
  真在 default 里」：
    - `git revert` 只加一个反向 commit、**不删** mergeCommit，故 mergeCommit 仍是 default 祖先
      （compare/{mc}...{default} behind==0），而内容已撤 → 任何基于 ancestry 的 merged 判定都假绿；
    - `gh pr list` 按 headRefName 匹配会被「删后同名重建分支」「force-push-after-merge」骗过
      （旧 mergeCommit 仍在 default，当前 tip 却未合）；GitHub 不暴露「合并时刻 head SHA」，无法绑定 current tip。
  可达性 ≠ 内容存活。按宪法（绝不假绿、宁可 unknown），**A1_50 不发任何 merged-green 声明**：
  `merged_into_default` 恒 emit false（app 永不上绿）。真正 sound 的 merged-green（内容/树级核验，或
  人工确认信号）另立未来原子 **A1_53**。

  唯一 sound 的廉价信号是 `contained_in_default` = (compare/{default}...{branch} 的 ahead==0)
  = 分支 tip 是 default 祖先、无领先 default 的提交。这是诚实的**可达性**陈述，**不等于**「内容存活/已合并」
  （合并后被 revert 的分支仍 contained），故 A1_51 渲染时**必须中性呈现、绝不上绿**。merge_status/ahead/
  behind/merge_base 是 compare 的纯观测，恒直出；compare 失败 → status=unknown（fail-visible，不崩、不假）。

  效率：compare 调用按 (branch_head_sha, default_head_sha) memoize；空 sha（default 未解析出）或
  Unknown（gh 错误）结果**不缓存**，故瞬时故障/未解析 default 下轮强制干净重算（堵死缓存 stale 假象）。

  范围：本卡只 daemon 诚实吐这些观测上 tape；app 的 BranchFact 已 fold merged_into_default（恒收到 false，
  零 app 改动、永不上绿）。ahead/behind/contained 的 app 折叠 + 逐分支节点渲染 = A1_51，本卡不碰 app/render，
  不改 RadarModel 诚实规则（.green 仍 BY LAW 缺席）。
allowlist:
  - "daemon/src/branch_poller.rs"
  - "fixtures/event_streams/branch_observed.jsonl"
  - "specs/atoms/A1_50_branch_merge_facts.md"
  - "specs/atoms/NUMBERING.md"
  - "specs/atoms/CURRENT"
max_new_files: 0
predicates:
  - "bash scripts/shipgate.sh p1 全绿（16 门；含 rust fmt / clippy -D warnings / cargo test 13-15 与本卡新测；过门前 pkill 'turingosd serve' 防 wire-probe 负载 flake）"
  - "compare 解析纯函数测：parse_compare(jq_json) → {status∈{ahead,behind,identical,diverged,unknown}, ahead:u32, behind:u32, merge_base}；方向钉死 base=default head=branch（ahead=分支独有提交）；缺字段 / 坏 json → Err；未知 status → Unknown"
  - "contained_in_default 测：ahead==0 ∧ status≠Unknown ⇒ true（中性可达性，非 merged）；ahead>0 ⇒ false；status==Unknown（compare 失败，ahead 降级为 0）⇒ false（无观测不宣称 contained，防 unknown 误读为 contained）"
  - "memoize + 退化键加固测（GhClient 计数桩）：(a) branch_sha 与 default_sha 均未变 → 不再 compare；任一变化 → 重算；(b) 空 default_sha 或空 branch_sha → 每轮强制重算（退化键不缓存）；(c) gh 错误的 Unknown 不缓存 → 下轮重试；(d) 默认分支 → identical/contained 且零 compare 调用"
  - "无 merged 声明保证：payload 的 merged_into_default 恒 false（json! 字面量常量）；源码不含 `gh pr list`、不含 ancestry/merge_commit 探测（grep 断言无 merged_pr/merge_commit_in_default 残留）"
  - "fixture：branch_observed.jsonl 诚实行（identical-contained / behind-contained / ahead / diverged / merged-then-reverted-仍contained-但merged:false / removed），全行 merged_into_default:false；validate_contracts（gate 2）+ 双读 sha 稳定 + seq 单调（gate 9）+ rust fixtures_conform_to_envelope（gate 15）全过"
  - "真机复观：daemon 对真 turingosv4 registry 真跑、读 UDS——分支显示真实 ahead/behind/merge_status（非全 unknown）；contained_in_default 如实跟随 ahead==0；**每一条分支 merged_into_default 均为 false**（零假绿）"
verified_external_facts:
  - fact: "GitHub compare：GET /repos/{o}/{r}/compare/{base}...{head}（三点式，相对 merge-base）。status 四值 {ahead,behind,identical,diverged}；ahead_by=head 独有提交数、behind_by=base 独有（head 缺的）数，故 base=default head=branch 时 ahead_by=分支独有提交。daemon 用 `gh api repos/{o}/{r}/compare/{base}...{head} --jq '{status,ahead_by,behind_by,total_commits,merge_base:.merge_base_commit.sha}'`。真机实测（turingosv4）：compare/main...adversarial-task-a-new-gate → {ahead_by:3,behind_by:550,status:diverged}，parse_compare 直接吃。"
    source: "docs.github.com/en/rest/commits/commits + cli.github.com/manual/gh_api + 真机 turingosv4 实测（2026-06-14）"
    verified_on: "2026-06-14"
  - fact: "merged-into-default 廉价检测【不 sound，已弃用】——对抗复核（workflow wf_ee716a30-e72，本地真跑 git）实证 3 条 constitutional 假绿：(1) revert：`git revert` 加反向 commit、不删 mergeCommit，`git merge-base --is-ancestor mc default`=YES 且 compare/{mc}...{default} behind==0，但内容已撤 → ancestry 判 merged=假绿；(2) 同名重建 / force-push-after-merge：`gh pr list` 按 headRefName 匹配命中旧 PR，旧 mergeCommit 仍在 default → 给未合的当前 tip 判绿；(3) >100 分支分页致 default tip 解析为空 → 缓存键判别力坍塌冻结 stale 绿。GitHub 不暴露「合并时刻 head SHA」，无法绑定 current tip。结论：可达性≠内容存活，廉价信号无法 sound 证明 merged-and-live；A1_50 不发 merged 声明（恒 false），sound merged-green 留 A1_53（内容级核验或人工确认）。"
    source: "对抗复核 workflow wf_ee716a30-e72（Critic×3 lens + Witness 本地 git 验证；纠正了前一轮 wf_eca86de5 误判 revert→behind>0 的错误结论）"
    verified_on: "2026-06-14"
  - fact: "rate/效率：authenticated 主限 5000/h；本卡每非默认分支 1 次 compare、按 (branch_sha,default_sha) memoize，稳态仅变化分支重算 « 5000/h。ETag 304 免费优化与 sound merged-green 同属后续。"
    source: "docs.github.com/en/rest/using-the-rest-api/rate-limits（调研 workflow wf_eca86de5-c62）"
    verified_on: "2026-06-14"
ux_touchpoints: >
  无直接 UI。daemon 诚实观测经 BranchObserved 上 tape；app 的 BranchFact 已 fold merged_into_default
  （恒 false、永不上绿）。逐分支节点 + ahead/behind/contained 中性渲染 = A1_51；sound merged-green = A1_53。
gate: "bash scripts/shipgate.sh p1"

# 代码思路（daemon/src/branch_poller.rs）

纯函数（零网络、便于单测）：
- `parse_branch_list(json, default) -> Vec<BranchInfo>{name,head_sha,is_default}`。
- `parse_compare(jq_json) -> CompareFact{status:MergeStatus, ahead, behind, merge_base}`；MergeStatus
  {Ahead,Behind,Identical,Diverged,Unknown}；`CompareFact::contained_in_default() = ahead==0`（中性可达性）。

poll()（承袭 A1_47 fail-visible：每失败 eprintln + 该分支降级，never crash/fake）：
- resolve default（已有）；list branches（已有，含 head sha）；default_sha = 列表中 is_default 的 head_sha（缺则空）。
- 对每个非默认分支 `compute_merge(gh, ctx, info)`：memoize 命中（branch_sha+default_sha 均未变）→ 复用；
  否则 `compare/{default}...{branch} --jq ...` → CompareFact（失败→Unknown）。**空 sha 或 Unknown 不缓存**（堵 stale）。
- payload：merge_status/ahead/behind/merge_base/contained_in_default + `merged_into_default: false`（常量字面量）。
- 默认分支：identical/ahead0/behind0/contained=true，零 compare 调用。
- 已**移除** A1_50 初版的 `gh pr list` + ancestry 探测 + merged_pr/merge_commit_in_default/merged_into_default
  函数（对抗复核证其不 sound，见 verified_external_facts）。

clippy -D warnings：GhClient.run(&[&str]) 路径无 shell（含 `/` 的 ref 直接传，三点式字面量）；查 exit；
RepoCtx 打包 per-repo 上下文避免长签名。
