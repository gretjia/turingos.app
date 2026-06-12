# FEASIBILITY.md — Turing Agentic OS 可行性研究报告

2026-06-11 · 配套 [WHITEPAPER.md](WHITEPAPER.md) · 完整论断库（159 条，含全部来源与复核裁决）：[research/R_agentic_os_sources.md](research/R_agentic_os_sources.md)

**方法**：两条并行调研线（Apple 平台 6 角度 / Agent 生态 6 角度），每角度独立 web 检索 + 一手文档抓取；load-bearing 论断另由独立复核员以"试驳"方式二次检索（48 项复核：**44 confirmed / 3 refuted / 1 uncertain**；三条 refuted 与一条 uncertain 均已按复核结论修正入稿，明细见文末附录）。标注约定——**[verified]**：抓取到一手来源原文支持；**[partially-verified]**：多个二手来源一致或一手来源间接支持；**[unverified]**：未找到可靠来源，仅存疑记录。每条带来源与日期（发布日或 fetched 2026-06-11）。

---

## 0. 先回答三个直接问题

**Q1：「我能否是第一批用上 Apple Foundation Models 的？」**
不是第一批——这是**好消息**。框架自 macOS 26（2025 年秋）起已对第三方 GA，端侧免费、离线可用、基础使用零审批 [verified]。你接入的是一个已 GA 约 9 个月（自 2025-09-29）、WWDC 2026 刚升级第三代模型的成熟框架，而不是排队等 entitlement 的实验品。真正的"早"在别处：**把它用于 agent 治理层的本地动作摘要**，这个应用形态目前没有占位者（见 §II-6）。

**Q2：「Touch ID 物理认证能否有机结合进我的系统？」**
能，且正是为这种场景设计的 [verified]。Developer ID 菜单栏应用可正常弹 Touch ID；Secure Enclave 驻留密钥 + `.biometryCurrentSet` 可做到"每次批准 = 一次新鲜生物识别手势门控的签名"。诚实边界：SE 只能证明"谁签了字节"，不能证明"屏幕上显示了什么"——所以批准卡内容哈希必须由应用纳入签名负载（这是设计责任，不是 API 缺陷）。唯一待真机实证的细节：Developer ID 应用内嵌 provisioning profile 启用 SE 钥匙的首启体验（§III-1）。

**Q3：「Apple 的 container 跟我的系统冲突还是能结合？」**
能结合，不冲突，但要认清它的形态 [verified]：Apple Containerization 1.0（2026-06-09 发布）是**Linux 虚拟机容器**，可作为 Swift 库内嵌进第三方应用——适合做"高危 shell/构建工作的执行隔离档"。它不是 macOS 原生进程沙箱，也不能替代"影子工作区"（后者用用户态副本 + 版本化暂存实现，零 entitlement）。两者各居其位。

---

## Part I · Apple 平台（2026-06）

### I-1 Foundation Models 框架

| # | 论断 | 标注 | 来源 |
|---|---|---|---|
| 1 | 框架自 iOS 26/macOS 26 起对第三方开放端侧模型，2025 年秋 GA | [verified] | [Apple Newsroom](https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/) 2025-09-29 |
| 2 | 端侧推理免费、离线可用、全程在设备上 | [verified] | 同上 |
| 3 | 基础使用（SystemLanguageModel）**无需任何 entitlement/waitlist/审批**；仅部署自训 LoRA adapter 需要 `com.apple.developer.foundation-model-adapter` entitlement | [verified] | [Adapter 页](https://developer.apple.com/apple-intelligence/foundation-models-adapter/) fetched 2026-06-11 |
| 4 | 门槛是硬件+设置而非审批：需 Apple Intelligence 兼容设备且已启用；必须处理 `.unavailable` 原因（设备不支持/未启用） | [verified] | Newsroom 2025-09-29 + [SystemLanguageModel 文档](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel) |
| 5 | API 面契合本产品：LanguageModelSession、guided generation（`@Generable`/`@Guide` 类型化约束解码）、tool calling、流式输出 | [verified] | WWDC25 [286](https://developer.apple.com/videos/play/wwdc2025/286/)/[301](https://developer.apple.com/videos/play/wwdc2025/301/) |
| 6 | 上下文窗口 4,096 token（输入输出共享）；26.4 起有 `contextSize`/`tokenCount(for:)` API | [partially-verified] | [TN3193](https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window) + InfoQ 2026-03。注意：技术报告里的 65K 是训练序列长度，**不是**会话上限 |
| 7 | 2025 代端侧模型 ~3B 参数、~2-bit 量化感知训练；Apple 明言适合摘要/抽取/分类/短对话，**不是**通识聊天机器人——恰为本产品用法 | [verified] | [Apple ML Research](https://machinelearning.apple.com/research/apple-foundation-models-2025-updates) 2025-06-09 |
| 8 | WWDC26 发布第三代：AFM 3 Core（~3B）+ AFM 3 Core Advanced（~20B 稀疏，每请求激活 1-4B）、图像输入、`LanguageModel` 协议（可挂 Claude/Gemini 等第三方模型）、`fm` CLI、Python SDK | [verified] | [Apple ML Research](https://machinelearning.apple.com/research/introducing-third-generation-of-apple-foundation-models) 2026-06-08 + [WWDC26 指南](https://developer.apple.com/wwdc26/guides/apple-intelligence/) |
| 9 | WWDC26 的"免费 Private Cloud Compute"档**仅限** App Store 小企业计划成员（<200 万首装）+ PCC entitlement——Developer ID 分发的应用基本无缘 | [verified] | [PCC 页](https://developer.apple.com/private-cloud-compute/) fetched 2026-06-11 |
| 10 | Developer ID（非 App Store）应用可使用端侧框架（2025 代 API 无 App Store 分发要求）；2026 新增 API 是否同等开放**待真机实证** | [partially-verified] | Adapter 页推论；见 §III-2 |

**判定**：✅ 成立。本产品只用端侧（隐私操守也只允许端侧），免费、零审批、API 形态正对"动作摘要+类型化标注"。降级路径必须实现（模型不可用时回落确定性模板句）。

### I-2 隔离工作区

| # | 论断 | 标注 | 来源 |
|---|---|---|---|
| 1 | Apple `container`/Containerization：Apple silicon 上每容器一台轻量 VM，**只跑 Linux 容器**；需 macOS 26+ | [verified] | [github.com/apple/container](https://github.com/apple/container) fetched 2026-06-11 |
| 2 | 1.0.0 发布于 2026-06-09；Containerization 是公开 Swift 包，第三方应用可内嵌驱动 | [verified] | [releases](https://github.com/apple/container/releases) + [containerization](https://github.com/apple/containerization) |
| 3 | WWDC26 "container machine"：持久 Linux 环境，自动镜像宿主用户名并共享宿主工作目录 | [verified] | [WWDC26 session 389](https://developer.apple.com/videos/play/wwdc2026/389/) |
| 4 | App Sandbox 只能约束**自己**的进程，不能给别的 agent 上沙箱 | [partially-verified] | [Apple 文档](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html) |
| 5 | APFS 快照创建需受限 entitlement `com.apple.developer.vfs.snapshot`（Apple 几乎只发给备份厂商）；回滚依赖私有 entitlement——**第三方实际不可用** | [verified] | [Eclectic Light](https://eclecticlight.co/2026/05/10/last-week-on-my-mac-snapshots-the-elephant-in-apfs/) 2026-05-10 |
| 6 | `sandbox-exec` 仍可用但已弃用、无文档化替代 | [verified] | [containerization#737](https://github.com/apple/containerization/issues/737) 2026-05-12 |
| 7 | "副本+diff+批准+落地"唯一零 entitlement、全版本可用的路径 = 用户态影子工作区（副本目录/版本化暂存） | [partially-verified] | 综合以上排除法 |

**判定**：✅ 成立，但要诚实分层：v1 影子工作区 = 用户态副本+版本化；容器 = 可选执行隔离档（Linux 形态如实标注）；**不承诺**系统级快照还原。

### I-3 Touch ID + Secure Enclave 批准仪式

| # | 论断 | 标注 | 来源 |
|---|---|---|---|
| 1 | macOS 上应用激活 Touch ID 的唯一路径是 LAContext.evaluatePolicy；菜单栏 GUI agent 可以弹（launchd daemon 不行——LA 需用户 GUI 上下文） | [verified] | [LAPolicy 文档](https://developer.apple.com/documentation/localauthentication/lapolicy/deviceownerauthenticationwithbiometrics) + [Apple 论坛 #106386](https://developer.apple.com/forums/thread/106386) |
| 2 | SE 驻留 P-256 私钥 + `SecAccessControlCreateWithFlags([.privateKeyUsage, .biometryCurrentSet])`：每次签名要求新鲜生物识别，私钥不出 SE | [verified] | [SecAccessControl 文档](https://developer.apple.com/documentation/security/secaccesscontrolcreatewithflags(_:_:_:_:)) |
| 3 | `.biometryCurrentSet` 钥匙在生物识别重新录入时自动作废（特性：换指纹=重建信任） | [verified] | [Apple 平台安全](https://support.apple.com/guide/security/keychain-data-protection-secb0694df1a/web) |
| 4 | 重用时长 `touchIDAuthenticationAllowableReuseDuration` 默认 0（每次评估都要新手势）——逐动作批准取默认即可 | [partially-verified] | [文档](https://developer.apple.com/documentation/localauthentication/lacontext/touchidauthenticationallowablereuseduration) |
| 5 | **SE 签字节，不证屏显**：绑定"批准时所见"必须由应用把批准卡规范化哈希纳入签名负载——无任何 OS API 代劳 | [verified] | [SE 安全文档](https://support.apple.com/guide/security/the-secure-enclave-sec59b0b31ff/web) |
| 6 | macOS 上用 SE/数据保护钥匙串需注册 App ID + `com.apple.application-identifier` entitlement（经 provisioning profile 授权）；Developer ID 分发下可行但需内嵌 profile | [verified]/[partially-verified] | [Apple 论坛 #728150（Quinn）](https://developer.apple.com/forums/thread/728150)；首启体验待实证 §III-1 |
| 7 | WWDC26：App Attest 登陆 macOS 27，且 attestation 证书含 "ACL Blob OID"（编码 SE 访问控制条件）——未来可向审计方证明"这把钥匙确实是生物识别门控的" | [verified] | [WWDC26 session 201](https://developer.apple.com/videos/play/wwdc2026/201/) |

**判定**：✅ 成立。架构边界自然成立：批准仪式在 GUI 应用层，daemon 只做网关与记录。

### I-4 Developer ID 公证分发

| # | 论断 | 标注 | 来源 |
|---|---|---|---|
| 1 | Apple Developer Program $99/年；Developer ID 证书 + Hardened Runtime + `notarytool` + 装订 = 现行标准链路 | [verified] | [developer.apple.com/programs](https://developer.apple.com/programs/whats-included/) / [公证文档](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) |
| 2 | 自 macOS Sequoia 起未公证软件无右键绕行（Tahoe 延续）——正经公证实质上是必选项 | [verified]/[partially-verified] | [Apple News](https://developer.apple.com/news/?id=saqachfa) 2024-08-06 |
| 3 | 公证政策不禁止本地 daemon/本地服务器形态；Hardened Runtime 禁注入他进程——与本产品"不注入"原则天然相容 | [partially-verified] | 公证文档 fetched 2026-06-11 |
| 4 | SMAppService 注册后台项会触发系统"已添加后台项"通知并需用户批准（Ventura+）——与同意哲学同向 | [verified] | [Apple 部署指南](https://support.apple.com/guide/deployment/manage-login-items-background-tasks-mac-depdca572563/web) |
| 5 | LSUIElement 菜单栏应用无特殊公证约束；Sparkle 仍是 App Store 外自动更新标准 | [verified]/[partially-verified] | [LSUIElement 文档](https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement) / [Sparkle](https://sparkle-project.org/documentation/) |
| 6 | 未发现 WWDC26/macOS 27 对 Gatekeeper/公证的新收紧 | [unverified] | 截至 2026-06-11 无一手证据；持续跟踪 |

**判定**：✅ 成立，无政策性障碍。

### I-5 可见性接入途径

| # | 论断 | 标注 | 来源 |
|---|---|---|---|
| 1 | MCP 现行规范 2025-11-25 版；2026-07-28 大版本 RC 已出（2026-05-21） | [verified] | [spec](https://modelcontextprotocol.io/specification/2025-11-25) |
| 2 | MCP 已是多厂商标准：LF Projects 治理实体；OpenAI Agents SDK 一方支持 | [verified] | [MCP 路线图](https://blog.modelcontextprotocol.io/posts/2026-mcp-roadmap/) 2026-03-09 |
| 3 | **规范原文**：host"必须在调用任何工具前取得用户明确同意"，同时"MCP 自身无法在协议层强制执行"——执行缺口即本产品定位的法源 | [verified] | spec Security 章 |
| 4 | MCP 批准网关已有开源先例：mcp-guardian（Apache-2.0，逐调用批准）、Lasso mcp-gateway、IBM ContextForge（先例存在=verified）；"均为纯用户态进程、零 Apple 许可"为构造性推断 | [verified]/[partially-verified] | [mcp-guardian](https://github.com/eqtylab/mcp-guardian) 等 |
| 5 | CLI 包装路径有一方验证：Anthropic 开源 sandbox-runtime（Seatbelt profile + 域名白名单代理；自述域名级过滤、有 domain-fronting 绕过缓存） | [verified] | [sandbox-runtime](https://github.com/anthropic-experimental/sandbox-runtime) |
| 6 | Endpoint Security 框架需受限 entitlement（向 Apple 个案申请、标准未公开、惯例发给安全厂商）——对消费级应用不现实，且与操守相悖，**不取** | [verified]/[partially-verified] | [entitlement 文档](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.endpoint-security.client) |
| 7 | Network Extension 内容过滤：entitlement 自助 + 系统扩展用户批准——可行但网络层无动作语义，v1 不取 | [partially-verified] | [NE 文档](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.networking.networkextension) |
| 8 | WWDC26：App Intents 新增基于风险的上下文确认机制（高危动作自动触发确认）——Apple 在 OS 层验证同一哲学 | [verified] | [WWDC26 session 347](https://developer.apple.com/videos/play/wwdc2026/347/) |

**判定**：✅ MCP 网关 + CLI 包装为正道，零审批；OS 级途径如实列出并按操守放弃。

### I-6 Apple 自身动向（竞争面）

| # | 论断 | 标注 | 来源 |
|---|---|---|---|
| 1 | macOS 27 名 "Golden Gate"，2026-06-08 发布，仅 Apple silicon，公测 7 月、正式秋季 | [verified] | [apple.com/os/macos](https://www.apple.com/os/macos/) |
| 2 | 新 Siri 部分由 ~1.2T 参数定制 Gemini 模型驱动（跑在 Apple PCC 上，多年授权，报道 ~$10 亿/年）；三层推理栈（端侧/PCC/Gemini） | [partially-verified] | MacRumors/TNW 2026-06-08/09——金额与细节为媒体报道 |
| 3 | MCP 支持**确认面仅 Xcode**（Xcode 为 MCP host 连 Figma/GitHub；ACP 随 WWDC26 当天的 Xcode 26 更新先行出货、Xcode 27 扩展）；"系统级 Siri/App Intents MCP"**无一手确认** | [verified]+[unverified] | [Apple Newsroom](https://www.apple.com/newsroom/2026/06/apple-aids-app-development-with-new-intelligence-frameworks-and-advanced-tools/) + [SOTU](https://developer.apple.com/videos/play/wwdc2026/102/)；系统级部分仅 beta 拆解报道 |
| 4 | Apple 出货的是**逐动作内联确认**（Siri "Ready to send it?"）与按资源权限；**没有**跨 agent 批准台账、没有可导出审计历史的发布 | [partially-verified] | [WWDC26 AI 指南](https://developer.apple.com/wwdc26/guides/apple-intelligence/)（缺席性论断，持续跟踪） |

**判定**：⚠️ 竞争重叠有界：Apple 在做"自家动作面的逐项确认"，没有做"第三方 agent 的中立治理台账"。空位真实，但需每个 WWDC 重新核一次。

---

## Part II · Agent 生态（2026-06）

### II-1 OpenClaw 概况

- [verified] MIT 开源、自托管个人助理；Peter Steinberger 创建；更名链 Warelay(2025-11-24)→CLAWDIS→Clawdbot→Moltbot(2026-01-27)→OpenClaw(2026-01-30)，Moltbot 一步源于 Anthropic 商标投诉。来源：[Wikipedia](https://en.wikipedia.org/wiki/OpenClaw) + [CNBC](https://www.cnbc.com/2026/02/02/openclaw-open-source-ai-agent-rise-controversy-clawdbot-moltbot-moltbook.html) 2026-02-02
- [verified] 架构：本地优先 Gateway（"sessions/channels/tools/events 的单一控制面"）+ 内嵌编码 agent **Pi**（Mario Zechner，核心仅 Read/Write/Edit/Bash 四工具；OpenClaw 换 Bash 为可沙箱 exec 并叠加消息/浏览器/cron/MCP 工具）。来源：[GitHub](https://github.com/openclaw/openclaw) + [Armin Ronacher](https://lucumr.pocoo.org/2026/1/31/pi/) 2026-01-31
- [verified] 技能 = SKILL.md（YAML frontmatter）；注册表 ClawHub。[partially-verified] 采用度数字口径混乱（star 数 24.7 万~37.8 万不等、ClawHub 技能数 3千~5万不等）——**一切单一数字均按估计处理**
- [verified] 官方安全文档异常坦诚：单一受信操作者模型、非敌对多租户边界、默认 host 执行无批准弹窗（security="full", ask="off"）、"prompt injection 未解决"为原文。来源：[docs.openclaw.ai/gateway/security](https://docs.openclaw.ai/gateway/security)

### II-2 OpenClaw 安全记录（需求证据，厂商署名可溯源）

- [verified] **ClawHavoc**（Koi Security，2026-02-02）：ClawHub 上 341 个恶意技能，其中 335 个投递 Atomic Stealer（macOS）。[The Hacker News](https://thehackernews.com/2026/02/researchers-find-341-malicious-clawhub.html)
- [verified] **ToxicSkills**（Snyk，2026-02-05）：扫描 3,984 技能，36% 至少一缺陷、13.4% 危急、76 个人工确认恶意载荷。[Snyk](https://snyk.io/blog/toxicskills-malicious-ai-agent-skills-clawhub/)
- [verified] **1Password 分析**（Jason Meller，2026-02-02）："Markdown is an installer"；确认某高下载技能投放被标记为 macOS 窃密软件的二进制。[1Password](https://1password.com/blog/from-magic-to-malware-how-openclaws-agent-skills-become-an-attack-surface)
- [verified] **暴露面扫描**（SecurityScorecard STRIKE，2026-02-11）：24 小时发现 4 万+ 暴露实例，35.4% 存在 RCE 风险。[SecurityScorecard](https://securityscorecard.com/blog/how-exposed-openclaw-deployments-turn-agentic-ai-into-an-attack-surface/)
- [partially-verified] **重要修正**：现行官方文档默认 loopback+强制鉴权；"默认绑 0.0.0.0 裸奔"的流行说法与现行文档矛盾——暴露主因是操作者配置。我们不重复讹传
- [verified] **排名操纵**（Silverfort，2026-03-24）：ClawHub 下载计数接口无鉴权可刷，PoC 技能 6 天 3,900 次执行；<24h 修复。[Silverfort](https://www.silverfort.com/blog/clawhub-vulnerability-enables-attackers-to-manipulate-rankings-to-become-the-number-one-skill/)
- [verified] **Claw Chain**（Cyera，2026-05-15）：4 个 CVE 含两个沙箱逃逸（TOCTOU），已修复。[The Hacker News](https://thehackernews.com/2026/05/four-openclaw-flaws-enable-data-theft.html)；[partially-verified] CVE-2026-25253 "ClawBleed"（Control UI token 泄漏→RCE，已修复）
- [verified] OpenClaw 的响应：技能举报自动隐藏、ClawHub 全量 VirusTotal 扫描（自述"非银弹"）、`openclaw security audit`、可选 Docker 沙箱、同日修复 CVE
- [unverified] "2026 前五个月累计 ~138 CVE"——仅单一二手来源，不入正文引用

**诚实结论**：这些风险（提示注入、技能即供应链、凭证集中）**内禀于任何拿到 host 权限的 agent 生态**，不是 OpenClaw 独有的失败——这正是跨 agent 治理层的需求证据，而非攻击素材。

### II-3 Hermes Agent

- [verified] Nous Research 出品的**agent 框架**（与 Hermes 4 模型家族同名不同物）；MIT；2026-02 公开发布（repo created_at 2025-07-22，[partially-verified] 公开时间线）；GitHub API 2026-06-11 读数 ~190,674 stars。API `open_issues_count` ~19,932，但**该字段含 open PR**，网页端实际 open issues 约 5k+（复核裁决 uncertain——故不以此数字推断工程状态）。[GitHub API](https://api.github.com/repos/NousResearch/hermes-agent)
- [verified] 六执行后端（local/Docker/SSH/Singularity/Modal/Daytona）、~20 聊天网关、自我改进循环（自动建技能+跨会话记忆）、provider 无关路由、内置 cron。[docs](https://hermes-agent.nousresearch.com/docs/)
- [verified] 自带安全层：危险命令审批三模式（manual/smart/off + once/session/always 四选项）、硬黑名单（YOLO 也绕不过）、DM 配对、stdio MCP 环境变量白名单（~8 个基线变量）
- [verified] **关键缺口（其文档自认）**：审批只盖危险 shell 命令；docker/singularity/modal/daytona 后端下危险命令审批被**显式跳过**（"容器即边界"）；文件写/浏览器/发信不在审批面

### II-4 网关可行性：OpenClaw 与 Hermes

- [verified] OpenClaw 可作 MCP client（`mcp.servers`、`openclaw mcp add`，stdio/HTTP）；[partially-verified] 该能力 2026 春才落地（2026-02-27 的 issue 显示彼时无原生 MCP）
- [verified] OpenClaw 工具策略可关停内置组：`tools.profile` + `tools.allow`/`tools.deny`（通配符、deny 优先、group:runtime/fs/web/ui/messaging；**browser 属 group:ui**——本表已按复核修正）。[docs](https://docs.openclaw.ai/gateway/config-tools)
- [verified]/[partially-verified] **OpenClaw 最厚接入点**：插件 hook `before_tool_call`——文档化的进程内策略闸，文档示例与先例覆盖 exec/message/browser/MCP，可改写/拦截/要求批准（"覆盖所有工具类"的完整矩阵文档未枚举，待 §III-3 实测）；原生 exec 审批 `tools.exec.mode∈{deny,allowlist,ask,auto,full}`。[hooks](https://docs.openclaw.ai/plugins/hooks) / [exec-approvals](https://docs.openclaw.ai/tools/exec-approvals)
- [partially-verified] 先例：knostic/openclaw-shield 安全插件（hook 路径，88 stars 无 release）
- [verified] **OpenClaw 纯 MCP 网关边界**：exec/process、文件四工具、web_search/web_fetch、browser、message（频道发信）、技能自带代码——全部原生执行不经 MCP。[tools](https://docs.openclaw.ai/tools)
- [verified] Hermes：MCP 原生（config.yaml `mcp_servers`，stdio/HTTP+OAuth，per-server include/exclude）；内置 toolset 可关停
- [verified] **Hermes 纯 MCP 网关边界**：terminal/process、execute_code（Python 沙箱可编程调工具）、文件、browser、**computer_use（macOS 桌面控制）**、send_message、cron 派发、自建技能均原生执行不经 MCP；per-tool 审批与审批 hook 是 open feature request；尚不能作为 MCP server（[#342](https://github.com/NousResearch/hermes-agent/issues/342) 无响应）
- [partially-verified] 两者均周更级演进——集成契约暴露在 churn 下，边界卡须随版本重核

### II-5 网关可行性：Claude Code 与 Codex

- [verified] Claude Code hooks：PreToolUse 对内置工具逐调用前置裁决（allow/deny/ask/defer + `updatedInput` 改写；command/http/mcp_tool handler；exit 2 阻断）。[hooks 文档](https://code.claude.com/docs/en/hooks)（文档版本 v2.1.162，fetched 2026-06-11）
- [verified→**复核修正**] **MCP-deny 缺口**：PreToolUse 的 deny 对 MCP 工具调用**不强制执行**——[issue #33106](https://github.com/anthropics/claude-code/issues/33106) 关闭为 not-planned；allow 列表内 Edit 的 deny 失效亦有记录（#37210/#18312）。原研究员"可盖每个工具"的表述被复核驳回，按驳回结论入稿
- [verified] 云会话（claude.ai/code）跑在 Anthropic 托管 VM，用户级 hooks/设置不随行（仅 repo 内提交的 hooks 生效）；模型 API 流量非工具调用、hook 不可见
- [verified] hooks 默认不防篡改（设置文件监视自动生效、`disableAllHooks` 存在）；macOS managed settings（`allowManagedHooksOnly` 等）可加固——非 MDM 下网关是纯自愿层
- [verified] Codex CLI 0.139.0（2026-06-09）有一等 hooks（hooks.json/config.toml，PreToolUse/PermissionRequest 等事件）；**官方自述拦截不完整**（部分 shell 调用、unified_exec 不在拦截面）。[hooks](https://developers.openai.com/codex/hooks)
- [verified] Codex：approval_policy{untrusted/on-request/on-failure/never} + sandbox_mode{read-only/workspace-write/danger-full-access}（Seatbelt/bwrap 强制）+ Starlark 规则引擎 + MCP per-server enabled_tools/disabled_tools
- [verified] Codex web_search 不可被 hook 拦截但可配置 disabled/cached；[partially-verified] Codex Cloud 任务在本机网关之外（OpenAI 托管，per-environment 网络设置）

**网关可治理性分级（按接入面厚度，含边界）**：OpenClaw **A**（hook+策略+MCP+原生审批四层）> Hermes **A-**（MCP 原生+toolset 关停，但审批面窄）> Claude Code **B+**（hooks 强但 MCP-deny 缺口+云会话例外+默认可关）> Codex **B-**（hooks 新生且官方自述拦截不完整+Cloud 例外）。注：字母为本文档综合复核驳回后的重评（研究员原稿给 Claude Code A-，在 MCP-deny 缺口被复核证实前写就），非论断库原文。

### II-6 需求证据与竞品

- [verified] "lethal trifecta"（私有数据×不可信内容×对外通信）：Simon Willison 2025-06-16 提出。[原文](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/)
- [verified] 真实事件链：GitHub MCP 注入泄私库（Invariant Labs，2025-05）；[partially-verified] WhatsApp MCP 工具投毒外泄（2025-04）；[verified] 首个野生恶意 MCP server postmark-mcp 静默 BCC 全部邮件（2025-09）
- [verified] OWASP Agentic 应用 Top 10 发布（2025-12-09/10）
- [verified] MCP 规模：2025-12-09 Anthropic 将 MCP 捐入 Linux Foundation 旗下 Agentic AI Foundation（Block/OpenAI 联合创始），时称 >10,000 公开 server。[Anthropic](https://www.anthropic.com/news/donating-the-model-context-protocol-and-establishing-of-the-agentic-ai-foundation)
- [verified] 竞品（如实）：企业侧已拥挤——Preloop（MCP 防火墙+人审+审计）、agentgateway、Lasso、mcp-firewall、Pipelock；消费侧最近邻 **Agent Secret**（macOS 本地、Touch ID 门控，但范围仅凭证取用批准）。**跨 agent×消费级×动作级 Touch ID 仪式×本地可回放审计**的组合目前无占位者
- [verified] 网关的根本边界（AWS 安全博客同样指出）：有通用 shell 的 agent 可直接调 API/驱动无头浏览器"完全绕过 MCP"——诚实披露是行业共识中的正确姿态

---

## Part III · 待真机实证清单（写进承诺前必须 BIND）

1. **SE 钥匙 × Developer ID**：内嵌 provisioning profile 的 Developer ID 应用在陌生 Mac 首启时 SE 钥匙可用性（Quinn 确认 entitlement 必需，但无端到端一手 walkthrough）。
2. **Foundation Models 2026 代 API × Developer ID**：AFM 3 Core Advanced / 图像输入在非 App Store 分发下的可用性（2025 代 API 无此疑问）。
3. **OpenClaw `before_tool_call` 实测**：hook 在 exec/message/browser 上的真实拦截行为与版本稳定性（文档与现实的差距要真跑）。
4. **Claude Code MCP-deny 缺口边界**：deny 不强制执行的精确范围（哪些路径仍可 ask？）——决定边界卡措辞。
5. **macOS 27 beta 回归**：Gatekeeper/公证、App Sandbox 在 27 上无回归（§I-4#6 为 unverified）。
6. **Guided generation 严格性**：`@Generable` 约束解码是否框架级保证输出永不越出声明 schema（论断库开放问题；无论结果如何，网关侧对模型输出做确定性校验、标签仅用于呈现）。
7. **SMAppService/TCC 全链路走查**：后台项批准通知、各 TCC 提示的真实首启路径与文案（§I-4#3/#5 为 partially-verified）。
8. **Claude Code 云会话 repo-hooks 行为**：仓库内提交的 hooks 在 claude.ai/code 云端的实际生效面——决定云会话边界卡措辞（CC-6）。

## 附：复核统计

48 项 load-bearing 复核：**44 confirmed / 3 refuted / 1 uncertain**。三条 refuted 均已按复核证据修正入稿：

1. Claude Code "PreToolUse 可盖每个工具" → 复核发现 **MCP-deny 不强制执行**（已修正入 II-5 与白皮书 §7.3）；
2. OpenClaw browser 工具属 group:ui 而非 group:messaging（已修正入 II-4）；
3. "Apple MCP/ACP 确认面仅 Xcode 27" → 复核发现 **ACP 已随 WWDC26 当天的 Xcode 26 更新先行出货**，Xcode 27 为扩展（已修正入 I-6 #3）。

1 条 uncertain（Hermes 的 GitHub API `open_issues_count` 含 open PR，网页端实际 open issues 约 5k+）已按保守口径写入 II-3（含字段语义说明，不再以该数字推断工程状态）。完整论断库与逐条来源：[research/R_agentic_os_sources.md](research/R_agentic_os_sources.md)。

---

## Part IV · v0.5 协议层与生态层补充（A1_13 四路调研，2026-06-12）

> 完整论断库（41 条，33 verified / 6 partially-verified / 1 refuted / 1 unverified，逐条原文证据与 URL）：[research/R_v05_protocol_live_sources.md](research/R_v05_protocol_live_sources.md)。本节只列改变设计的要点。

### IV-1 协议层

- [verified] **MCP**：现行稳定规范仍为 2025-11-25；下一版 RC 已发布、定稿日 2026-07-28（写承诺前留意版本切换）。治理 = Linux Foundation 旗下 Agentic AI Foundation（Anthropic/Block/OpenAI 共同发起）。
- [verified] **MCP Apps**：2026-01-26 成为**首个 official MCP extension**（工具返回交互式 UI 组件入会话）；与 OpenAI **联合制定**——Apps SDK 明确要求 app 必须有 MCP server。两者是同一 UI 面，不是两套标准。
- [verified] **A2A**：Google 2025-04-09 发布 → 2025-06-23 捐 Linux Foundation → **2026-03 达 v1.0（首个生产级版本）**；"150+ 组织"为 LF 口径（Google 同日博客称 100+，计数口径不同，引用须带说明）[partially-verified]。
- [refuted] "A2A 与 MCP 正在合并"：两者互补（agent 间 vs agent-工具），无合并迹象。
- [verified] **A2UI**：Google 2025-12-15 公开，官方自述 early-stage，版本 v0.8——只做 adapter 不锁定。**AG-UI 属 CopilotKit**（非 Google），MIT，事件流式 agent↔前端协议，AWS Bedrock AgentCore 2026-03 已支持。

### IV-2 模型接入经济学

- [verified] ChatGPT Plus/Pro/Business **不含 API 用量**（两套独立计费体系）；Codex 含于全部 ChatGPT 计划（含 Free），滚动 5 小时窗限额，2026-04 起按 token 对齐计价。
- [partially-verified] **订阅 OAuth 接入第三方**：OpenClaw 2026-05-02 经 **Codex OAuth 端点**让 ChatGPT 订阅者直用 GPT-5.4（Altman 官宣）——是 de-facto 通道，**不是面向任意第三方的官方 SDK**；Apps SDK 货币化条款另有限制。设计上支持、措辞上不承诺。
- [partially-verified] **Anthropic 2026-06-15 分账**：交互式 Claude Code 留在订阅内；**Agent SDK / `claude -p` / 第三方 app 改走专属月度 credit 池**（Pro $20 / Max5x $100 / Max20x $200，不滚存）。TuringOS 若经 Agent SDK 用用户订阅，消耗的是该池。
- [verified] Gemini 官方 OpenAI 兼容端点（beta，特性不全）；[partially-verified] xAI：OpenAI SDK 一手确认，Anthropic SDK 仅 Cloudflare 网关二手。
- [partially-verified] API 标准实为**三个面**：OpenAI Chat Completions（普适事实标准）/ OpenAI Responses（agent 向新形态）/ Anthropic Messages（原生）。Gateway 按三面设计。

### IV-3 Skills 与 Live Software

- [verified] **SKILL.md 已是开放标准**（Anthropic 2025-12-18 发布；48 小时内 VS Code 与 Codex CLI 接入；2026-03 已 32 个工具支持，含 Gemini CLI/Cursor/Copilot/Goose）。Turing Skill 兼容 SKILL.md = 顺势而为。注意：各 surface 的自定义 Skills 不互通同步。
- [verified] **Apple adapter 训练官方就是 LoRA**（开发者文档原文 "PEFT approach known as LoRA"）——v0.4 评审中"不要随意等同 LoRA"的提醒经查反向不成立，用户原表述正确。部署需 Foundation Models Framework Adapter Entitlement（训练与本地测试不需要）。
- [verified] **adapter 逐基模型版本绑定**：每个 adapter 只兼容一个特定系统模型版本，OS 升级即须重训——这是持续运营税，路线图必须预算。
- [verified] 端侧模型约 3B，Apple 明言"非通用世界知识 chatbot"；WWDC26 自带模型 = **LanguageModel（声明能力）+ LanguageModelExecutor（执行推理）双协议**。
- [verified] 先例：Hermes 自我改进循环（经验→技能→使用中改进→持久化→FTS5 检索）；**MiMo Code**（小米，2026-06-10，OpenCode 二次开发，MIT，长程任务 + SQLite FTS5 记忆 + `/distill`、`/dream` 技能蒸馏）；研究线 SEAL（MIT，自编辑权重）/ AlphaEvolve（DeepMind，生产级进化搜索）/ SAGE（Amazon，技能库+GRPO）。

### IV-4 Freeform 与 Hostile Host

- [verified] **Freeform 自动化面 = 仅一个 Shortcuts 动作**（"Add Files to Board"，iOS 26 引入）；无创建看板动作、无 AppleScript 字典、无 URL scheme、无公开文件格式。"直接调用 Freeform 呈现"不可行，只能做导出/分享桥。
- [verified] 嵌入式画布：**Excalidraw MIT**（可自由商用嵌入）优于 tldraw（v4 生产部署需 license key，hobby 档带水印）。
- [verified] Hostile-host 先例：硬件钱包 WYSIWYS（签名与显示同一安全域）；银行 **chipTAN**（独立设备显示交易内容，PC 被木马也无法篡改已确认交易）；**Foundation Passport Prime**（2026-05-22，自称首个 "Human Authority Hardware"，明确以 AI agent 批准为场景——品类已被市场验证）。
- [verified] 反面边界：FIDO2/WebAuthn 交易确认扩展 **2025-04-02 关闭未合并**（现役硬件 key 无可信显示）；[partially-verified] Apple Watch `deviceOwnerAuthenticationWithWatch` 只能弹**通用批准 UI**，第三方无法在表上显示自定义动作详情，亦无第三方 SE 签名 API——Watch 是在场因子，不是 WYSIWYS 面。
- [verified] Audit Anchor 模式先例：Sigstore Rekor（Merkle 包含证明 + 追加式日志 + 独立监督者）。学术线（OAP，arXiv 2603.20953）明确自陈不防 compromised runtime——hostile-host 在文献中仍是 open problem。

### Part III 增补（v0.5 新增待实证项）

9. **Codex OAuth 端点第三方接入**：OpenClaw 路径的可复制性、条款边界与稳定性（决定 Model Gateway 订阅档措辞）。
10. **Anthropic Agent SDK credit 池实测**（2026-06-15 生效后）：订阅 OAuth 在第三方 app 内的真实计量与限额行为。
11. **Excalidraw 嵌入 WKWebView**：离线打包、性能、导出链路（Canvas Projection 的工程底座）。
12. **Apple Watch 批准链路实测**：`deviceOwnerAuthenticationWithWatch` 在菜单栏 app / daemon 架构下的真实弹出面与限制。
13. **OpenClaw/Hermes 社区粘性与切换成本评估**（评审第 8 条明确要求"社区调研而非主观感受"）：用户留存信号、贡献者速度、迁移成本、用户群体规模——本版未做，列为独立调研项；做完之前白皮书 §14.4 的"真实用户规模"门槛条件不下结论。
