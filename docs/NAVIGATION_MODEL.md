# NAVIGATION_MODEL — 导航模型（十大主导航 × 每页五问）

每个页面必须回答五问：**①用户来这里看什么？②可做哪些 typed actions？③哪些状态只是投影？④哪些动作需要签名（级别）？⑤哪些内容是 inferred/unknown？** 回答不全的页面不许进开发。

| 导航 | ①来看什么 | ②typed actions | ③投影 | ④签名 | ⑤inferred |
|---|---|---|---|---|---|
| **Global Ops** | 一眼健康度：活跃会话/待审提案/待签仪式/异常 | 无（纯 Glance） | 全部 | — | 离线 agent 的"最后已知态"标 gray |
| **Projects** | 已注册项目与其 worktree 拓扑 | RegisterProject(L1) | 列表/拓扑 | — | 外部新建未对账的 worktree 标 gray |
| **Missions** | 任务 DAG、分配、进度 | AssignMission(L2) | DAG 状态 | L2 | agent 自报进度标 inferred 直至有 receipt |
| **Worktrees** | Radar：每个 worktree 的 HEAD/dirty/占用者/信任态 | OpenWorktree(L1) | 全部（git 派生） | — | FSEvents 提示态标 blue，对账确认前不转 green |
| **Proposals** | 提案收件箱：证据链分层（裁决→签名→diff） | SubmitProposal(L2) / ApproveProposal(L2) / AdoptHumanChange(L2) | 列表与裁决摘要 | L2 | 未跑完谓词的提案禁止显示任何"预测结果" |
| **Identity** | actor 名册与 trust_state、密钥指纹、key_kind | RevokeSigner(L3) | 名册 | L3 | — |
| **Ratification** | 待签 L4 队列与仪式历史 | SignRatification(**L4 仪式屏**) | 历史 | **L4** | — |
| **Replay** | 时间轴重放任意 tape 区间 | ReplayRange(L0) | 全部（重建演示） | — | — |
| **Market Signals** | observe-only 看板；常驻横幅 "Price is a signal, not predicate truth" | 无 | 全部 | — | 全页本质为 inferred 信号 |
| **Settings** | daemon 状态、PINS 版本、通知偏好 | 本地偏好(L1)；触 PINS = L3 | 偏好 | L1/L3 | — |

## 导航纪律

- typed action 全集与级别以 `contracts/typed_actions.schema.json` + [RATIFICATION_POLICY](RATIFICATION_POLICY.md) 为准，页面不得发明未注册 action。
- 任何页面的徽章只许引用 [TRUST_STATES](TRUST_STATES.md) × [VISUAL_SEMANTICS](VISUAL_SEMANTICS.md)。
- Glance 路径（菜单栏 → Global Ops）必须零模态、零阻塞。
