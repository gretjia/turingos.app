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
