---
atom: A1_63a_mainline_resolution
phase: "1"
depends_on: ["A1_62_canonical_main_cascade", "A1_69_commit_detail_info"]
adr: "ADR-018 (主线判定=指定类信号,refine ADR-017 trunk-candidacy); research/R1_mainline_convention.md (RATIFIED 2026-06-15)"
intent: >
  用户重申主线纪律(2026-06-15):galaxy 的 canonical 主线**必须**锚在真 git 主线(GitHub 或本地真 main),
  大量未合并本地 commit/分支是重要探索线索但须**分清主次、恒有一条主线**,且此判定要**用行业共识约定**。
  10-agent 研究+对抗 workflow(wf_ac035e39)→ 约定 RATIFIED(用户四问全批推荐),见 ADR-018 + R1_mainline_convention.md。

  **实证根因(HEAD live bug)**:今天 galaxy 把 turingos.app 锚在陈旧 `claude/brave-knuth-5uo3ce`(实测 0-ahead/90-behind
  于真 main)——因 branch_poller.rs:289 `is_default = name == raw gh default_branch`、RadarModel.swift:224
  `isAnchor = branchFact.isDefault`、且 AttentionModel.swift **根本没有 .refReconciliation fold case**
  (A1_62 的 reconciliation 到不了任何投影)。

  **本原子 = DAEMON-ONLY 主线真相 + 诚实锚**。关键洞察:app 今天 isAnchor=branchFact.isDefault(经 BranchObserved
  `is_default` 通道),故**只要 daemon 把 `is_default` 设成"仅 confirmed primary 为 true"(provisional/ambiguous/unobserved
  时全 false → 无锚 → app 自然不画 confident 脊柱),即可零 app 改动让 turingos.app 锚 main 且 ambiguous 诚实留白
  —— no-false-green 由保守 is_default 守住,无需 app chrome 同原子**(约定"chrome 必须同原子"的担忧=别在 provisional/wrong
  上画 confident 脊柱;保守 is_default 已满足此不变量)。
  - **DAEMON 两遍 whole-repo reduction**(主线判定非 per-branch 局部):
    PASS A gather(**无条件于缓存/声明信号**):配置默认 + **live** `ls-remote --symref`(path-present;非缓存 symbolic-ref=陈旧)
    + 常规名 main|master|trunk|develop|release/* 存在性 + 对配置默认的 ahead/behind(复用/precompute compare;有 path 用本地 merge-base)。
    PASS B reduce:① 非空枚举前置 ② ancestry 消去(丢严格祖先/behind==0 被包含) ③ **名称优先级** main/master>trunk>develop>release/*
    破僵 ④ >1 分叉幸存→ambiguous → 产出 `mainline_ref: Option` + tier{confirmed/provisional/ambiguous/none} + relation。**depth/recency 算但只标注,永不选王**。
  - **`is_default = (name == mainline_ref) && tier==Confirmed`**(reduction 之后 DERIVED,非 parse_branch_list:289 早 stamp);
    `mainline_ref` 作 compare base/recent sha/default_ref(present 时;else 退回配置默认但 is_default 仍保守)。
  - 扩展 RefReconciliation 携 resolved primary + tier + `relation`(新增 default_behind_named + ahead/behind)——**additive,供 A1_63a2 app 消费**,
    本原子 app 不读(今天 AttentionModel 本就无 .refReconciliation case,不回归)。保持 merged_into_default=false-always、contained=可达性。
  - `PinObserved` 事件类型**桩**(rung0 前向兼容,本期不 emit/不做 UI)。derive_from_tape 守恒测(Art.0)。
  **本原子不碰 app**(零 app 改动 → 零 golden 变更:golden 在 p1 fixture 上,daemon live 行为变不影响静态 fixture)。
  **后继 A1_63a2(app-only)**:补 .refReconciliation fold + 渲染 provenance tier(confirmed/provisional/ambiguous/unobserved)+ 三 fail-visible 态显式标签 + 三类别(PRIMARY/co-trunk/SECONDARY)chrome。
  **A1_63b**:Railroad Swimlane 几何(OID scene/topo lanes/first-parent 脊柱/merge_base 边)。
allowlist:
  - "daemon/src/branch_poller.rs"
  - "daemon/src/events.rs"
  - "contracts/event_stream.schema.json"
  - "fixtures/event_streams/ref_reconciliation.jsonl"
  - "ADR.md"
  - "research/R1_mainline_convention.md"
  - "specs/atoms/A1_63a_mainline_resolution.md"
  - "specs/atoms/NUMBERING.md"
  - "specs/atoms/CURRENT"
max_new_files: 1
predicates:
  - "bash scripts/shipgate.sh p1 全绿(16 门;过门前 pkill GUI app + 'turingosd serve' + 删 lock)。**golden 不变**(零 app 改动;daemon live 行为变不触静态 p1 fixture)。"
  - "**daemon reduce 机械测(纯函数 resolve_mainline)**:给定候选+ahead/behind → PASS B 产出正确 (mainline_ref, tier):① 配置默认是某常规名的严格祖先(behind==0) → 被 fold,常规名 confirmed 胜(brave-knuth 折叠/main confirmed=turingos.app 真题);② 名称优先级:{main, develop} 互非祖先 → main confirmed(非按 depth/recency);③ >1 分叉常规名幸存仅活跃度可分 → tier=ambiguous, mainline_ref=None;④ 分支枚举空 → tier=none/unobserved(非退回配置默认);⑤ 配置默认是常规名(main)且无更优 → confirmed via rung1。"
  - "**is_default 保守 DERIVED(核心不变量)**:`is_default==true ⟹ tier==Confirmed 且 name==mainline_ref`;provisional/ambiguous/unobserved 时**所有**分支 is_default==false(grep+测断言:无任何路径在 tier≠Confirmed 时置 is_default=true=no-false-green 守卫)。turingos.app:brave-knuth.is_default==false, main.is_default==true。"
  - "**RefReconciliation 扩展(additive)**:加 resolved primary + tier + relation(新增 default_behind_named 携 ahead/behind);merged_into_default 恒 false;contained=可达性。event_stream.schema payload=object,additive 不破既有消费者(app 本就不读 RefReconciliation,零回归)。"
  - "**PinObserved 桩**:EventKind 加 PinObserved + schema kind 枚举加;无 emit 路径(rung0 前向兼容)。"
  - "**Art.0 derive_from_tape 守恒测(ADR-018-F)**:mainline_resolution_is_conservation_of_tape —— 断言 emitted (resolved_primary, mainline_tier) + per-branch is_default 是 resolve_mainline 输出对观测候选集的**确定性重建**(view==derive_from_tape);is_default 经共享纯规则 derive_is_default(tier, primary, name) 派生(poll 与测同一函数);Confirmed(turingos.app fold)+ 非 Confirmed(ambiguous/provisional/unobserved 全不 designate)各覆盖。"
  - "无回归:rust fmt/clippy/test 绿;**swift build+test 绿且零改**(app 未触);既有 BranchObserved 消费者不崩(is_default 语义收紧=更诚实,字段不变)。"
  - "**daemon socket live 证(环境无关,直接验修)**:重启带 resolution 的 daemon → 只读订阅:turingos_app 的 BranchObserved 中 **main.is_default==true、brave-knuth.is_default==false**(修前相反);RefReconciliation 携 resolved=main + relation=default_behind_named(ahead0/behind90)。"
  - "**真机 UX 验证(我 computer-use 或用户)**:重启 daemon + 现有 app(无需重 build app),zoom in turingos.app → 中心锚 = **main**(非 brave-knuth)。截屏 /tmp/galaxy_evidence/mainline_*.png;环境漂移则 daemon socket live 证代偿(is_default 通道已证 + 机械测)。"
verified_external_facts:
  - "turingos.app: gh default_branch=claude/brave-knuth-5uo3ce(非常规名), 0-ahead/90-behind 于 main; codex/a1-08..11 全 0-ahead 于 main(103/0 99/0 97/0 93/0); main(4baca321) 唯一常规名幸存 — verified_on 2026-06-15(本 session live)"
  - "HEAD bug: AttentionModel.swift 无 .refReconciliation case; RadarModel.swift:224 isAnchor=branchFact.isDefault; branch_poller.rs:289 is_default=name==raw gh default_branch — verified_on 2026-06-15"
  - "event_stream.schema.json payload=type:object 无逐字段约束 → relation 枚举扩展 + PinObserved kind additive — verified_on 2026-06-15"
ux_touchpoints: >
  galaxy zoom-in 任意项目 → 中心主线锚 = 真 git 主线(designation 选出,非陈旧默认/非最活跃);未合并分支分清主次为 secondary 探索线;
  真主线不可观测/真分叉时诚实显 unobserved/ambiguous,绝不臆测脊柱。
gate: "bash scripts/shipgate.sh p1"

# 代码思路（详 research/R1_mainline_convention.md「daemon vs app 改动」）
## daemon/src/branch_poller.rs
- 新 `resolve_mainline(candidates) -> Resolution{ mainline_ref: Option<String>, tier: TrunkSource, relation, category_hints }` 纯函数(PASS B);PASS A gather 在 poll() 内 observe_local_trunk(:665) 之后无条件建候选集。
- is_default 移出 parse_branch_list:289 → reduction 后 derive。mainline_ref 替换 compare base(:575)/recent sha(:737)/default_ref(:768)。
- RefReconciliation(:670-690) 加 resolved primary + relation(default_behind_named + ahead/behind)。
## daemon/src/events.rs
- EventKind 加 `PinObserved`(桩;无 emit 路径,仅类型+schema 前向兼容)。
## app
- AttentionModel.swift: 加 `.refReconciliation` case → fold mainline_ref/relation/tier 进投影(新 ReconciledMainlineFact 或挂 ProjectFact)。
- RadarModel.swift: isAnchor(:224) + center-anchor 由 mainline_ref 驱动;NodeCardContent/scene 加 provenance tier + 三 fail-visible 态 + 三类别数据标注。
- RadarViews.swift: 渲染 provenance tier icon+text(VISUAL_SEMANTICS 3/4)+ fail-visible chrome(不画 confident 脊柱)。
