# VISUAL_SEMANTICS — 统一视觉语义（全产品唯一 badge 体系）

色彩是语义，不是装饰。下表是全产品唯一合法映射；任何视图自造配色 = 设计评审 FAIL。具体色值（含明暗模式、对比度达标值）由 P1 design tokens 单文件定义，本表锁定**语义**。

| 色 | 语义 | 典型场景 |
|---|---|---|
| **green** | verified / pass | 验签通过、谓词 PASS、对账一致、守恒测试绿 |
| **red** | failed / veto / invalid | 谓词 FAIL、Veto、签名无效、冒名拒绝、审计 panic |
| **yellow** | attention / advisory / risk finding | RiskFinding、lease 即将过期、beta lane 构件 |
| **gray** | unknown / inferred / foreign | 未对账 worktree、离线 agent 最后已知态、observe-only actor |
| **blue** | active / streaming / current | 进行中会话、FSEvents 提示态、当前重放位置 |
| **purple** | ratification / class-4 / human-root | L4 仪式、人类根签名、宪法级对象 |

## 硬性规则

1. **trust_state → 色彩映射唯一**（见 [TRUST_STATES.md](TRUST_STATES.md) 附表），由共享组件渲染，页面不得重实现。
2. **red 永不用于非失败语义**（如"热"、"重要"）；**purple 专属宪法域**，普通高亮禁用。
3. 色彩永不孤立承载语义：每个 badge 同时有图标 + 文本（可达性 0/1 谓词覆盖）。
4. inferred 内容（gray）必须显式标注来源与对账时间，禁止与 verified 内容视觉混排。

## 项目辨识色通道（2026-06-10 增补，V6 对账立法）

V6 星系美学引入**项目辨识色**（每个项目一种星云/轨道色）。为不破坏唯一语义色体系，立法如下：

5. 项目辨识色是**独立于语义六色的第二通道**，只许出现在**身份表面**：项目星云
   （nebula）、项目巨字标签（project label）、主干轨道点缀。**永不**出现在徽章、
   trust 状态 chrome、状态承载性连线上——那些表面只属于语义六色。
6. 项目辨识色调色板**不得复用语义六色的色值**（green/red/yellow/blue/purple 的
   #34D399/#F87171/#FBBF24/#3B82F6/#A855F7 及其近似值禁用），由 design tokens
   单文件统一定义（P1 A1_05 落地），避免"绿色星云被读成 verified"类歧义。
7. 节点卡的状态表达（glow line / aura / badge / edge）仍由 trust_state 与
   activity 状态驱动（active=blue、conflict=yellow、merged=green、orphan=gray），
   与所属项目无关——V6 原稿中"项目色兼作 active 色"的用法在实现中按本条调和。
