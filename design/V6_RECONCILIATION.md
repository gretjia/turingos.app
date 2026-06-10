# V6 对账与 P1-UI 实施切片（2026-06-10，四次裁决产物）

> 输入：用户自绘 V6 定稿（`design/mockups/v6/`）+ Onboard 三段式 UX 裁决 + R1-R8 批准。
> 输出：V6 与既有设计法律的逐条对账、立法调和、SwiftUI 翻译架构、P1-UI atom 卡集。
> 原则：V6 给形态与气质；TRUST_STATES × VISUAL_SEMANTICS 给徽章与状态色的唯一法源。

## 1. 逐条对账表

| V6 元素 | 法律对应 | 裁决 |
|---|---|---|
| 语义六色（green/red/yellow/blue/purple/gray） | VISUAL_SEMANTICS 六色语义**逐字吻合** | 直接采纳；色值以 V6 token 为准进 design tokens |
| 项目专属色（blue=turingos 等）兼作 active 色 | 与"唯一语义色"冲突（green 星云≠verified、purple≠宪法域专属） | **立法调和**：项目辨识色=独立第二通道，只许身份表面（星云/巨字/轨道点缀）；状态 chrome 仍由语义色驱动。VISUAL_SEMANTICS 新增第 5-7 条 |
| 节点徽章文案（signature_valid/manifest_registered/capability_missing/manifest_missing/human_adopted） | TRUST_STATES 枚举**逐字吻合**（用户稿直接用了正确枚举值） | 直接采纳；徽章色严格按 TRUST_STATES 附表（V6 个别示例色偏 → 实现按法表） |
| Truth/Active/Merged/Conflict/Orphan 五节点形态 | Radar 行语义（R1 brief D3）+ trust 法 | 直接采纳：Truth=主轴锚点加重；Conflict=⚠ 浮标+黄；Orphan=虚线+低透明（=prunable/gitdir 死链行）；Merged=冰冻绿 |
| Agent Chip + Live Stream（active 节点内） | P1 只读域内无 agent 身份事实（P2 identity / P5 adapters） | 形态保留，P1 以 `occupant` 推断态渲染（gray inferred 标注）；P2/P5 接真实 manifest 后转正 |
| Glance Popover（三 metrics + 高危列表 + L4 入口） | Glance 时刻 + A1_03 聚合投影三计数 | 直接采纳；计数绑定 `prj_glance_counts` 投影 |
| L4 仪式屏（紫色全屏 + hash 框 + Touch ID 行权） | Sign 时刻 + R2（确定性渲染）+ RATIFICATION_POLICY | 形态采纳；P1 仅静态预览入口（P3 实现真仪式管线）；R2 锁死：此屏永不进生成式管线 |
| 语义缩放（<0.6 压缩态） | Onboard 裁决"默认压缩显示" | **压缩态=默认初始视角**（centerWorld scale 0.25 即宏观）；缩放阈值/隐藏清单按 V6 规范 §7.2 逐条实现 |
| 项目间零 Edge（独立拓扑） | ADR-009/PLAN P1（项目=独立 git repo） | 直接采纳，与 daemon 按 repo 隔离的事实一致 |
| 节点拖拽 + 每帧 updateEdges | V6 规范 §7.3 | 采纳（布局状态=本地 UI 偏好，不上 tape） |
| Inter + JetBrains Mono | 旧 r1 美学（Fraunces/IBM Plex）已被否决 | **以 V6 为准**：随 app 打包 Inter + JetBrains Mono（均 OFL 许可）；macOS 回退 SF Pro/SF Mono |
| Web HTML 载体 | ADR-005（SwiftUI 壳） | V6 是设计语言不是技术选型；SwiftUI 翻译见 §3 |
| 稿内示例数据（omega/noosphere/o1-preview…） | — | illustration only；实现绑定 daemon 真实流，禁止复刻示例数据 |

## 2. Onboard 三段式 → 相位切片

| 段 | P1 范围（只读纪律内） | 延后 |
|---|---|---|
| **Connect** | gh CLI 登录态复用 → GitHub Device Flow → 纯本地模式，逐级降档 fail-visible；token 只进 Keychain，永不入 tape/事件流/日志 | — |
| **Select** | GitHub repo 列表 + 本地 repo 发现合并展示；勾选=RegisterProject(L1) 写注册表；**仅有本地 clone 的 repo 可被 Radar**（无 clone 的显示 gray "remote-only"占位） | clone 动作（写盘）延后 |
| **Observe** | Global Workspace 全景（V6 universe，默认压缩态）+ 单项目放大 + Glance | **派发任务给 agent = P4/P5**（Missions/lease/adapters）；入口可见但 disabled（NAVIGATION_MODEL 既定） |

## 3. SwiftUI 翻译架构（ADR-005/008 内）

- **数据通路不变**：daemon UDS JSONL 订阅（A1_03 既有）→ Swift 解码 EventEnvelope → 投影 fold → SwiftUI 视图。app 是纯投影消费者，零 git 调用。
- **画布**：SwiftUI `Canvas` + 手势（MagnifyGesture/DragGesture）实现 pan/zoom/语义缩放；节点卡为 overlay SwiftUI 视图（保留可达性树，满足 0/1 谓词），连线/星云/轨道在 Canvas 绘制。
- **构建**：本机 `DEVELOPER_DIR=/Applications/Xcode-beta.app`（27 SDK）；deployment target macOS 26；27-only API 源文件级隔离；CI xcodebuild 用 runner 现有 26.5（ADR-008）。
- **UDS 客户端**：Network.framework `NWConnection` 对 UDS 的支持待本机实测（R-stage UNVERIFIED），降级方案 = BSD socket 薄封装。
- **设计 tokens 单文件**：V6 全部色值/字阶/动效预算 + 项目辨识色调色板（避开语义六色值）。

## 4. 内核反向塑形（本裁决新增，登记 PLAN.md）

| UX 需求 | 反向塑形 |
|---|---|
| 全景面板 = 多 repo 同屏 | daemon 多 repo：注册表驱动 N×Reconciler，事件按 project_id 隔离（A1_06） |
| 压缩卡要每 repo 一眼健康度 | 聚合投影按 project 分桶 + 全局 rollup，守恒测试覆盖两层（A1_06） |

## 5. P1-UI Atom 卡集（一次一颗，顺序可调）

| Atom | 交付 | 关键依赖 |
|---|---|---|
| A1_05 app 骨架 + design tokens | Xcode 工程（macOS 26 target/27 SDK lane）、tokens 单文件、UDS 订阅客户端、菜单栏+主窗骨架、CI app lane | NWConnection-UDS 实测 |
| A1_06 daemon 多 repo 注册表 | 注册表文件 + N×Reconciler + 按 project 分桶投影与 rollup 守恒 | 无（内核轨，可先行） |
| A1_07 Onboarding Connect+Select | 三级降档 auth + repo 列表/勾选 + RegisterProject 落注册表 | research/R1_auth memo（后台调研中） |
| A1_08 Global Workspace Radar | V6 universe SwiftUI 化：星云/轨道/节点卡/连线/语义缩放/拖拽，绑真实流；golden 快照进 shipgate | A1_05/06 |

每卡按 ATOM_TEMPLATE 立卡后才开工；shipgate p1 全绿 + 对抗双审照旧。
