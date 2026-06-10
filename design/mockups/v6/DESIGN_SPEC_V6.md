这是一个为您准备的完整设计规范描述文件，旨在提交给 Orchestrator Agent，以确保其在实现或重建该系统时，完全忠实于您的设计意图，避免任何形式的“设计漂移（Design Drift）”。  
# TuringOS Global Workspace Radar (V6) 系统设计规范描述  
**致 Orchestrator Agent：**  
本文件完整解释了随附 HTML/CSS/JS 源代码的设计逻辑、视觉语义、数据结构和交互行为。在落地此设计时，**严禁**随意更改语义颜色定义、缩放逻辑、DAG 连接算法以及多项目独立主轴的布局。必须确保实现结果与本描述在功能和美学上完全一致。  
## 1. 概述与核心哲学  
本系统名为 "TuringOS Global Workspace Radar (Version 6)"。它是一个基于 Web 的全景拓扑网络，旨在可视化分布在多个独立项目中的 Git Worktree（工作区）的实时状态。  
**核心哲学：**  
* **星系美学 (Galaxy Aesthetics)：** 界面应呈现出一个深邃的宇宙感，项目如同星系，节点如同星球，主干如同轨道。  
* **语义发光 (Semantic Luminous)：** 颜色不仅是视觉装饰，更是关键的信任和状态语义。所有颜色必须严格遵循定义好的“法律（The Law）”。  
* **语义缩放 (Semantic Zoom)：** 在宏观（缩小）视角，隐藏细节噪点，强调项目和拓扑流向；在微观（放大）视角，平滑展现 Agent 卡片、代码详情和证据抽屉。  
* **真实开发场景模拟：** 项目必须独立存在，项目之间没有任何 DAG 关联。项目内部必须呈现复杂的 Git 开发分支（DAG）结构（包括深度派生分支、孤儿分支和已合并分支）。  
## 2. 视觉规范与设计令牌 (Design Tokens)  
必須使用严格定义的 CSS 变量实现。  
**2.1 基础材质**  
* **Space 背景：** 极深的黑色 (#030305)，配合项目中心发出的放射状星云光晕 (--space-nebula)。  
* **Star Grid：** 一个细腻的、不可点击的星点网格背景图。  
* **Litho-Glass 材质：** 核心卡片、菜单栏和 HUD 使用深度玻璃态（Glassmorphism）。必须包含：backdrop-filter: blur(40px)、rgba 基础色（15, 15, 20, 0.5）、细致的边界 (--glass-border) 和内发光亮点。  
**2.2 字体排版**  
* **UI 文本：** 使用 'Inter' 字族，简洁、现代。  
* **代码/单声道文本：** 使用 'JetBrains Mono' 字族。用于 HEAD SHA、分支名、Agent 模型名、Diff 数据。  
**2.3 核心语义颜色 (The Law)**  
严格应用于信任徽章（Badges）、连接线（Paths）、aura（光环）和卡片发光线条。**不允许歧义或混合使用**。  
* **Green (**#34D399**):** 代表 Merged（已合并）、Verified（已验证）、Stable（稳定 Release）。  
* **Red (**#F87171**):** 代表 Failed（失败）、Invalid（无效）、Missing Manifest（清单丢失）。  
* **Yellow (**#FBBF24**):** 代表 Conflict（冲突）、Attention（需要注意）、Blocked（被阻断）。  
* **Blue (**#3B82F6**):** 代表 turingos 项目专用色；代表其活跃（Active）状态。  
* **Orange (**#F97316**):** 代表 omega 项目专用色；代表其实验性（Experimental）或沙盒（Sandbox）状态。  
* **Purple (**#A855F7**):** 代表 turingos_app 项目专用色；代表其与行权/宪法决议相关状态。  
* **Gray (**#9CA3AF**):** 代表 Truth（真相节点/观察态）、Inactive（未激活）、Merged 的总结文本。  
## 3. UI 布局结构  
DOM 结构必须符合以下逻辑分层，z-index 必须正确配置。  
**3.1 macOS Menubar (Top, Sticky, z-index 2000)**  
* MB-Left： 包含 、"TuringOS" 和 "Radar" 标题。  
* MB-Right： 包含雷达诊断图标和时间。  
* Glance Popover (L0 State, 2001)： 点击雷达图标时弹出的玻璃卡片。  
    * 显示全局 metrics（Active, Conflict, Merged 计数）。  
    * 显示高危冲突列表。  
    * 包含进入 L4 Ratification 的入口按钮。  
**3.2 Main App (Flex Layout, z-index 1000)**  
* **Sidebar (Left, Sticky)：** macOS 风玻璃侧边栏。  
    * 导航组：Workspace (Worktree Radar 处于 active 状态)；Security & Trust (Ratification Entrance)。  
* **Radar Wrapper (Right, Expands)：** 容纳全景画布和 HUD 的容器。  
**3.3 HUD Overlay (Bottom Right of Radar Wrapper)**  
* 包含 Zoom In、Zoom Out、Reset Center 玻璃按钮。  
* 包含系统的 Watermark 和当前工作模式（Dynamic Timeline）。  
## 4. 全景画布设计 Details (The Universe)  
**4.1 核心拓扑层级 (z-index 顺序)**  
1. **Nebula Layer (**#nebula-layer**)：** 为每个项目渲染巨大的放射状光晕背景。  
2. **Axis Layer (**#axis-layer**)：** 为每个项目渲染一条物理存在的主干轴线。  
    * 必须包含轨道视觉 (mainline-track) 和不断扫过的光流 (::after axisSweep 动画)。  
    * 微观模式下显示项目全名文本；宏观模式下加粗轨道。  
3. **Edge Layer (**#edge-layer**, SVG)：** 动态绘制 Bezier (C) 连接线。  
4. **Node Layer (**#node-layer**, HTML)：** 渲染可拖拽的 HTML 节点卡片。  
**4.2 独立项目独立 (Independence Rule)**  
模拟 Git 真实开发场景：**严禁项目之间有任何 Edge 连接**。每个项目都是一个封闭的拓扑结构。 本次设计包括四个项目：  
* **turingos (Kernel)**  
* **omega (AI Logic)**  
* **noosphere (Net)**  
* **turingos_app (UI)**  
## 5. 节点 (Nodes) 与 数据结构 Details  
**5.1 数据模型 (Data Model)**  
核心 graphData.nodes 对象必须包含：id, x, y, tag, title, branch, type, colorClass, glowClass, badge{txt, cls}。  
* 对于 active 节点，必须包含：agent{name, model, role, avatar}, live{task}，pulse:true, aura:color。  
* 必须包含可展开的真实数据详情（data:[{k, v, vc}]）和底层证据详情（ev:[{k, v, vc}]）。  
**5.2 节点类型与视觉映射 (z-index 2)**  
所有卡片必须应用极端的玻璃感。点击卡片必须触发 .expanded CSS 类（使用 CSS transition 平滑改变 max-height）。  
* **Truth Node (type='truth'):** ground truth 主轴锚点（如 wt_main）。卡片应比普通卡片更大、更重、应用粗边界、白色 Glow Line (rgba(255,255,255,0.5))，字体更大。  
* **Active Node (type='active'):** 正在活跃写入的 Agent 工作区。颜色使用特定项目专用色（Blue, Orange, Green, Purple）。  
    * 必须在卡片内展示 **Agent Chip**（头像、姓名、模型）。  
    * 必须在卡片内展示 **Live Stream** 任务（动态写入动画，颜色必须匹配项目专用色）。  
    * 卡片底部必须渲染一个圆形呼吸 Aura (光环) (aura pulse-aura)。  
* **Merged Node (type='merged'):** 已经完成 PR 并合并到 main 的历史节点。使用 Green 语义色。无 agent details、无 live stream、卡片材质呈现“冰冻态”（透明度更高，光线更暗）。  
* **Conflict Node (type='conflict'):** 高危/阻断节点。使用 Yellow 语义色。卡片发光线条应更亮（Glow line opacity 0.8）。  
    * 必须在卡片左侧渲染浮动的闪烁警告符号 (⚠️ warning-glyph float-warn)。  
* **Orphan Node (type='orphan'):** 死链、抛弃、不可信任的工作区。卡片呈现虚线边界 (border: 1px dashed)，整体透明度极低 (opacity 0.7)，不显示 HEAD 详情，观察模式下不显示分支详情。  
## 6. 连接线 (Edges) 与 DAG Details  
**6.1 连接线语义 (z-index 1)**  
使用 SVG Bezier C 曲线在 nOffset 之间动态绘制。  
* **Active Path:** 默认实线，颜色匹配源节点颜色。  
* **Dashed/Flow Path (dash property):** 必须包含 flow-anim (CSS dash Flow 动画)。  
    * 用于 Merging Back 的路径（从派生分支合并回 truth main 节点），虚线绿色线。  
    * 用于 cross-tag/cross-commit 依赖，虚线紫色线。  
* **Conflict Path:** 派生至冲突节点的路径，必须更粗 (width: 4)，并使用 Yellow 色。  
**6.2 复杂的 DAG 模拟**  
项目内部 DAG **不允许只是从 main 直接派生**，必须展示以下深度：  
* **Depth 2 (omege项目):** wt_main -> wt_agi_core (Active) -> wt_rlhf (Active)。必须显示两个 Active 节点之间的贝塞尔路径随 Agent 拖拽动态更新。  
* **Multi-branch Conflict (turingos项目):** wt_sched -> wt_sched_force (Conflict Tension)。必须模拟 agent 使用 --force 导致的覆写风险。  
* **Prunable/Legacy Orphan (noosphere项目):** 派生自 wt_main 但已经 off-chain 的孤儿节点，没有任何其他 DAG 连接。  
## 7. 交互行为 Details (The Logic)  
这是防漂移的最关键部分，Orchestrator 必须完整实现 JS 逻辑。  
**7.1 Canvas 控制**  
* **Pan:** 只有在 dragNode 为 null 时，允许 wrapper 上的 mousedown 触发 panning (state.x, state.y)。  
* **Zoom (Wheel):** 必须实现以鼠标位置为中心的数学缩放算法，而不是以画布中心。缩放极限限制在 0.1 (Galaxy Macro) 到 2.0 (Code Micro)。  
**7.2 核心逻辑：语义缩放 (Semantic Zoom, **< 0.6**)**  
Orchestrator 必须实现 JS 核心逻辑：当缩放比例低于 0.6 时，触发画布 .semantic-far 类。应用以下严格规则：  
* **Hide (max-height: 0, opacity: 0, scaleY: 0, border: none, transform 0.4s):**  
    * 节点内的 n-data 数据区。  
    * Agent Chip和Live Stream动画。  
    * 节点分支名和徽章（Badges）。  
    * 证据抽屉 (n-drawer) 强制不可见。  
    * 主干轨道全名文本。  
* **Show (opacity: 1, text-align: right):** 项目微观/中观视角下隐藏的大项目标签 (project-label)。  
* **Boost:**  
    * 所有的 edge-path (stroke-width: 8)。  
    * 主干轨道轨道 (mainline-track) 厚度变为两倍。  
**7.3 Node 拖拽 & Follows**  
* 节点 mousedown 阻止 panning，允许 dragging 卡片。  
* 节点 mousedown 计算鼠标与卡片中心的相对偏移 nOffset。  
* mousemove 平滑更新节点的 dragNode.data.x, dragNode.data.y。  
* **Critical:** JS updateEdges() 必须在节点拖拽的**每一帧**被触发，动态 recalculated 全部的贝塞尔路径参数 (C s.x + cpOff s.y, t.x - cpOff t.y, t.x t.y)，确保连线完美跟随卡片。  
**7.4 SecurityScreen flow (L4 Ratification Entrance)**  
* GlancePopover 或 Sidebar L4 按钮必须触发全屏 L4 Screen (.active class，应用 blur 和 opacity)。  
* 必须展示 L4 具体证据 Hash 框（SHA256 指纹）。  
* 必须模拟 "Touch ID" 验证签名，点击后改变按钮颜色（Green）和文本，并在延迟一秒后应用关闭 L4 屏幕并 Reset 按钮状态的 JS flow。  
**（结束。将此文件原样提交给 Orchestrator Agent。）**  
