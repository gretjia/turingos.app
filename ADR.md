# ADR — 架构裁决记录（001-017）

推翻任何一条须新增 ADR 条目并走 RATIFICATION_POLICY 对应层级，不得默改。

## ADR-001 控制面不是 IDE（承继 v1.2）
只做 Mission / Worktree / Identity / Proposal / Predicate / Ratification / Replay。Claude Code、Codex、Cursor 是执行器，不内嵌编辑器与终端复刻。

## ADR-002 git worktree = 共享物理层（承继）
所有 agent 与人类共用 git worktree 作为工作空间原语；App 不发明私有工作区格式。

## ADR-003 Git-backed ChainTape/CAS 是唯一 canonical truth（承继）
UI 状态、SQLite、内存缓存一律 derived projection：可删、可重建，并以守恒测试（`view == derive_from_tape(tape)`）背书。投影必须声明 `derive_source` / `schema_version` / `rebuild_command`（contracts/projection.schema.json 强制）。

## ADR-004 Fail-closed agent identity（承继，PR #340 对齐）
无 manifest → 拒；签名无效/冒名 → 拒；未注册 → observe-only。信任状态全集见 docs/TRUST_STATES.md。

## ADR-005 技术栈：SwiftUI 壳 + Rust `turingosd`
内核语义复用上游（见 ADR-009 车道）；GUI↔daemon = UDS + JSON-RPC，**事件订阅式**（UX 实时性反向塑形：纯请求响应不满足 Radar/仪式屏的流式需求）。Human Root 私钥只存在于 App 进程侧 Secure Enclave；daemon 只验签、永不持有人类根私钥。

## ADR-006 双层 Harness：repo law vs developer UX
- **Canonical Harness（repo law）**：`scripts/shipgate.sh` + `contracts/*.schema.json` + `fixtures/**` + `scripts/predicates/*.grep` + 确定性测试。**在无 Claude 的环境（CI、Codex、人类本地）可完整运行**，对一切贡献者一视同仁。
- **Claude Developer Harness（contributor UX）**：`.claude/{hooks,skills,agents}`，只是 Claude Code 贡献者的加速与防呆层，**绝不承载仓库法律**。
杜绝"只有 Claude Code 能正确开发本仓"的隐性锁定。

## ADR-007 Replay Rule Epoch / Legacy Evidence Guard（承继 v1.2 §3.5）
新验证规则 fail-closed forward 生效；历史链标 `legacy_pre_rule`，**绝不改判历史**。重放旧链用旧 epoch 规则。

## ADR-008 双轨平台目标
- **开发 SDK = Xcode 27 (macOS 27 SDK)**（用户 2026-06-10 二次裁定）：本地开发与设计直接用 Xcode 27 beta SDK；**deployment target = macOS 26**（向下兼容）。
- **27-only API 隔离纪律**：凡 macOS 27 专属 API 必须 `if #available(macOS 27, *)` 且**源文件级隔离**（独立文件/条件编译），保证工程在 26.5 SDK 下仍可整体编译——这是 CI 可行性的前提，也保证 27 GM 切换零返工。
- **CI Swift lane**：用 runner 镜像现有的最新 Xcode（当前 26.5）；macos-26 镜像提供 Xcode 27 beta 后即切（R-stage 例行核查 runner-images）。**禁止功能依赖 beta-only API** 不变（shipgate #6）。
- **arm64-only** 不变。

## ADR-009 双仓契约
- `turingosv4` = constitutional runtime（ChainTape/CAS/replay/sequencer/market/verifier，canonical receipts/predicates/economic tx）。
- `turingos.app` = sovereign host（UX shell + daemon + adapters + projections）。
- 本仓**不得重定义 runtime truth、不得复制 canonical state logic、只能经 PINS.toml 钉死的 runtime interface 读写 receipts**。细则与集成车道（A：CLI-as-API 按 docs/CLI_ABI.md；B：上游 lib 化 PR 走上游 Class-3/4 流程）见 docs/UPSTREAM_CONTRACT.md。

## ADR-010 Worktree 真相层级
Claude Code 的 WorktreeCreate/WorktreeRemove hooks **存在且可用**（2026-06-10 官方文档实证，纠正本仓早期错误结论——见 research/R0_memo.md §4）：用于主动接管 Claude 管理的 worktree 生命周期。**但 hooks 不是 canonical source of truth**：canonical discovery 永远是 `git worktree` registry + filesystem 周期对账。理由：①用户可能不用 hooks；②Cursor/VS Code/人类/脚本不经过 Claude hooks；③hooks 可配错、被禁用、随版本变化；④worktree 的最终真相是 git + filesystem。

## ADR-011 三级 API（投影安全）
- **Projection API**：只读；无私钥、默认无 raw transcript、无隐藏评分内幕；可安全投射到远端/移动表面。
- **Action API**：typed action（contracts/typed_actions.schema.json）；策略检查；可要求本地签名人；**禁止任意命令转发**。
- **Signing API**：仅接受 canonical payload；显式人类确认；预留 m-of-n SignerSet（未来 iPhone SE 可注册为 Class-4 第二签名因子）。
未来 iOS/iPadOS/visionOS 客户端只消费 Projection + 提交 typed action + 签 canonical payload，**永不成为第二个 daemon**（主权宿主拓扑：Mac 持密钥/daemon/worktree）。字段分级见 docs/PROJECTION_POLICY.md。

## ADR-012 运行授权协议（用户 2026-06-10 当面裁定，PR #1 合并时授予）
- **自主域**：R→D→S 全流程的执行环节由执行 agent 自主决策执行——含 **repo law（shipgate + CI）全绿后的 PR 合并**。宪法约束与 harness 监督全程在场。
- **停机点（唯一例外）**：每个 Phase/Module 的 R-stage 调研思辨完成后、形成可执行细节（Atom 卡集）之前——**设计简报与关键裁决必须停机等用户确认**（"探讨"环节）；UX-heavy Phase 的设计评审属此列。
- **合并纪律**：FAIL 状态下无合并权，原文上报；合并方式保留分支历史（不 squash 宪法域锚定的 merge——T5 防线）。
- **权力边界**：本 ADR 不下放宪法权力——L3/L4 域动作（宪法/PINS/RATIFICATION_POLICY/本协议自身的变更）仍需用户显式批准。
- **增补（R1 停机点裁定）**：UI 设计为共创流程——执行 agent 出草图/效果图方案，**用户参与初期设计与测试**；UI 实现 Atom 在对应草图获用户认可前不开工（内核轨不受此限）。细则见 DESIGN.md「设计共创协议」。

## ADR-013 签名抽象层（硬件签名零重构预留，用户 2026-06-10 裁定）
- **法律**：一切签名/验签必须经统一抽象接口（Rust trait `Signer`/`Verifier`、Swift protocol 同构）：`key_kind() / fingerprint() / sign(canonical_payload) -> signature / attestation()`。业务代码（提案、仪式、回执、merge guard）**只依赖抽象，永不触碰具体算法/介质**。
- **key_kind 开放枚举**：`contracts/signature_receipt.schema.json` 的 key_kind 扩值 = minor 版本（加值向后兼容，contracts/README 既定规则）；未来硬件签名介质（FIDO2 token、外置 HSM、新 SE 形态、多设备 SignerSet 成员）以**新增 key_kind + 新 Signer 实现**接入，**底层与业务代码零重构**。
- **接线时点**：P2 第一颗签名 Atom 即以 trait 落地（SE-P256 与 ssh-ed25519 是首两个实现，本身就互为"第二调用方"——M1 满足）；attestation 字段在 receipt schema 预留 optional。
- **验收谓词**：P2 起 shipgate 增加"具体算法类型名不得出现在 daemon 业务模块"的 grep 谓词（只许出现在 signer 实现目录）。

## ADR-014 Apple Intelligence 接入姿态（用户 2026-06-10 裁定：预留可能）
- **接入面 = App Intents**：未来 macOS 27 Apple Intelligence（Siri/Spotlight/Visual Intelligence）接入 TuringOS 的唯一通道是 **App Intents 作为 typed Action API 的系统投影**——intent 注册表与 `contracts/typed_actions.schema.json` 一一对应，模型/系统永不直接组合本 app 的 UI（WWDC25 官方架构，R_GENUI_memo §2.2）。
- **级别红线**：仅 **L0/L1** action 可注册为 App Intent；**L3/L4 永不可被系统 AI 一句话触发**（与 RATIFICATION_POLICY 仪式稀缺性一致；R_GENUI R7 的谓词形态：intent 注册表 × typed_actions level 交叉校验，level≥3 有对应 intent 即门禁红）。
- **实体投影**：暴露给系统 AI 的 entity 只来自 Projection API（read-only、携带 provenance、projection-safe 字段分级——ADR-011/PROJECTION_POLICY 原样适用）。
- **接线时点**：P1 不实现；SwiftUI 壳的 action 分发层从第一天按 typed_actions 编排（本就是 D4 架构），届时接 App Intents 是纯增量。

## ADR-015 单仓完全移植（用户 2026-06-11 终裁；取代 ADR-009 的双仓拓扑，保留其边界纪律为仓内法律）
- **裁决**：**完整版 turingosv4（当前 main，194 门禁，含全部已并 OS 成果）作为内核进入本仓** `runtime/` 目录；turingos.app 既有的一切（daemon/SwiftUI/contracts/harness）**全部保留**——daemon 是 GUI 的投影/传输层，不是第二个宪法内核；宪法语义唯一存在于 runtime/。
- **锚点**：当前 v4 main，具体 rev 经「锚点再验证 protocol」（干净 clone：workspace 测试 + 194 门禁 + pin 全扫 + 新红编目 + 热点 diffstat 定向核查）通过后钉入 PINS。**U 项（R1.9B：banner 回灌等）必须先于钉 rev 并入 v4 main。**
- **导入方式**：squash 单 commit，message 记录 `turingosv4@<rev>`；可溯性 = 导入 commit + v4 原仓存档。
- **基线棘轮**：基线 = 194 门禁绿 + workspace 绿（除再验证编目的例外红）；例外清单**只缩不扩**、每红绑 owning atom、清零后定义永久锁回"全部绿"。
- **边界纪律（承 ADR-009，仓界变目录界）**：壳/daemon 代码 **import runtime internals = grep 谓词红线**；消费只经 `turingos` CLI（按 docs/CLI_ABI.md，非合规命令隔离适配）或显式 atom 添加的 lib facade。runtime/ 的 194 门禁 + workspace 测试成为本仓 CI lane（**内核的宪法随内核迁居**）。
- **v4 原仓命运**：U 项落地 → 钉 rev → 导入基线绿 → PR #283 打 tag `archive/p1-realvalue-20260605` 关闭 → 本地分支清理（已授权）→ archive 只读。唯一真相自此在本仓。
- **质量裁决存档**：S3=0（无模块需移植即重写）；五项编目债务（fail-open stub / 签名测试洞 / CI 盲区 / CLI 七律 1/29 / transition_ledger S2 + 留痕清单）拴定各自 owning atom，详见 research/R1.9_memo.md §⑤ 与 R1.9_synthesis.md。

## ADR-016 无限缩放 Galaxy 望远镜（用户 2026-06-14 裁定，/goal 授权自主执行）
依据 R-stage 备忘 `research/R1_infinite_zoom_memo.md`。把 galaxy 从「每项目横轨道 + 分支计数」重做成**无边际画布 + 无限语义缩放望远镜**：项目（深空）→ 项目星系/簇 → 分支/worktree → commit → （P5+）ChainTape 决策节点；每档**只渲已观测的**，跨阈值换表征（聚合 glyph→簇泡→节点卡→全内容）。
- **推翻 V6 默认宏观视图**：本 ADR 推翻 `design/V6_RECONCILIATION.md` §1 冻结的默认初始视角（centerWorld scale 0.25 压缩态宏观），改为无限缩放望远镜的默认取景。授权来自 ADR-012 停点/共创权（用户 2026-06-14 解锁），按本文件首行纪律走 RATIFICATION_POLICY 新条目立案、**不静默改默认**。**收工配真机截图视觉签字**——视觉忠实度是主观判据，走 RiskFinding + 用户签字，**绝不冒充机械 predicate / 绝不假绿**（M6）。UI 实现期执行 agent 持设计自主权（ADR-012 增补/DESIGN.md），重大转向呈报。
- **commit 观测层（A1_52，daemon/内核轨）**：daemon 新增 `CommitObserved` 事件让 commit 粒度可观测（今天 daemon 最深只观测到分支顶点，无 per-commit 事件——见 memo §1）。契约**加性演进**（`contracts/README.md` 规则 4：加枚举值 + 同 PR 加 fixtures，向后兼容、不删改既有字段/语义）。事件**有界窗**（每分支仅 merge_base..tip 的 ahead-commit + 默认分支近 N 条）——**只发已观测 commit，绝不无界喷发、绝不伪造**。
- **渲染 = Metal 实例化 + SwiftUI a11y overlay 混合**：MTKView 实例化画密集视觉层；节点卡 + 可达性镜像层保留 SwiftUI（VISUAL_SEMANTICS rule 3「可达性 0/1 谓词覆盖」+ 现有 `RadarNode.accessibilityLabel` 测试不得退化）。任何 macOS 27-only Metal API 必须 `#available(macOS 27,*)` + 源文件级隔离（ADR-008），CI 26.5 SDK 仍整体编译。
- **tile-tree / LayerProvider / DeferredRef = 内部 app 结构（非契约）**：照搬 3D Tiles tileset 模型从空间泛化到语义粒度；`LayerProvider{getTile,getChildren}`，`GitProvider` 服务 project/branch/commit，`DeferredRef("chaintape",…)` 对齐 `DeriveSource::Chaintape`，decision 层 **leaf-until-provider** 至 P5+（未注册=叶子、绝不渲合成决策节点）。若 P5+ 需跨进程边界再提 `contracts/*.schema.json`。
- **诚实律不变**：绿 BY LAW 保留——分支/commit 节点永不上 merged-green，`merged_into_default` 恒 false，`contained_in_default` 仅可达性（中性呈现）；sound merged-green 留 **A1_53**。trust 色只从 `event_stream.schema.json` 的 `trust_state` 枚举映射；项目辨识色=第二通道只上身份表面（VISUAL_SEMANTICS rules 5-7）。
- **边界（不重开）**：本 ADR **不修改 ADR-012 自身**（用其权、不改其文）；不碰 `runtime/` trust-root（ADR-015）；零跨项目边（ADR-009）；导航留 macOS 菜单不加侧边栏（A1_30）；纯投影消费者零 git 调用（ADR-005）。L3/L4 域动作仍需用户显式批准。
- **落点**：`research/R1_infinite_zoom_memo.md`（R-stage 备忘）+ `specs/atoms/{A1_52_*, A1_51a_*, A1_51b_*, A1_51c_*, A1_51d_*}.md`（A1_51 拆为 a/b/c/d + A1_52 daemon）。

## ADR-017 Canonical-Main 真主线 + 未合并分支即机会（galaxy 数据模型；用户 2026-06-15 裁定，待签字）
依据 `research/R1_canonical_main_memo.md`（调研 wf_3a765aaa + 对抗审查 wf_35cdeba3，均真机实证）。纠正 ADR-016/A1_51 落地中的 **local-centric 缺陷**：今天 galaxy 主线 = `gh default_branch` 字符串等值（实测把用户自己仓库 turingos.app 的临时分支 `claude/brave-knuth-5uo3ce` 画成中心），分支发现 100% 远程、本地未 push 工作不可见。本 ADR 立 galaxy 的诚实数据模型：**找到项目真正的主线，把散落的本地+远程未合并分支当机会点全局外显**。
- **A. Canonical 主线 = 诚实级联 + RefReconciliation 一等对象,绝不静默选王**。每项目并行观测「远程 default」(gh `defaultBranchRef` / `git ls-remote --symref` 活值,缓存 origin/HEAD 仅离线且标 stale) 与「本地 trunk」(刷新 origin/HEAD → main/master 启发,**永不用任意 local HEAD**),各为**独立观测事实**带 `source` 枚举 + `observed_at`。发 typed `RefReconciliation{remote_default, local_trunk, relation}`;`relation` ∈ {agree, ref_differs_same_oid, oid_differs, remote_unobserved, local_unobserved} = **纯观测元组函数,缺失侧显式 *_unobserved,绝不推断**。一致→脊柱;分歧→galaxy 核心画两候选锚 + gap-arc(长度=真实 commit 距离;未观测=虚线"距离未知")。
- **B. commit-OID = 唯一节点身份,ref=折在 commit 上的标签**(落地 ADR-016/model B;RadarModel 今天仍 3 个不相交数组=回归,本 ADR 纠正)。同 OID→一节点多标签;异 OID→两节点,差距=**真实 parent-edge 图距离**(非 `base+k*divergence` 装饰算术)。两 OID 间边**仅当中间 commit 全已观测才实线**,否则显式"省略/未观测跨度"边带 `truncated`(daemon 250 截断 flag 外显不吞)。
- **C. 同时发现本地 + 远程分支**:加本地 git 观测(`for-each-ref refs/heads`+upstream;reflog/stash/被删分支 tip = 游离工作)发 `LocalBranchObserved`/`LocalCommitObserved`(provenance `local-only`)。provenance 四态 {local-only, remote-only, both-synced, both-diverged};**游离/无分支本地工作 = 一等机会节点**,中性标"local-only, unreferenced"+中性年龄,**永不 abandoned/dead/debt**,绝不投成远程信任态。
- **D. 多脊柱/森林为一等可能**:trunk-candidacy 是多值**观测**属性(is-remote-default / is-local-trunk / name-matches / 高入度);>1 候选分歧时脊柱**可见分叉**,不静默选王(turingos.app 即当下实例)。smartlog 拓扑:脊柱省略已合并内部,未合并分支按距-trunk 发散度散布。
- **E. 机会 = tape 上的 fold,可重放;权重 = 纯确定函数**。`opportunity_weight(seq)` 按 **seq** 锚定(非 wall-clock),= 观测整数的纯字节确定函数(独有 commit 数 + 由 `observed_at` 派生的 recency);信号全中性可 sound 观测(距 trunk ahead/behind、独有 commit 数、活动年龄、provenance、contained=可达性≠已合并)。**主观排序走 RiskFinding/产品判断,绝不冒充 {PASS,FAIL} predicate(红线 4)**。机会升进**第 4 个 `AttentionSeverity.opportunity`**,走现有 triage→AttentionTarget→radar fly-to 管线(须把 AttentionTarget 扩成通用 `nodeIds`、RadarScene.resolve 支持任意已定位节点)。Meta Orb scope=注视点 = 机会动词,接已写好但死的 A1_41(WorktreeResearch.gather+proposeWorktreeTask),生成文走 R3 灰徽+R8 证据共置、只 L≤2 propose。
- **视觉区分(颜色+美学,用户点名;每区分带非颜色腿、过灰度测)**:**结构一律 achromatic 白-alpha + 项目 accent(Tokens.Accent),语义六色只留信任态,branch/commit 永不上语义色/永不上绿**。① 脊柱=几何+光度(中心轴线+axisSweep+唯一白 halo+双描边环),普通分支=轨道小 accent 点;② 四态 provenance=描边形状(实线/点线/长虚线/双环带缝)+sf 字形,非色相;③ 远程↔本地分歧=**黄**(唯一正当语义复用)tension 边慢脉冲+⚠+一句话,halo 达成一致前 withheld;④ 机会权重=连续 bloom(glow 半径×环厚)+轨道半径,**绝非计数网格**(Software3.0 §3);⑤ 陈旧=热力冷却(向冷背景 LERP+glow 衰减,≥0.25 地板),中性不是债红/不是语义灰。
- **诚实律红线(必钉)+ 一并修的现存假象**:(1) 每事实加 `observed_at`+`source`;**recency 只能由 observed_at 派生** —— BranchFact 今天**无任何时间戳**,补字段前"年龄"是纯虚构。(2) **swimlane 行序必须是观测 parent-DAG 拓扑排序(Kahn over parentShas),时间戳仅 tie-breaker** —— 今天 RadarModel 按 ISO 字符串排序=虚构了 DAG 里没有的顺序(审查实锤)。(3) `merged_into_default` 恒 false、contained 仅可达性、popover 必带「≠ 已并入内容」。(4) `cross_source_state`(agree/diverged)是**新加性字段**,不重载 `provenance`(观测来源标签);走 contracts/README 规则 4。
- **覆盖(显式退役)**:本 ADR **退役/覆盖 `design/V6_RECONCILIATION.md` / DESIGN_SPEC_V6 中 green=#34D399「Merged 节点」(冰冻态) 规格** —— 直接抵触诚实律(merged-green 已判 unsound,承 A1_50/ADR-016);本方案 branch/commit 结构全 achromatic+accent,绿无插槽。按本文件首行纪律走 RATIFICATION_POLICY 立案,不静默改。
- **边界(不重开)**:不碰 `runtime/` trust-root(ADR-015);零跨项目边(ADR-009);契约只加性演进(规则 4);纯投影消费者零 git 调用本 ADR 不改(daemon 才做 git/gh 观测);L3/L4 域动作仍需用户显式批准;真机视觉签字按 M6 走 RiskFinding 不冒充 predicate。
- **落点(拆卡待开,一次一颗配真机签字)**:daemon 本地观测+级联 trunk+RefReconciliation 事实 / OID-身份 scene 重构(含 swimlane 拓扑排序修+边-未观测诚实) / 机会 fold+第4 triage 档+AttentionTarget 扩 nodeIds / 视觉方案(provenance 形状+分歧黄+机会 bloom+冷却) / Meta Orb 接 A1_41。UI 那几颗(A1_57 popover/A1_58 内容/A1_60 全屏/A1_61 丝滑)押在模型定后,因都依赖之。

## ADR-018 主线判定 = 指定类信号,活跃度永不选王（refine ADR-017 trunk-candidacy；用户 2026-06-15 四问全批推荐）
依据 `research/R1_mainline_convention.md`（10-agent 研究+对抗 workflow wf_ac035e39：5 研究 facet 行业共识 + 3 对抗 lens 信号可靠性/森林多主干/宪法诚实律）。**refine 并部分退役 ADR-017 的 trunk-candidacy 信号**：ADR-017-D 把 trunk-candidacy 列为多值观测含「**高入度**(descendant-count)」——对抗实测此信号（及 first-parent 深度、recency）在本 repo **反转**：`--contains` 高入度选回陈旧 `brave-knuth`、深度 workflow-依赖（turingos.app 49 merge 但 first-parent 深度仅 68，squash/rebase 下翻转）、GitFlow 下把 `develop` 选成 `main`。本 ADR 立**指定类（designation-class）判定**：
- **A. 一句话原则**：PRIMARY 主线由**指定类**信号选出，**不由活跃度**。行业共识（git-branchless `mainBranch` / Sapling / GitKraken pin / GitLens / pvigier git-graph）= 拓扑提议、指定裁决。**first-parent 深度 / recency / descendant-count 永不做选择器,只做 liveness/layout 标注**（红线）。
- **B. 判定级联**：rung0 人工 pin（`PinObserved` 事件，本期**先桩缓 UI**）→ rung1 **live** `ls-remote --symref origin HEAD`（**非缓存 symbolic-ref**=陈旧）且命名常规分支(main|master|trunk)且 ancestry 不反对 → rung2 **ancestry 消去**（`merge-base --is-ancestor`，丢严格祖先/0-ahead 被包含者）+ **名称优先级**(main/master>trunk>develop>release/*) 破僵 → rung3 仅"无 compare 可观测的单候选无常规名共存"才 provisional → rung4 名称存在性 → rung5 fail-visible。
- **C. 三 fail-visible 终态（rung5）**：`mainline unobserved`（空仓/0-branch，**非空枚举是离开 rung5 的硬前置**）/ `mainline ambiguous — N spines`（>1 分叉幸存仅靠活跃度可分，或配置默认是某非常规名长寿线的严格祖先=真主线未命名）/ `declared default vs main, ancestry unobserved`（compare 限流且二者共存）。**绝不**在廉价可知陈旧的分支（如 brave-knuth）上画哪怕灰脊柱。「一主线必存在」由**可观测时指定**满足,**非**臆测满足。
- **D. 三类别**（覆盖 ADR-017 两类）：PRIMARY（恰一,最左直 first-parent 脊柱）/ **MAINTAINED CO-TRUNK**（release/*|*-stable|hotfix/*|vN.x，并行维护脊柱，显式非"探索"——把生产维护线叫探索是语义谎言）/ SECONDARY 探索 lead（绕主线，ahead/behind 对**纠正后 mainline_ref** 而非陈旧 ctx.default_branch=load-bearing base-correction）。
- **E. 诚实律续**：`merged_into_default` 恒 false（承 ADR-016/[[reference_github_merged_detection_unsound]]，无 cheap ancestry/PR 升级）；严格祖先**且在 first-parent 脊柱上**才折叠，否则（如被 revert 的可达祖先）保留为降权可见 secondary（绝不结构性 false-absorbed）；recency 只冷却不熄灭，唯一终态=观测删除（gone≠abandoned）。**A1_62 `relate()=Agree` 不可读作"主线正确"**（它比 remote-default vs **缓存** origin/HEAD，二者镜像、都陈旧）；{配置默认, A1_62 local_trunk}=**一个** owner 声明事实，唯一真第二信号 = 常规名 reachability 探针，**无条件运行**。
- **F. 实现两遍 reduction**：主线判定**非** per-branch 局部 → daemon PASS A gather（无条件于缓存/声明）+ PASS B reduce → `mainline_ref`+TrunkSource tier+relation；`is_default` 改 reduction 后 DERIVED 字段（非 parse_branch_list:289 早 stamp）；`mainline_ref` 作 compare base/recent sha/default_ref；扩展 RefReconciliation 携 relation=default_behind_named；derive_from_tape 守恒测（Art.0）。**app 同原子**：补缺失 .refReconciliation fold（今天 AttentionModel 无此 case→reconciliation 到不了投影）、isAnchor 吃 mainline_ref、渲染 provenance tier + 三 fail-visible 态 + co-trunk 类（rung3 provisional + rung5 chrome = load-bearing no-false-green，**不可 defer**）。
- **G. 残留（非 blocking，留痕）**：常规名候选集封闭（特异名真主线 production/mainline-v2 需 pin/可配置名单，后续 atom）；ambiguous 比原设想更常触发（=诚实代价，pin 逃生口本期仅桩）；co-trunk 名称模式启发（特异名维护线漏判、死 release/old 误渲）；gh compare 限流间歇 blank（honest-blank>confident-stale，用户已批）。
- **H. 路径缺失库**（~22 个含 turingos.app 自己）：花 gh compare 解析常规名，失败→rung5 不画临时脊柱（用户决策2批）。
- **落点**：A1_63a = 主线真相+诚实锚（daemon 两遍 reduction + app fold/锚/chrome 同原子）；A1_63b = Railroad Swimlane 几何（OID-身份 scene + topo lanes + first-parent 脊柱 + merge_base 边 + 三类别成 lane）。按首行纪律走 RATIFICATION_POLICY，不静默改 ADR-017。
