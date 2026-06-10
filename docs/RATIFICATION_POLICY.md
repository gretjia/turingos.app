# RATIFICATION_POLICY — 五级动作分层（防签名疲劳立法）

如果所有大一点的操作都弹仪式，用户会机械点击，签名意义即被破坏。**仪式必须稀缺**：只有 L4 获得全注意力仪式屏；L4 清单白名单化，新增条目本身是 L4 动作。

| 级别 | 名称 | 交互形态 | 签名要求 | 示例 |
|---|---|---|---|---|
| **L0** | Observe | 无确认，只记录 | 无 | 打开页面、ReplayRange、查看提案 |
| **L1** | Local change | 普通确认，可撤销 | 无 | RegisterProject、OpenWorktree、本地偏好 |
| **L2** | Capability / Proposal | 标准审批卡片 | agent signature 或 human adoption signature | SubmitProposal、ApproveProposal、AssignMission、AdoptHumanChange |
| **L3** | Sensitive operation | Touch ID / 本地 sudo 确认 | SE 生物识别本地签名 | RevokeSigner、改 PINS、改门禁/谓词/豁免 |
| **L4** | Constitutional | **Full Ratification Ceremony**：全注意力仪式屏 + `human_readable_summary` + canonical payload hash + 后果声明 + signed tag | Human Root（SE P-256）+ §8 token + `v4-ratify-*` tag | 见白名单 |

## L4 白名单（新增/移除条目 = L4 动作）

1. 宪法文本修订（上游 constitution.md——本仓快照随之更新）。
2. trust-root 变更：Human Root 轮换、SignerSet 成员/阈值变更。
3. replay rule epoch 切换（ADR-007）。
4. 本 RATIFICATION_POLICY 的级别定义与 L4 白名单变更。
5. UPSTREAM_CONTRACT 三铁律变更。

## 配套纪律

- **无 canonical payload 的批准不叫 ratification**：L4 动作没有 payload hash + 签名 = 结构非法（contracts/ratification_payload.schema.json + shipgate #8）。
- L4 仪式屏的 `human_readable_summary` 是 schema required 字段——给人读的摘要是宪法义务，不是 UI 美化。
- 级别判定在 typed action 注册时静态声明（contracts/typed_actions.schema.json 的 `level` 字段），运行时不得动态降级。
