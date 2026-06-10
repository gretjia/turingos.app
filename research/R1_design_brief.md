# R1 设计简报 — Worktree Radar V0（停机点呈交件）

> 依 ADR-012：本简报与五项关键裁决（D1-D5）经用户确认后，方可产出 P1 Atom 卡集。
> 内核问与体验问双轨并答；证据见 [R1_memo.md](R1_memo.md)。

## 产品时刻定位

P1 交付 **Glance** 与 **Radar** 两个 UX 时刻的 V0：用户把项目交给系统后，**零点击**即知一切是否健康（菜单栏），**一眼**即知谁在哪个 worktree 干什么（主窗口）。只读——本 Phase 不写用户仓库一个字节。

## 五项关键裁决（D1-D5，等待用户确认）

### D1 部署目标 = macOS 26（建议）

全量 Liquid Glass；覆盖 26+27（27 精修经 SDK 重编自动生效，无 hard API delta——judgement，27.x 复核）；不下探（产品前提 Software 3.0 原生，P2 需现代 SE 栈）。**确认后 PINS.toml stable lane 钉 Xcode 26.5 / Swift 6.3.2 / target macOS 26（UpdatePins = L3，需您批准——本简报确认即视为批准）。**

### D2 入口形态 = MenuBarExtra 常驻 + 主窗口 Radar 并举（建议）

- **菜单栏（Glance）**：状态点（全产品最高异常等级的色语义）+ 三计数（活跃会话/待审提案/异常 worktree）+ 点击下拉迷你列表。永不弹窗打断。
- **主窗口（Radar）**：项目 → worktree 行视图。NAVIGATION_MODEL 五问已立法，P1 实现其 Worktrees 页。

### D3 Radar 信息架构（行级语义）

每行 = 一个 worktree：`分支(或 detached 徽章) | HEAD 短哈希 | dirty 指纹(±行数/Bin/LFS) | 占用者(agent/human/未知) | trust badge | 活动脉冲(FSEvents 脏信号, blue)`。
特殊行：**同分支双检出冲突**（`--force` 可造成，正常不该有）→ 整行 attention(yellow) + 显式冲突说明；**prunable/gitdir 死链** → foreign(gray) + 「对账发现的孤儿」；外部工具创建的 worktree → gray「未注册来源」。失败与异常永远是看得见的状态。

### D4 数据通路 = Rust daemon 看守 + Swift 纯投影（建议，本裁决影响最深远）

```
git repo ──(git2 枚举 + porcelain -z 快照)──> turingosd(Rust)
FSEvents 脏信号 ──(notify crate, FSEvents backend)──┘   │
                                    UDS + JSONL 事件订阅(契约: event_stream.schema.json)
                                                        ▼
                                              SwiftUI App = 纯投影消费者
```

- 与 ADR-005/011 同构：daemon 是唯一内核，Swift 壳**只消费投影**——未来 iOS 遥控面零返工。
- P0.5 渲染器证明的 `events → projection → view` 链在 P1 原样升级：fixtures 不变，渲染端换成 SwiftUI。
- 备选（被否方案）：Swift 直接读 git——更快出活，但身份/签名/对账逻辑日后必须搬回 daemon，等于把 ADR-005 推迟成债。
- **风险登记**：notify crate 的 FSEvents backend 未实证（R1 UNVERIFIED #7），P1 第一颗内核 Atom 即做 spike，失败则降级为「daemon 周期对账 + Swift 侧 FSEvents 转发」，契约不变。

### D5 验收形态 = 三层

①macOS CI lane（`runs-on: macos-26`，xcodebuild 构建+单测+golden 快照测试）进 shipgate p1；②Rust 测试继续 Linux lane（peer-cred trait 抽象，macOS pid 路径 CI 实测补 UNVERIFIED）；③**Phase 末视觉评审 checkpoint：您的 Mac 首次出场**（Liquid Glass 手感 + VoiceOver 走查，主观美学走人类评审——M8）。

## 双轨反向塑形（本期新增登记）

| UX 需求 | 反向塑形 |
|---|---|
| 活动脉冲要「呼吸感」而非闪烁噪音 | daemon 端 FSEvents 去抖窗口成为协议参数（事件信封新增 debounce 元数据，schema minor 扩展） |
| 菜单栏三计数要恒时可信 | daemon 必须维护常驻聚合投影（不是查询时现算）——投影守恒测试覆盖 |

## P1 不做（防镀金）

不写用户仓库；不做 diff 全文查看器（P6 提案审阅的职责）；不做 worktree 创建/删除（P4-P5）；不递归 submodule 内部；不做多机。

## 确认方式

回复确认/修改 D1-D5 任意项。确认后我自主执行：PINS 钉版 → Atom 卡集（预计 6-8 颗：daemon 骨架/枚举快照/FSEvents spike/UDS 订阅/SwiftUI 壳/MenuBarExtra/golden+CI）→ D-stage 开发 → S-stage 过闸，下次停机即 Phase 末视觉评审。

---

## 停机点裁决记录（用户 2026-06-10）

| 项 | 裁决 |
|---|---|
| D1 | **修改**：面向 macOS 27 设计 + 向下兼容。工程释义（已并 ADR-008）：设计北极星 = 27 的 Liquid Glass 精修形态；deployment target = macOS 26（"向下兼容"的机器含义）；27 专属 API 只做 `#available` 渐进增强；27 GM + runner 就位后整体切主车道，零返工 |
| D2-D5 | **批准** |
| 新增① | UI 设计共创：agent 出草图/效果图，用户参与初期设计与测试（ADR-012 增补 + DESIGN.md 共创协议）；UI Atom 待草图认可，内核轨即刻开工 |
| 新增② | Generative UI 独立调研（Software 3.0 人机交流基石）——后台深度调研中，产出 R_GENUI_memo 后另设停机点 |
| 新增③ | 硬件签名零重构预留 → ADR-013 签名抽象层（Signer trait + key_kind 开放枚举 + P2 即接线） |

### 二次裁决（用户 2026-06-10 后续）

| 项 | 裁决 |
|---|---|
| D1 细化 | **开发直接用 Xcode 27 SDK**，deployment target 维持 macOS 26（ADR-008 已更新：27-only API 源文件级隔离，CI 在 runner 提供 27 前用 26.5） |
| 新增④ | **预留 macOS 27 Apple Intelligence 接入** → ADR-014：App Intents = typed Action API 的系统投影；仅 L0/L1；entity 只来自 Projection API；P1 不实现、架构保证纯增量接入 |

### 三次裁决（用户 2026-06-10，本地会话）

| 项 | 裁决 |
|---|---|
| UI 选型 | **三张效果图（variant-a-operations-table / variant-b-radar-cards / menubar-glance）全部否决**。用户亲自操刀设计，满意稿后续提供——共创方向改为「用户出稿 → agent 评审与实现」。UI Atom 维持门禁阻塞（ADR-012 增补不变） |
| 设计空窗期安排 | 内核轨不受阻：执行 agent 即刻续行 A1_02 → A1_03 → A1_04；另行调研+实证「模型分级路由」工作方法论（Claude 开发层纪律，不触 repo law） |
| R_GENUI §6 R1-R8 | 本次未裁决，**维持待批准状态**（批准后并入 DESIGN.md） |

### 四次裁决（用户 2026-06-10 深夜，本地会话）——UI 轨门禁解除

| 项 | 裁决 |
|---|---|
| 设计定稿 | 用户交付自绘 **V6 Global Workspace Radar**（HTML 原稿 + 防漂移设计规范），即批准的设计北极星。入库 `design/mockups/v6/`；稿内数据全部为 illustration example 非真实数据。星系美学/语义发光/语义缩放/项目独立拓扑四哲学锁定 |
| UX 流程重裁 | Onboard 三段式：**Connect**（无缝接入既有 git 体系：gh CLI 复用 → GitHub Device Flow → 纯本地，逐级降档）→ **Select**（列全部 repo，用户勾选纳管，已完结项目可不进）→ **Observe**（Global Workspace 全景面板默认**压缩态**，可全局观察/[P4+]派任务，或点入单项目操作）。已并入 DESIGN.md Onboard 章 |
| R_GENUI §6 R1-R8 | **批准**。八条设计法律已并入 DESIGN.md（推翻 R1 须新 ADR + L4） |
| 平台 | Xcode 27 beta（27.0/27A5194q + MacOSX27.sdk）已移入 /Applications/Xcode-beta.app——ADR-008 的 27-SDK 开发车道本机就绪（构建经 DEVELOPER_DIR 指定，不动 xcode-select 全局默认） |
| 对账与切片 | V6 ↔ 仓库设计法律逐条对账 + P1-UI atom 卡集见 `design/V6_RECONCILIATION.md`；唯一立法调和 = 项目辨识色第二通道（VISUAL_SEMANTICS 增补第 5-7 条） |

### 五次裁决（用户 2026-06-10，本地会话）——Software 3.0 信息架构重构

| 项 | 裁决 |
|---|---|
| 看板哲学否定 | 此前一切稿件（r1 三张乃至 V6 忠实翻译路线）犯 **Software 1.0/2.0 看板哲学**错误：数据轰炸、用户抓不住重点。以 Software 3.0 理念重构整个软件 |
| 设计自主权 | V6 参考稿**不构成严格约束**；执行 agent 有自主决定权（代码简洁性、贴合内核的设计、更优的 Software 3.0 美学）。调研结果需磋商时才停机 |
| 三定律立法 | 注意力优先 / 语言优先 / 安静即成功 → `design/SOFTWARE3_UX.md`（含反模式黑名单）；V6 降格为材质语言参考；P1-UI 卡集重切：A1_08=Attention Stack Home（取代星系画布首页定位），A1_09=星系 Radar 下钻视图 |
