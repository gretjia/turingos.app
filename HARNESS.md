# HARNESS — 防漂移马具（双层架构）

## 分层声明（ADR-006）

| 层 | 组成 | 约束对象 | 依赖 |
|---|---|---|---|
| **Canonical Harness（repo law）** | `scripts/shipgate.sh`、`scripts/validate_contracts.sh`、`contracts/*.schema.json`、`fixtures/**`、`scripts/predicates/*.grep` | 一切贡献者：人类、Claude、Codex、CI | bash + coreutils + python3 stdlib + git。**无 Claude 依赖（shipgate #7 自检）** |
| **Claude Developer Harness（contributor UX）** | `.claude/{settings.json,hooks,skills,agents}` | 仅 Claude Code 会话 | Claude Code |

PR 合入的唯一标准是 repo law 全绿。Claude 层即使全部删除，仓库法律不受影响。

## 原语诚实映射

Claude Code 没有原生 workflow/loop/goal 原语，本仓以现有原语合成，不假装拥有不存在的机制：

- **hook** → 5 个强制拦截点（下表）。
- **grep** → `scripts/predicates/*.grep` 负面模式谓词库。
- **workflow** → skills 工序链：`/atom-open` → 编码 → `/atom-ship`；合入走 PR。
- **goal** → Atom 卡 frontmatter 机器可读目标 + Stop hook 比对回执 + CI 跑 repo law。
- **loop** → 每次 merge 后重审计；R→D→S 每 Phase 重置。

## 五 Hook 协议（每个 ≤60 行，bash+python3）

| Hook | 事件 (matcher) | 行为 |
|---|---|---|
| `guard_constitution.sh` | PreToolUse (Edit\|Write\|MultiEdit\|NotebookEdit\|Bash) | 写 `constitution/constitution.md` → deny；Bash 命令含 constitution/ 且匹配写模式（重定向/tee/cp/mv/sed -i/rm/truncate/chmod/python open-w）→ deny。**封堵上游修订日志记载的 R-018 类旁路**（用脚本绕过编辑器改宪法） |
| `guard_spec_alignment.sh` | PreToolUse (Edit\|Write\|MultiEdit\|NotebookEdit) | 目标路径不在 CURRENT Atom 卡 allowlist → deny（提示走 Atom 卡修订留痕）；**R-stage 门禁**：把 CURRENT 指向 Phase N 的 Atom 而 `research/RN_memo.md` 不存在 → deny。CURRENT 缺失或为 `NONE` = bootstrap 模式（放行，宪法守卫仍生效） |
| `guard_minimalism.sh` | PostToolUse (Edit\|Write\|MultiEdit) | 对刚写入的文件跑极简负面模式（Manager/Factory/Singleton/AbstractBase 等抽象气味），违例以 additionalContext 即时回灌。**advisory 通道，不拦截** |
| `gate_stop.sh` | Stop | CURRENT ≠ NONE 且 `specs/atoms/receipts/<atom>.receipt` 缺失或非 PASS → block 收工并回灌缺口清单。尊重 `stop_hook_active` 防死循环 |
| `session_brief.sh` | SessionStart | 注入：第一原则 + 开工四问 + CURRENT Atom 卡全文（渐进披露：不灌全部文档） |

测试接缝：`guard_spec_alignment` 支持 `TOS_CURRENT_FILE` 环境变量覆盖、`gate_stop` 支持 `TOS_RECEIPT_DIR` 覆盖——shipgate #10 用它们做干跑断言，不污染真实仓库状态。

## Subagents 与 Skills（Claude 层）

- `veto-ai`：只读工具、清洁上下文；输出域严格 **{PASS, VETO}** 并援引宪法条款。S-stage 终审用。
- `minimalism-auditor`：advisory；产出 RiskFinding（severity ∈ {info,attention,risk}），与 Veto 严格分轨（M6）。
- `/atom-open <atom-id>`：校验 R memo 存在 → 设 CURRENT → 复述 intent/allowlist。
- `/atom-ship`：跑 repo law → 写回执 `specs/atoms/receipts/<atom>.receipt` → CURRENT 置 NONE。

## Harness 自身的极简纪律

shipgate 单文件无框架；hooks 每个 ≤60 行；谓词是数据（.grep 文件）不是代码。Harness 改动本身受 shipgate 约束（吃自己的狗粮）。
