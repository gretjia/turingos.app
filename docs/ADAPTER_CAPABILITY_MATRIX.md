# ADAPTER_CAPABILITY_MATRIX — agent 工具能力矩阵（P5 实现依据）

原则（ADR-010）：深集成用各工具原生事件面，**canonical 永远是 git + filesystem 周期对账**——矩阵最后一行对全员成立。各能力的版本与字段在 R5 复核并钉入 PINS。

| 能力 | Claude Code | Codex | Cursor / VS Code / human |
|---|---|---|---|
| 生命周期 hooks | **yes**（31 事件，2026-06-10 实证） | 部分（app-server 通知） | no |
| Worktree 创建/移除接管 | **yes**：WorktreeCreate（可替换默认 git 行为、须返回绝对路径、非零退出=失败）/ WorktreeRemove（不可阻断，仅清理归档） | yes（基于 git worktree、detached HEAD 工作） | no（外部创建，靠对账发现） |
| 结构化事件流 | hooks JSON（PreToolUse/PostToolUse/FileChanged/SubagentStart…） | **app-server 双向 JSON-RPC**：progress / tool use / approvals / diff 即 UI-ready events（首选路线，非 CLI 包装） | no |
| 审批回路 | PermissionRequest hook / Remote Control | app-server approvals | App 内人工 |
| 会话存在感 | statusline + transcript path | streamed events | inferred（gray） |
| 签名 WorkTx | adapter 注入 skill（`turingos-submit`） | adapter 包装 | **human adoption signature** |
| 兜底（canonical） | **FSEvents + `git worktree list` 周期对账** | 同左 | 同左 |

## Adapter 纪律

1. adapter 只翻译事件为 `contracts/event_stream.schema.json` 信封，**不裁决**；裁决在 daemon。
2. 每个 adapter 必须在原生事件面完全失效（hooks 被禁/版本变化）时退化为兜底行而不丢正确性——混沌注入是 P5 门禁。
3. 工具不可见 ≠ 不存在：外部创建的 worktree 经对账进入 Radar，trust_state=observed_unsigned，gray 呈现。
