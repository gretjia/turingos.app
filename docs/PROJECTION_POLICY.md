# PROJECTION_POLICY — 三级 API 与字段分级（ADR-011 细则）

未来任何远端/移动表面只接触 Projection + typed action + canonical payload 签名。本政策从 P0 生效，使协议天然 projection-safe，移动端无需返工。

## 三级 API

| API | 性质 | 约束 |
|---|---|---|
| **Projection API** | 只读订阅 | 仅 `projection-safe` 字段（下表）；无私钥、无 raw transcript（默认）、无评分内幕；事件订阅式推送 |
| **Action API** | typed action 提交 | 只接受 `contracts/typed_actions.schema.json` 注册的 action；策略检查 + 级别校验（RATIFICATION_POLICY）；**禁止任意命令转发**——不存在"远程 shell"端点 |
| **Signing API** | canonical payload 签名 | 只接受 canonical payload（hash 锚定）；显式人类确认；签名发生在签名人本地 SE；预留 m-of-n SignerSet |

## 字段分级

| 级 | 含义 | 例 |
|---|---|---|
| `projection-safe` | 可投任意已认证表面 | trust_state、HEAD、dirty、diff_hash、谓词裁决、receipt 元数据、human_readable_summary |
| `host-only` | 仅主权宿主进程可见 | raw transcript 全文、worktree 文件内容、UDS 凭证 |
| `sealed` | 物理隔离 | 人类根私钥（SE 不出）、评分函数与隐藏政策（Art.III Goodhart 屏蔽） |

## 纪律

1. 字段默认 `host-only`；进入 projection-safe 须在 schema 注释中显式标注并过设计评审。
2. raw transcript 的远端查看是显式 L3 授权动作且带 redaction（P6 R-stage 细化）。
3. 投影端不得二次推导 sealed 信息（如从谓词时序反推评分逻辑）——L2 Goodhart 探针覆盖。
