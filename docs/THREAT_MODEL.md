# THREAT_MODEL — 威胁模型（P0 立法，逐场景升格为 E2E）

每个场景给出：攻击面 → 防线 → 验证方式。新增攻击面必须先登记再写代码。

## 12 个最低场景

| # | 场景 | 防线 | 验证 |
|---|---|---|---|
| T1 | 恶意本地进程连接 UDS | UDS 五件套（下文） | L2 E2E：非本用户/非白名单进程连接必拒 |
| T2 | symlink / 路径穿越进受保护文件 | 一切用户输入路径 canonicalize 后比对 registry；worktree 路径不得逃逸项目根 | P1 六边界之一；负向测试 |
| T3 | 伪造 agent identity / manifest 冒名 | fail-closed 验签（ADR-004）；trust_state 全程可见 | P2 金标四态 |
| T4 | 重放旧的签名回执 | receipt 含 seq/nonce + tape 位置锚定；重放即 seq 冲突 | L2 E2E |
| T5 | squash 掉 Class-4 signed tag 锚定的 merge | merge guard 校验 tag↔merge-commit 对应关系；孤儿化即告警 panic | P3 负向测试 |
| T6 | FSEvents 漏写导致投影偏离 | FSEvents 仅提示；周期全量对账兜底（ADR-010） | L1 混沌注入 |
| T7 | App 投影 DB 损坏/被篡改 | 投影可删可重建（三件套）；守恒测试；损坏即重建不修补 | L1 |
| T8 | daemon 失陷但 App wallet 安全 | 人类根私钥只在 App 侧 SE，daemon 只验签（ADR-005）；失陷 daemon 无法伪造 L3/L4 签名 | L2 |
| T9 | App 失陷但 daemon 验出坏 payload | daemon 独立校验 canonical payload hash 与 schema；不信任 GUI 传入的任何摘要 | L2 |
| T10 | prompt injection 诱导 agent 读隐藏评分/政策 | 评分函数与隐藏政策物理隔离于 agent 可读路径外（Art.III Goodhart 屏蔽） | L2 Goodhart 探针 |
| T11 | 巨文件/二进制炸弹 worktree | diff 分级（hash-only 阈值）；渲染预算；后台线程隔离 | L2 + P1 六边界 |
| T12 | 启动外部工具时 shell 环境投毒 | login shell 工具发现白名单化；不执行项目内 rc/钩子脚本来发现工具 | P5 门禁 |

## UDS 五件套（T1 细则）

1. socket 文件权限 `0600`，置于用户私有目录。
2. 每连接做 peer credential 校验（`LOCAL_PEERCRED`/`getpeereid`）。
3. daemon 以 per-user LaunchAgent（SMAppService）运行。
4. 默认无 root：daemon 不以特权运行，提权需求单独立案。
5. **Human Root 私钥永不进 daemon**：签名只发生在 App 进程侧 Secure Enclave，daemon 只做验签。

## 纪律

- 防线失效时 fail-closed：拒绝并留痕（tape node），绝不静默放行或静默修复（M2）。
- 历史 evidence 被篡改 → 审计 panic，人工介入，**不自动"修复"历史**（ADR-007）。
