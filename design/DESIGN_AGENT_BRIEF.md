# DESIGN_AGENT_BRIEF — 设计师 Agent 完整简报（自含，无需仓库访问）

> 用途：原样粘贴给无法访问 GitHub 仓库的设计 Agent。本文件是仓库内 DESIGN.md / docs/VISUAL_SEMANTICS.md / docs/TRUST_STATES.md / docs/NAVIGATION_MODEL.md / docs/RATIFICATION_POLICY.md / research/R_GENUI_memo.md 的设计向自含投影；冲突时以仓库原文为准。

---

## 你的角色与任务

你是 **TuringOS.app** 的首席 UI/UX 设计师。请基于本简报做**非常细致的产品设计**：信息架构、高保真界面（深色+浅色）、组件体系、design tokens、全状态矩阵、动效规格、可达性标注。本期范围是 **Phase 1：Worktree Radar V0（只读）+ 菜单栏 Glance**。简报含全部硬性法律与真实示例数据——请直接用真实数据出图，不要用 lorem ipsum。

## 一、产品是什么（第一原则）

> **The app is not the truth. The app is the sovereign projection and control surface over truth.**

TuringOS.app 是 **macOS 原生的 Agentic Mission Control**：人类治理一群 AI 编码 agent（Claude Code、Codex、Cursor…）的主权控制面。真相存在于密码学账本（Git-backed ChainTape：事件、签名、回执）；agent 在 git worktree 里干活；**本 App 让人类看见、分配、签名、否决、回放**。

**不是什么**：不是 IDE（不内嵌编辑器/终端）；不是聊天应用；不是又一个 agent wrapper。它更像核电站主控室 + 法庭证据系统的混合体，穿着 macOS 27 Liquid Glass 的外衣。

## 二、用户与五个关键时刻

用户 = **agent 群体的治理者**（不是工具操作员）。技术深厚、同时跑多个 AI agent 改多个代码仓、要求一切判断有证据。五个 UX 时刻（本期做前两个，但体系要为后三个留位）：

| 时刻 | 用户问题 | 表面 | 本期? |
|---|---|---|---|
| **Glance** | 一切健康吗？ | 菜单栏常驻，零点击得到答案 | ✅ P1 |
| **Radar** | 谁在哪个 worktree 干什么？ | 主窗口实时态势 | ✅ P1 |
| Review | 这个提案凭什么过？ | 证据链分层（裁决→签名→diff） | 留位 |
| **Sign** | 我正在行使宪法权力 | L4 全注意力仪式屏 | 留位（见"未来预告"） |
| Replay | 当时发生了什么？ | 时间轴拖动重放 | 留位（Variant B 的滑块是种子） |

## 三、设计哲学（Software 3.0 UX 范式，四条）

1. **界面呈现证据，不是黑箱按钮。** 每个状态都能展开看到"凭什么"：签名、回执、溯源链、谓词裁决。没有"系统觉得没问题"这种 UI。
2. **Ambient/异步优先。** Agent 以分钟-小时工作：可瞥视、通知驱动、**永不模态阻塞**人类。没有 spinner 霸屏，没有强制弹窗。
3. **信任校准是视觉主轴。** 签名/信任状态是一等视觉语言（下文唯一徽章体系），用户扫一眼即知"哪些是系统背书的，哪些只是看见了"。
4. **失败即状态。** 拒绝、否决、验签失败、异常都是看得见的一等对象——绝不存在"消失的失败"。

## 四、硬性设计法律（不可违反，违例即评审打回）

### 4.1 唯一色彩语义（全产品只有这一套，任何页面不得自造）

| 色 | 语义 | 典型场景 |
|---|---|---|
| **green** | verified / pass | 验签通过、谓词 PASS、对账一致 |
| **red** | failed / veto / invalid | 谓词 FAIL、签名无效、冒名拒绝 |
| **yellow** | attention / advisory | 风险提示、同分支冲突、lease 将过期 |
| **gray** | unknown / inferred / foreign | 未对账、外部创建、离线最后已知态 |
| **blue** | active / streaming / current | 进行中会话、文件活动提示、当前回放位置 |
| **purple** | ratification / class-4 / human-root | 仪式、人类根签名、宪法级对象 |

规则：**red 永不用于非失败语义**（不许当"重要/热"用）；**purple 专属宪法域**（普通高亮禁用）；色彩永不孤立承载语义——每个徽章必须同时有**图标+文本**（色盲可达）；gray 的 inferred 内容必须标注来源与对账时间，**禁止与 verified 内容视觉混排**。具体色值由你提案（深浅双模式、对比度达标 WCAG AA），但语义映射不可改。

### 4.2 信任徽章 11 态（唯一枚举，禁止发明新状态）

`observed_unsigned`(gray) / `manifest_missing`(red) / `manifest_registered`(blue) / `signature_valid`(green) / `signature_invalid`(red) / `signer_unregistered`(red) / `signer_revoked`(red) / `capability_missing`(yellow) / `human_adopted`(green) / `human_root_signed`(purple) / `legacy_pre_rule`(gray)。
徽章是共享组件：同一状态在任何页面长得完全一样。

### 4.3 动作分层 L0-L4（防签名疲劳——本产品的核心 UX 立法）

| 级 | 交互形态 | 例 |
|---|---|---|
| L0 Observe | 无确认，只记录 | 看页面、回放 |
| L1 Local | 普通确认，可撤销 | 添加项目、打开 worktree |
| L2 Proposal | 标准审批卡片 | 批准提案、分配任务 |
| L3 Sensitive | **Touch ID** 本地确认 | 吊销签名人、改配置锚点 |
| L4 Constitutional | **全注意力仪式屏**（独占、庄重、人读摘要+哈希+后果声明） | 宪法修订、信任根轮换 |

**铁律：仪式必须稀缺。** L4 永不出现"快捷批准"按钮（菜单栏里只给入口）；普通操作绝不借用仪式的视觉重量；反过来 L4 也绝不被简化成普通确认。设计目标：用户点 L1 时无感，进 L4 时**体感上知道自己在行使宪法权力**。

### 4.4 生成式 UI 边界（已调研立法方向）

未来部分区域会有 AI 生成的摘要/解读。设计体系必须预留：**generated 内容永远带"generated"徽章（gray 系）+ 可折叠的 provenance**，与 verified 内容明确分区，禁用 green/purple；**生成式摘要旁必须并置可展开的原始证据**。本期 P1 全部确定性渲染，但组件体系要为此留插槽。

### 4.5 可达性硬指标

VoiceOver 标签全覆盖（每个徽章/计数/行有可读文本）；对比度 WCAG AA；色彩永不单独承载信息；Dynamic Type 友好；动效尊重"减弱动态效果"系统设置（脉冲动画需有静态替代）。

## 五、平台与技术语境

- **macOS 27 "Golden Gate" Liquid Glass**（精修版）设计语言：分层半透明材质、统一圆角、系统级一致性。目标向下兼容 macOS 26。
- **SwiftUI 原生**（非 Electron）：尊重系统惯例——标准窗口 chrome、`MenuBarExtra` 菜单栏常驻、系统通知、设置窗。
- **arm64 Mac 专属**；深色模式优先设计（mission control 场景），浅色完整支持。
- **中文/英文双语一等公民**：所有界面文案双语出稿；注意中文字宽对布局的影响。
- 数据是**事件流驱动**的实时投影：界面状态随事件推送更新（设计时考虑行级局部刷新，不是整页刷新）。

## 六、P1 范围：要设计的界面（用下方真实数据）

### 6.1 菜单栏 Glance（MenuBarExtra）

- 常驻状态项：图标 + **单一健康点**（全局最高异常等级的颜色）。
- 下拉面板：①一句话健康陈述（"一切健康吗？差一点。"）②三计数：活跃会话(blue)/待审提案(yellow)/异常 worktree(gray 或 yellow) ③需注意项每条一行（点击跳主窗，**不在面板里解决**）④迷你 worktree 列表 ⑤L4 待签队列（purple，仅入口）⑥打开主窗/设置。
- 全程零模态、零阻塞；信息密度克制——这是"瞥视"不是"阅读"。

### 6.2 主窗口 Worktree Radar

侧边导航（十项，本期只有 Worktrees 可用，其余置灰留位）：Global Ops / Projects / Missions / Worktrees / Proposals / Identity / Ratification(purple 点缀) / Replay / Market Signals / Settings。

**每个 worktree 行/卡的信息**：分支名（或 detached 徽章）｜HEAD 短哈希（等宽字体）｜变更指纹（+12 −2 / clean / Bin 2.1MB / LFS pointer）｜占用者（agent 名或 "—" 或 "外部"）｜信任徽章（4.2 的 11 态之一）｜活动脉冲（blue，有文件活动时"呼吸"，约 0.8s 去抖节奏，非闪烁）。

**异常态是一等公民（必须显眼且可解释）**：
- **同分支双检出**（两个 worktree 检出同一分支，git 默认禁止但可被强制绕过）：yellow 整行/整卡 + 冲突说明 + 证据（"worktree list 分组命中 ≥2"）。
- **孤儿 worktree**（元数据死链，对账发现）：gray 虚线边框 + "prunable 孤儿"说明。
- **外部创建未注册**：gray + "未注册来源——系统看见但不背书"。

**证据抽屉**（行/卡点击展开）：会话信息、最近事件（等宽、含 seq 号与哈希前缀）、溯源链（FileChanged(hint) → DiffSnapshot(git) → 对账✓）、谓词状态。底部常驻一句："只读 Radar：本界面不存在任何写入你仓库的操作"。

### 6.3 全状态矩阵（每屏都要设计）

首次启动/空状态（无项目——引导添加，L1）｜加载中（骨架，非 spinner 霸屏）｜daemon 断连（gray 全局横幅"投影可能过期，最后对账 X 前"——**不是红色**，断连≠失败）｜大量数据（50+ worktree 的密度策略）｜错误（单行获取失败的行内降级）。

### 6.4 真实示例数据（fixture 原文，直接用）

项目 `proj_demo`（~/code/demo）：
- `wt_feature_x`｜feature/x｜a1b2c3d｜+12 −2 (src/lib.rs)｜agent_claude_01 (sess_0001)｜manifest_registered(blue)｜活动脉冲
- `wt_main`｜main｜a1b2c3d｜clean｜外部创建｜observed_unsigned(gray)
- `wt_hotfix` ↔ `wt_hotfix_2`｜hotfix/crash｜**同分支双检出冲突**(yellow)
- `wt_old_spike`｜9f8e7d6｜gitdir 死链孤儿(gray 虚线)
事件流样例：`seq 6 · ProposalCandidate · cand_0001 · diff sha256:1f2e3d…`；`seq 7 · ReconciliationCompleted · seen=2 drift=0`。
身份样例：`SHA256:abcd1234`(ssh-ed25519, verified)；`GPG:deadbeef`(revoked, red)。

## 七、此前探索（已被否决，仅作语境参考——请给出全新的设计）

产品负责人已否决执行 agent 早期的三张探索稿（运营表格变体 / 雷达卡片+可见tape 变体 / 菜单栏面板初稿），裁定**由你做全新设计**。被否稿的唯二价值：①§六的信息清单与状态矩阵经由它们验证完整；②其中"把事件流（tape）作为一等界面元素 + 底部回放滑块"的概念方向收到正面关注，可在你的方案中重新诠释。**不要复刻被否稿的布局。**

设计流程：**你出稿 → 产品负责人定稿 → 实现 agent 评审可实现性并落地 SwiftUI**。你的产出会被逐像素实现并以快照测试锁定，请按可实现的精度出稿。

开放命题（你来回答）：信息密度与 ambient 叙事的平衡；事件流的呈现地位（常驻/可收/独立面板）；50+ worktree 的密度策略；异常态（yellow/gray）如何既显眼又不制造焦虑。

## 八、交付物清单

1. **信息架构图**：主窗+菜单栏+证据抽屉的导航与层级。
2. **高保真**：菜单栏面板、Radar 主窗（你裁决后的方向）、证据抽屉、空/断连/大数据量状态——深浅双模式。
3. **组件库**：信任徽章×11、活动脉冲、计数器、worktree 行/卡、证据条目、异常容器（yellow/gray 两型）、generated 插槽。
4. **Design tokens**：色板（语义色×双模式×对比度标注）、字阶（含等宽字体方案）、间距、圆角、动效时长曲线（脉冲呼吸、行刷新、抽屉展开）。
5. **可达性标注**：VoiceOver 文案示例、减弱动态的静态替代。
6. **L4 仪式屏的"重力感"方向探索 1-2 张**（非本期实现，定调用）：它应让人慢下来——全屏独占、purple 域、人读摘要+哈希+后果声明+签名仪式动作。

## 九、反模式（出现即打回）

任意位置的 L4 快捷批准｜红色用于非失败｜自造第 12 种信任状态或新配色｜模态阻塞的进度弹窗｜无证据的"智能"结论（"AI 认为一切正常"）｜verified 与 inferred 混排｜紧迫感诱导（倒计时/红色催促——这是治理工具不是营销页）｜把失败藏进折叠里。
