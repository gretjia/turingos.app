# TRUST_STATES — ActorTrustState 统一枚举（唯一信任状态语言）

Worktree、Proposal、MarketTx、Ratification、Identity 各处共用本枚举；**禁止任何页面自造红黄绿**。机器枚举值锁定在 `contracts/event_stream.schema.json`（`trust_state`），改动须同步两处并过 shipgate。

| 枚举值 | 含义 | 色彩（VISUAL_SEMANTICS） |
|---|---|---|
| `observed_unsigned` | 看得见但无签名能力（observe-only） | gray |
| `manifest_missing` | 声称是 agent 但无 manifest → fail-closed 拒绝写权 | red |
| `manifest_registered` | manifest 已注册，尚无本次签名 | blue |
| `signature_valid` | 本次签名验证通过 | green |
| `signature_invalid` | 签名验证失败（含篡改） | red |
| `signer_unregistered` | 签名有效但签名人不在名册（冒名/未注册） | red |
| `signer_revoked` | 签名人已被吊销 | red |
| `capability_missing` | 身份有效但缺本动作所需 capability | yellow |
| `human_adopted` | 人类收养的无签名变更（human adoption signature） | green |
| `human_root_signed` | 人类根签名（L3/L4 域） | purple |
| `legacy_pre_rule` | 现行规则生效前的历史链（ADR-007：不改判） | gray |

## HumanRootWallet ≠ AgentWallet（职权分立）

| | HumanRootWallet | AgentWallet |
|---|---|---|
| 介质 | App 进程侧 Secure Enclave（P-256，生物识别解锁） | agent 自持（ssh-ed25519 / fido2，manifest 登记 key_kind） |
| 职权 | 宪法修订、Class-4/L4、trust-root、本地 sudo（L3） | proposal / work / verify / challenge / market tx（≤L2） |
| 禁区 | 永不进 daemon、永不出 SE | 永远无权触发 L3/L4 |

## key_kind 注册值

`se-p256`｜`ssh-ed25519`｜`ssh-fido2-ed25519`｜`gpg`。算法异构是现实（上游 ed25519 生态 vs SE 仅 P-256），显式建模而非藏进 UI。
