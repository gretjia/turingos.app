# CLI_ABI — `turingos` CLI-as-API 七条铁律（车道 A 契约）

CLI-as-API 最容易烂在：stdout 混入人类说明、stderr 被当业务错误、exit code 漂移、JSON 无版本、升级破坏 adapter、长任务无事件流。本契约逐条封堵。App 侧 adapter 只允许按本契约消费 CLI；上游若尚不满足某条，该命令在 adapter 中标记 `non-conformant` 并隔离适配，同时走车道 B 推动上游修复。

## 七条铁律

1. **App 调用的每个 CLI 命令必须支持 `--json`。** 不支持 `--json` 的命令不得进入 adapter 白名单。
2. **stdout 只能是 machine JSON / JSONL。** 一行人类散文都不行。
3. **stderr 只能是 diagnostics**，不可承载业务状态；App 侧只记录、不解析业务含义。
4. **每个 response 必须带 `schema_version`**（例：`tos.app.cli.v0`）。无版本字段 = 解析失败 = fail-closed。
5. **错误必须是 typed error code**（`{"error": {"code": "WORKTREE_LOCKED", ...}}`），exit code 仅作粗分类（0 成功 / 非 0 失败），语义以 typed code 为准。
6. **长任务必须支持 event JSONL 流或 receipt polling**，二者至少其一；禁止以"卡住 stdout 直到完成"的方式表达进度。
7. **每个进入白名单的命令必须有 fixture transcript**（`fixtures/cli_transcripts/<command>.jsonl`，P1 起）：真实调用的录制件，adapter 测试以 transcript 驱动，升级 rev 时 transcript diff 即兼容性报告。

## 响应示例（规范形态）

```json
{
  "schema_version": "tos.app.cli.v0",
  "kind": "WorktreeSnapshot",
  "project_id": "proj_x",
  "worktree_id": "wt_a",
  "head": "abc123",
  "dirty": true,
  "diff_hash": "sha256:...",
  "source": "git"
}
```
