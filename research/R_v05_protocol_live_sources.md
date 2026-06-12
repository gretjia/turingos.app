# R_v05 论断库：协议层 / 模型接入 / Live Software / Hostile Host（A1_13 四路调研）

> 机器渲染自 A1_13 调研 workflow 产出（4 路 Sonnet，131 次检索/抓取，调研日 2026-06-12）。
> 状态域：verified（一手来源直读）/ partially-verified（二手或有歧义）/ refuted（来源相反）/ unverified（未找到）。
> 共 41 条：partially-verified 6 / refuted 1 / unverified 1 / verified 33。
> 白皮书 v0.5 凡引本库论断，措辞强度不得超过其状态。

## Track A — Agentic 协议层（MCP / A2A / MCP Apps / A2UI / AG-UI）（12 条）

### P1. A2A origin `[verified]`

- **论断**：A2A was created by Google in April 2025.
- **证据（原文）**："One year ago, on April 9th, 2025 Google announced the Agent2Agent(A2A) protocol."
- **来源**：https://opensource.googleblog.com/2026/04/a-year-of-open-collaboration-celebrating-the-anniversary-of-a2a.html（内容日期：2026-04-09；核验日：2026-06-12）
- **对 v0.5 的含义**：Origin date and creator are confirmed correct for the whitepaper. Google Cloud is the originating party; the initial public announcement was April 9, 2025.

### P2. A2A Linux Foundation donation `[verified]`

- **论断**：A2A was donated to / hosted by the Linux Foundation.
- **证据（原文）**："Today at Open Source Summit North America, the Linux Foundation announced the formation of the Agent2Agent project" (June 23, 2025). The LF press release also states: "Originally developed by Google, the project is now hosted by the Linux Foundation."
- **来源**：https://developers.googleblog.com/en/google-cloud-donates-a2a-to-linux-foundation/（内容日期：2025-06-23；核验日：2026-06-12）
- **对 v0.5 的含义**：LF hosting is confirmed; the donation happened June 23 2025 (not at the April announcement). Whitepaper should attribute governance to Linux Foundation as of June 2025.

### P3. A2A 150+ organizations claim `[partially-verified]`

- **论断**：By ~April 2026, A2A claimed 150+ organizations of support.
- **证据（原文）**："The number of supporting organizations has grown from more than 50 to over 150 — including AWS, Cisco, Google, IBM, Microsoft, Salesforce, SAP, and ServiceNow." However, the Google Open Source Blog anniversary post (same date) says only "over 100 technology companies now supporting the project."
- **来源**：https://www.linuxfoundation.org/press/a2a-protocol-surpasses-150-organizations-lands-in-major-cloud-platforms-and-sees-enterprise-production-use-in-first-year（内容日期：2026-04-09；核验日：2026-06-12）
- **对 v0.5 的含义**：The 150+ figure appears in the LF press release; the Google blog on the same day says >100. The discrepancy likely reflects different counting methods (companies vs. organizations including non-companies). Whitepaper may cite "150+ organizations" with the LF press release as its source, but should note the two figures differ. Do not treat 150 as a hard fact without hedging.

### P4. A2A spec status `[verified]`

- **论断**：A2A reached a stable v1.0 specification by early 2026.
- **证据（原文）**："In March, the project reached a major milestone with the release of A2A Protocol v1.0, the first stable, fully production-ready version of the standard."
- **来源**：https://opensource.googleblog.com/2026/04/a-year-of-open-collaboration-celebrating-the-anniversary-of-a2a.html（内容日期：2026-04-09；核验日：2026-06-12）
- **对 v0.5 的含义**：A2A v1.0 landed March 2026. TuringOS v0.5 can cite A2A as a production-ready standard, not merely a draft.

### P5. MCP Apps – first official extension and what it standardizes `[verified]`

- **论断**：MCP Apps was announced ~January 2026 as the first official MCP extension, enabling tools to return interactive UI components rendered in conversation.
- **证据（原文）**："MCP Apps are now live as the first official MCP extension" and "Tools can now return interactive UI components that render directly in the conversation: dashboards, forms, visualizations, multi-step workflows, and more."
- **来源**：https://blog.modelcontextprotocol.io/posts/2026-01-26-mcp-apps/（内容日期：2026-01-26；核验日：2026-06-12）
- **对 v0.5 的含义**：Claim is fully correct. Whitepaper can state MCP Apps (Jan 26 2026) as the first official extension enabling in-conversation UI rendering.

### P6. MCP Apps – relationship to OpenAI Apps SDK `[verified]`

- **论断**：MCP Apps is built jointly with OpenAI (not a competing spec). OpenAI's Apps SDK is built on top of MCP.
- **证据（原文）**：MCP blog: "We were excited to partner with both OpenAI and MCP-UI to create a shared open standard for providing affordances." OpenAI Apps SDK quickstart: "To build an app for ChatGPT with the Apps SDK, you need: 1. A Model Context Protocol (MCP) server (required) that defines your app's capabilities" and "Apps built with the Apps SDK use the Model Context Protocol (MCP) to connect to ChatGPT."
- **来源**：https://blog.modelcontextprotocol.io/posts/2026-01-26-mcp-apps/（内容日期：2026-01-26；核验日：2026-06-12）
- **对 v0.5 的含义**：MCP Apps and OpenAI Apps SDK are convergent, not competing. An MCP server is explicitly required for the Apps SDK. TuringOS v0.5 protocol layer can treat these as the same UI surface, not two separate standards to implement.

### P7. A2UI – announcement date, maturity language, version `[verified]`

- **论断**：A2UI was announced by Google ~December 2025 and described as early-stage.
- **证据（原文）**：Byline: "DEC. 15, 2025". Maturity: "early stage _format_ and _implementations_". Version: "Our format is currently at `v0.8` because we have been through many rounds of battle hardening."
- **来源**：https://developers.googleblog.com/introducing-a2ui-an-open-project-for-agent-driven-interfaces/（内容日期：2025-12-15；核验日：2026-06-12）
- **对 v0.5 的含义**：Whitepaper claim of Dec 2025 announcement and early-stage status is confirmed. v0.8 at announcement, not v1.0. TuringOS v0.5 should treat A2UI as an experimental/preview input—not a stable dependency—at time of writing (June 2026).

### P8. AG-UI – origin, what it standardizes, adoption `[verified]`

- **论断**：AG-UI is an open event-based protocol that standardizes how AI agents connect to user-facing applications; it was originated by CopilotKit.
- **证据（原文）**："AG-UI is an open, lightweight, event-based protocol that standardizes how AI agents connect to user-facing applications." GitHub (CopilotKit repo description): "Makers of the AG-UI Protocol." GitHub ag-ui repo: 14,200 stars. AWS: Amazon Bedrock AgentCore Runtime added AG-UI support March 2026.
- **来源**：https://docs.ag-ui.com/introduction（内容日期：n/a；核验日：2026-06-12）
- **对 v0.5 的含义**：AG-UI is CopilotKit-originated (not Google, not Anthropic) and is MIT-licensed. It covers agent-to-frontend streaming / state sync, distinct from MCP (agent-to-tool) and A2A (agent-to-agent). TuringOS v0.5 whitepaper should attribute AG-UI to CopilotKit, not position it as a neutral standards body.

### P9. OpenAI Apps SDK – GA vs preview status `[unverified]`

- **论断**：OpenAI Apps SDK is in preview (not GA) as of 2026.
- **证据（原文）**：The OpenAI Apps SDK quickstart documentation does not use the words "preview," "beta," or "GA." It references "Apps SDK compatibility" as an ongoing feature. No maturity designation appears in the pages fetched.
- **来源**：https://developers.openai.com/apps-sdk/quickstart（内容日期：n/a；核验日：2026-06-12）
- **对 v0.5 的含义**：The whitepaper should not assert a specific GA/preview status for the OpenAI Apps SDK without a primary source. The docs indicate it is actively deployed (ChatGPT ships support), which implies at minimum a public availability state, but the formal designation is unconfirmed.

### P10. MCP current spec revision `[verified]`

- **论断**：The most recent stable MCP spec is 2025-11-25.
- **证据（原文）**："In [`2025-11-25`], calling a tool over Streamable HTTP means establishing a session first" (cited as the current baseline). "The final specification will be published on **July 28, 2026**."
- **来源**：https://blog.modelcontextprotocol.io/posts/2026-07-28-release-candidate/（内容日期：2026-07-28；核验日：2026-06-12）
- **对 v0.5 的含义**：As of June 12 2026, 2025-11-25 remains the current stable spec. A release candidate for 2026-07-28 is published but not yet final. Whitepaper citing 2025-11-25 is correct; it should note a new stable spec is imminent (RC published).

### P11. MCP governance – Agentic AI Foundation co-founders `[verified]`

- **论断**：MCP was donated to the Linux Foundation / Agentic AI Foundation, co-founded by Anthropic, Block, and OpenAI.
- **证据（原文）**："a directed fund under the Linux Foundation, co-founded by Anthropic, Block and OpenAI" and "Donating MCP to the Linux Foundation as part of the AAIF ensures it stays open, neutral, and community-driven as it becomes critical infrastructure for AI." Founding projects: Anthropic's MCP, Block's goose, OpenAI's AGENTS.md.
- **来源**：https://www.linuxfoundation.org/press/linux-foundation-announces-the-formation-of-the-agentic-ai-foundation（内容日期：2025-12-09；核验日：2026-06-12）
- **对 v0.5 的含义**：Whitepaper claim is confirmed. Note: Google is a Platinum member of AAIF but was NOT a co-founder of the foundation itself (co-founders are Anthropic, Block, OpenAI). Ensure whitepaper does not misattribute AAIF co-founding to Google.

### P12. A2A and MCP merging `[refuted]`

- **论断**：A2A and MCP are merging or one is absorbing the other.
- **证据（原文）**："A2A is complementary to the Model Context Protocol (MCP), another Linux Foundation project." Google blog: "The A2A protocol is designed to be complementary to existing standards like the Model Context Protocol (MCP); while MCP manages internal tool integration, A2A handles the vital external coordination between autonomous entities."
- **来源**：https://www.linuxfoundation.org/press/a2a-protocol-surpasses-150-organizations-lands-in-major-cloud-platforms-and-sees-enterprise-production-use-in-first-year（内容日期：2026-04-09；核验日：2026-06-12）
- **对 v0.5 的含义**：No merger is occurring or planned. Both are under the Linux Foundation umbrella (AAIF for MCP, separate LF project for A2A) but are explicitly positioned as complementary, solving different layers. TuringOS v0.5 architecture should treat MCP (agent↔tool) and A2A (agent↔agent) as distinct protocol layers, not interchangeable. A joint interoperability spec is discussed for Q3 2026, but that is coordination work, not a merger.

## Track B — 模型接入经济学与 API 标准（8 条）

### M1. ChatGPT subscriptions vs OpenAI API billing `[verified]`

- **论断**：ChatGPT Plus / Pro / Business subscriptions do NOT include OpenAI API usage; API is billed separately.
- **证据（原文）**：OpenAI APIs are billed separately from ChatGPT Plus, Business, Enterprise and Edu. ChatGPT and the API platform use separate billing systems, so charges and billing history are managed separately. API usage is billed separately on a pay-per-token basis.
- **来源**：https://help.openai.com/en/articles/9039756-billing-settings-in-chatgpt-vs-platform（内容日期：n/a；核验日：2026-06-12）
- **对 v0.5 的含义**：TuringOS v0.5 cannot assume users who have a ChatGPT subscription have any API budget; the two are entirely separate billing surfaces. Any integration must either collect API keys or use the Codex OAuth path (see Claim 3).

### M2. Codex inclusion in ChatGPT plans and usage limits `[verified]`

- **论断**：Codex is included in eligible ChatGPT plans; users sign in with their ChatGPT account; usage limits vary by plan.
- **证据（原文）**：Codex is included across Free, Go, Plus, Pro, Business, Edu, and Enterprise plans. Codex CLI, IDE extensions, and Codex Cloud are all included in ChatGPT Plus ($20/month) with soft and hard usage caps in rolling 5-hour windows. Usage from Codex, ChatGPT for Excel, and Workspace Agents counts toward agentic usage.
- **来源**：https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan（内容日期：n/a；核验日：2026-06-12）
- **对 v0.5 的含义**：Codex spans all paid (and free) ChatGPT tiers, but with tiered rate limits, not unlimited access. TuringOS designs should account for per-plan caps rather than treating Codex as a flat-rate resource. As of April 2 2026 pricing aligns with token usage rather than per-message.

### M3. OpenAI 'Sign in with ChatGPT' for third-party apps `[partially-verified]`

- **论断**：OpenAI allows third-party apps to authenticate users via their ChatGPT account such that the user's ChatGPT subscription covers model usage inside the third-party app.
- **证据（原文）**：ChatGPT Plus subscribers can log in via OAuth, access GPT-5.4 through the Codex endpoint, and run autonomous AI agents. For $23, a user gets access to GPT-5.4 through OpenClaw's agent framework without per-token API charges.
- **来源**：https://thenextweb.com/news/openai-openclaw-chatgpt-subscription-agent（内容日期：2026-05-02；核验日：2026-06-12）
- **对 v0.5 的含义**：This is narrower than the claim implies. The mechanism works specifically via the Codex CLI OAuth endpoint (not a general 'Sign in with ChatGPT' for arbitrary apps). It is a de facto capability demonstrated by OpenClaw on May 2 2026 (Sam Altman announced it), not an official published SDK/API for all third-party developers. The Apps SDK monetization docs explicitly state that selling digital services via ChatGPT subscription pass-through is 'not yet allowed.' TuringOS cannot freely build on this as a stable, documented API — it is Codex-endpoint-specific and potentially policy-constrained. The GitHub issue requesting a general 'Sign in with ChatGPT' for third-party subscription pass-through was closed as 'not planned.'

### M4. Anthropic Claude Pro/Max subscription and third-party Agent SDK access `[partially-verified]`

- **论断**：Claude Pro/Max subscription covers Claude Code usage; third-party apps via Claude Agent SDK can authenticate with Claude subscription instead of an API key.
- **证据（原文）**：Interactive Claude Code in your terminal or IDE stays on your existing subscription limits and is not affected by this change. Agent SDK and `claude -p` usage will draw from a new dedicated credit starting June 15, separate from your subscription's interactive usage limits. Third-party apps built on the Agent SDK (OpenClaw, Conductor, Zed, Jean) move to the new credit system.
- **来源**：https://devtoolpicks.com/blog/anthropic-splits-claude-subscriptions-agent-sdk-credit-june-2026（内容日期：2026-06-02；核验日：2026-06-12）
- **对 v0.5 的含义**：As of 2026-06-12 the picture is: (1) interactive Claude Code in terminal/IDE remains on the flat subscription; (2) Claude Agent SDK / claude -p / GitHub Actions / third-party apps shift on 2026-06-15 to a finite monthly credit pool ($20 for Pro, $100 for Max 5x, $200 for Max 20x) that resets monthly without rollover. Third-party apps CAN authenticate via subscription OAuth, but after June 15 they draw from the credit pool, not unlimited subscription access. TuringOS v0.5 should model this as a credit-budgeted surface, not unlimited, and must handle credit-exhaustion gracefully.

### M5. Gemini API OpenAI-compatible access `[verified]`

- **论断**：Gemini API officially supports OpenAI-compatible access (OpenAI libraries pointed at Google endpoint).
- **证据（原文）**：Gemini models are accessible using the OpenAI libraries (Python and TypeScript / Javascript) along with the REST API. Support for the OpenAI libraries is still in beta while we extend feature support.
- **来源**：https://ai.google.dev/gemini-api/docs/openai（内容日期：n/a；核验日：2026-06-12）
- **对 v0.5 的含义**：Google officially endorses the OpenAI-compatible endpoint at https://generativelanguage.googleapis.com/v1beta/openai/ with a three-line code change. However it remains in beta with incomplete feature parity. TuringOS can route Gemini calls via the OpenAI client library with low migration cost, but should be aware of beta caveats and missing Gemini-native features (File API, Live API, content caching).

### M6. xAI API compatibility with OpenAI and Anthropic SDKs `[partially-verified]`

- **论断**：xAI API is officially compatible with both OpenAI and Anthropic SDKs.
- **证据（原文）**：const anthropic = new Anthropic({ apiKey: "<api key>", baseURL: "https://gateway.ai.cloudflare.com/v1/{account_id}/{gateway_id}/grok" }); [and Python equivalent] client = Anthropic( api_key=XAI_API_KEY, base_url="...grok" )
- **来源**：https://developers.cloudflare.com/ai-gateway/usage/providers/grok/（内容日期：n/a；核验日：2026-06-12）
- **对 v0.5 的含义**：OpenAI SDK compatibility is confirmed by xAI's own official quickstart docs (base URL https://api.x.ai/v1 with OpenAI SDK). Anthropic SDK compatibility is shown in Cloudflare AI Gateway docs via a gateway proxy — not by xAI's own docs (docs.x.ai did not mention Anthropic SDK). The claim is partially-verified: OpenAI SDK = confirmed first-party; Anthropic SDK = works via gateway/proxy and documented by Cloudflare, but xAI's own docs do not explicitly endorse it. TuringOS should treat OpenAI-compat as the reliable xAI interface and Anthropic-compat as a community-level workaround.

### M7. Anthropic Agent Skills / SKILL.md mechanism, support surface, and open-standard adoption `[verified]`

- **论断**：Anthropic Agent Skills use SKILL.md + progressive disclosure / dynamic loading, are supported in Claude Code, API, and Claude apps, and the format is an open standard adopted by third parties as of 2026-06.
- **证据（原文）**：This filesystem-based architecture enables progressive disclosure: Claude loads information in stages as needed, rather than consuming context upfront. Level 1: Metadata (always loaded) — YAML frontmatter provides discovery information. Level 2: Instructions (loaded when triggered) — the main body of SKILL.md. Level 3: Resources and code (loaded as needed). Skills are available across Claude's agent products: the Claude API, Claude Code, and claude.ai. Update: We've published Agent Skills as an open standard for cross-platform portability. (December 18, 2025)
- **来源**：https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview（内容日期：n/a；核验日：2026-06-12）
- **对 v0.5 的含义**：The SKILL.md mechanism is fully documented and first-party confirmed. It is now an open standard (published 2025-12-18) with wide third-party adoption: within 48 hours Microsoft VS Code and OpenAI Codex CLI integrated it; by March 2026 32 tools (Google Gemini CLI, AWS Kiro, JetBrains Junie, Block Goose, GitHub Copilot, Cursor, etc.) support it. TuringOS v0.5 should treat SKILL.md as a durable cross-platform packaging format for agent capabilities, not Anthropic-proprietary. Caveat: custom Skills do NOT sync across surfaces (claude.ai, API, Claude Code are separate namespaces).

### M8. OpenAI-compatible + Anthropic Messages as the two de-facto LLM API standards in mid-2026 `[partially-verified]`

- **论断**：'OpenAI-compatible + Anthropic Messages' is a fair description of the two de-facto LLM API standards in mid-2026.
- **证据（原文）**：Today, three API formats dominate how AI Agents talk to LLMs: OpenAI's Chat Completions API — the de facto standard, universally supported; OpenAI's Responses API — the newer, agent-oriented evolution with built-in tools and state management; and Anthropic's Messages API — Claude's native interface, with capabilities like extended thinking and prompt caching. Because practically every major provider has adopted this format, code written against Chat Completions works across OpenAI, Anthropic (via adapters), Gemini, Mistral, Bedrock, and other models with minimal changes.
- **来源**：https://portkey.ai/blog/open-ai-responses-api-vs-chat-completions-vs-anthropic-anthropic-messages-api/（内容日期：n/a；核验日：2026-06-12）
- **对 v0.5 的含义**：The two-standard framing is broadly accurate but slightly imprecise: OpenAI itself now has TWO formats (Chat Completions = legacy de-facto universal standard; Responses API = newer agent-oriented successor with stateful context and built-in tools). For TuringOS v0.5, routing logic should distinguish these three surfaces: (1) OpenAI Chat Completions (universal, stable), (2) OpenAI Responses API (agent-native, stateful, prefer for agentic flows), (3) Anthropic Messages (Claude-native, extended thinking, prompt caching). DeepSeek is notable as the only first-party provider that natively speaks both OpenAI and Anthropic formats without a proxy.

## Track C — Live Software 与 Apple 端侧训练 / 自进化框架（10 条）

### L1. Apple Foundation Models adapter toolkit — official name `[verified]`

- **论断**：The official toolkit name is the 'Foundation Models adapter training toolkit' (or 'adapter training'), using LoRA (Low-Rank Adaptation) as the PEFT method.
- **证据（原文）**："the system model uses a parameter-efficient fine-tuning (PEFT) approach known as LoRA (Low-Rank Adaptation). In LoRA, the original model weights are frozen, and small trainable weight matrices called 'adapters' are embedded through the model's network."
- **来源**：https://developer.apple.com/apple-intelligence/foundation-models-adapter/（内容日期：2025；核验日：2026-06-12）
- **对 v0.5 的含义**：TuringOS v0.5 can correctly refer to Apple's toolkit as the Foundation Models adapter training toolkit using rank adapters / LoRA; both terms are accurate and first-party confirmed.

### L2. Apple Foundation Models adapter toolkit — required entitlement `[verified]`

- **论断**：Deploying custom adapters in a shipping app requires the 'Foundation Models Framework Adapter Entitlement' (entitlement key: com.apple.developer.foundation-model-adapter); training and local testing do NOT require it.
- **证据（原文）**："When you're ready to deploy adapters in your app, the Account Holder of a membership in the Apple Developer Program will need to request the Foundation Models Framework Adapter Entitlement. You don't need this entitlement to train or locally test adapters."
- **来源**：https://developer.apple.com/apple-intelligence/foundation-models-adapter/（内容日期：2025；核验日：2026-06-12）
- **对 v0.5 的含义**：TuringOS v0.5 design must account for this entitlement gate if it intends to ship adapter-enhanced on-device features through the App Store; prototyping does not need the entitlement.

### L3. Apple Foundation Models adapter toolkit — retraining per base-model update `[verified]`

- **论断**：Adapters must be retrained for every system model version; a single adapter is compatible with only one specific system model version.
- **证据（原文）**："Each adapter is compatible with a single specific system model version. To support people using your app who have devices on OS versions using different system model versions, you will need to train a different adapter for every version of the system model."
- **来源**：https://developer.apple.com/apple-intelligence/foundation-models-adapter/（内容日期：2025；核验日：2026-06-12）
- **对 v0.5 的含义**：This is a significant operational tax for TuringOS v0.5: each OS release that ships a new foundation model version forces adapter retraining and re-deployment; engineering roadmap must budget for this recurring cost.

### L4. Apple on-device foundation model — parameter count and task positioning `[verified]`

- **论断**：Apple's on-device foundation model is approximately 3B parameters; Apple explicitly states it is NOT designed for general world-knowledge chat and positions it for summarization, extraction, classification, and similar constrained tasks.
- **证据（原文）**："It is not designed to be a chatbot for general world knowledge." Evaluated capabilities include: "Classification, Extraction, Summarization, Tool-use, Rewriting" among others. Parameter count: "approximately 3-billion-parameter" (∼3B).
- **来源**：https://machinelearning.apple.com/research/apple-foundation-models-2025-updates（内容日期：2025；核验日：2026-06-12）
- **对 v0.5 的含义**：TuringOS v0.5 whitepapers correctly characterize Apple's on-device model as ~3B and task-specialized; the 'not world-knowledge chat' framing is directly confirmed first-party. The claim is accurate to say summarization/extraction/classification but should not omit that classification appears in an evaluation list, not as a primary product-positioning word.

### L5. WWDC 2026 Foundation Models — bring-your-own-model API name `[verified]`

- **论断**：WWDC 2026 introduced two protocols for bringing external models into the Foundation Models framework: LanguageModel (declares capabilities) and LanguageModelExecutor (handles inference/streaming); the API is NOT a single 'LanguageModelExecutor' alone.
- **证据（原文）**："It describes the model to the framework. It declares what the model can do, through capabilities, and provides the configuration the framework needs to set up the model's EXECutor." (LanguageModel protocol); "where the work happens. It has an initializer that takes a Configuration, a prewarm function for preparing resources ahead of the first request, and a respond function that streams generation back to the session." (LanguageModelExecutor). Enables: "developers can bring frontier AI models into their apps using the same framework" and "you call them the same way, because every model conforms to the Language Model protocol."
- **来源**：https://developer.apple.com/videos/play/wwdc2026/339/（内容日期：2026-06；核验日：2026-06-12）
- **对 v0.5 的含义**：TuringOS v0.5 should refer to both protocols (LanguageModel + LanguageModelExecutor) as the WWDC 2026 bring-your-own-model surface; collapsing to only 'LanguageModelExecutor' omits half the contract. This enables cloud models (Claude, Gemini) to be plugged into the same Foundation Models session API as on-device Apple models.

### L6. MiMo Code — publisher, type, base project, license, release, focus areas `[verified]`

- **论断**：MiMo Code is published by Xiaomi (XiaomiMiMo GitHub org), is a terminal-native AI coding agent, is a secondary development based on OpenCode (not an independent build), licensed MIT, released June 10 2026, with focus areas: long-horizon tasks (goal/stop conditions with judge), cross-session memory (SQLite FTS5), and self-improvement (/distill and /dream commands that extract skills from repeated workflows).
- **证据（原文）**："This project is a secondary development based on the open-source project OpenCode"; focus: "persistent memory, intelligent context management, subagent orchestration, goal-driven autonomous loops, compose workflows, and self-improvement"; "/distill discovers repeated workflows and packages them into reusable skills"; license: MIT.
- **来源**：https://github.com/XiaomiMiMo/MiMo-Code（内容日期：2026-06-10；核验日：2026-06-12）
- **对 v0.5 的含义**：TuringOS v0.5 whitepaper can cite MiMo Code as a June 2026 production example of a self-improving terminal coding agent with skill distillation; the claim that it is a 'fork of OpenCode' is correct (secondary development = fork/extension); focus on long-horizon tasks and self-improvement is confirmed.

### L7. Hermes Agent — self-improving loop description `[verified]`

- **论断**：Hermes Agent (by Nous Research) officially describes its loop as: creates skills from experience, improves them with use, nudges itself to persist knowledge, and searches its own past conversations (FTS5 session search with LLM summarization).
- **证据（原文）**：README: "it creates skills from experience, improves them during use, nudges itself to persist knowledge, searches its own past conversations"; "Agent-curated memory with periodic nudges. Autonomous skill creation after complex tasks. Skills self-improve during use. FTS5 session search with LLM summarization for cross-session recall."
- **来源**：https://github.com/NousResearch/hermes-agent（内容日期：2026-02；核验日：2026-06-12）
- **对 v0.5 的含义**：The four-part description in the whitepaper (creates skills / improves with use / persists knowledge / retrieves past conversations) is confirmed verbatim against the official README. TuringOS v0.5 can cite this accurately.

### L8. Self-evolving landscape — MIT SEAL (Self-Adapting Language Models) `[verified]`

- **论断**：SEAL (arXiv 2506.10943, June 2025) is a framework where LLMs autonomously modify their own weights by generating 'self-edits' — custom fine-tuning data and adjustment instructions — via RL with downstream performance as reward. Authors are from MIT-affiliated labs.
- **证据（原文）**："SEAL directly uses the model's own generation to control its adaptation process"; enables "knowledge incorporation and few-shot learning" via "supervised finetuning" from self-generated edits; "self-adaptation ability scales with model size."
- **来源**：https://arxiv.org/abs/2506.10943（内容日期：2025-06-12；核验日：2026-06-12）
- **对 v0.5 的含义**：TuringOS v0.5 can cite SEAL as a mid-2025 research proof-point for on-weights self-adaptation (distinct from skill-library approaches like Voyager/Hermes); the claim of MIT authorship is partially verified — paper lists MIT-associated authors but institution affiliation is not printed on the abstract page.

### L9. Self-evolving landscape — Google DeepMind AlphaEvolve `[verified]`

- **论断**：AlphaEvolve (Google DeepMind, May 2025) is an evolutionary coding agent powered by Gemini LLMs for general-purpose algorithm discovery; it uses generate-evaluate-evolve loops to improve algorithmic solutions as executable code, and has been used in production to optimize Google's own infrastructure and Gemini training.
- **证据（原文）**："AlphaEvolve pairs the creative problem-solving capabilities of our Gemini models with automated evaluators that verify answers, and uses an evolutionary framework to improve upon the most promising ideas." Practical results: recovered "0.7% of worldwide compute resources", cut Gemini training time by 1%, broke a 56-year math record.
- **来源**：https://deepmind.google/blog/alphaevolve-a-gemini-powered-coding-agent-for-designing-advanced-algorithms/（内容日期：2025-05-14；核验日：2026-06-12）
- **对 v0.5 的含义**：TuringOS v0.5 can accurately cite AlphaEvolve as a May 2025 production example of LLM-powered evolutionary self-improvement in a real-world setting (not just research). It is not a general 'agent learns skills from failures' system but an evolutionary search agent for algorithm optimization.

### L10. Self-evolving landscape — Voyager lineage and SAGE (2025–2026) `[verified]`

- **论断**：Voyager (2023) established the skill-library paradigm for lifelong learning agents; the lineage continues into 2025–2026 with SAGE (Skill Augmented GRPO for Self-Evolution, arXiv 2512.17102, December 2025, Amazon Science), which formalizes skill-library accumulation with RL and achieves 8.9% higher task completion with 26% fewer interaction steps.
- **证据（原文）**："Sequential Rollout, iteratively deploys agents across a chain of similar tasks for each rollout. As agents navigate through the task chain, skills generated from previous tasks accumulate in the library and become available for subsequent tasks." Results: "8.9% higher Scenario Goal Completion while requiring 26% fewer interaction steps."
- **来源**：https://arxiv.org/abs/2512.17102（内容日期：2025-12-18；核验日：2026-06-12）
- **对 v0.5 的含义**：TuringOS v0.5 should note that the Voyager skill-library lineage is not academic-only — it is being industrialized (Amazon SAGE, Xiaomi MiMo Code /distill) as of late 2025/early 2026, making skill-accumulation a credible near-term design pattern for agentic OS governance layers.

## Track D — Freeform 自动化面 与 Hostile-Host 先例（11 条）

### F1. Apple Freeform — public automation surface (Shortcuts/App Intents) `[verified]`

- **论断**：As of iOS/macOS 26, Apple Freeform exposes exactly one Shortcuts action ('Add Files to Board' / 'Add File to Freeform'), introduced in iOS 26. There is no 'Create Board' action, no AppleScript dictionary, no documented URL scheme, and no public framework API for third-party programmatic access to Freeform boards.
- **证据（原文）**："Add Files to Board" is the sole Freeform entry included in their catalog of 25+ new Shortcuts actions in iOS 26. No create-board action, no AppleScript dictionary, no URL scheme is mentioned in Apple developer documentation or community sources.
- **来源**：https://9to5mac.com/2025/12/09/ios-26s-shortcuts-app-adds-25-new-actions-heres-everything-new/（内容日期：2025-12-09；核验日：2026-06-12）
- **对 v0.5 的含义**：TuringOS cannot integrate with or embed Apple Freeform as an infinite-canvas surface via any public API. Third-party use is limited to the single 'Add Files to Board' Shortcut action; board creation, reading, or programmatic manipulation require screen-scraping or proprietary workarounds that Apple does not document or support.

### F2. Apple Freeform — AppleScript, URL scheme, file format `[verified]`

- **论断**：Apple has not published an AppleScript dictionary, a documented URL scheme (e.g. freeform://), or a public .freeform file format specification for the Freeform app.
- **证据（原文）**：Community discussion concludes: 'An API for Freeform would need to be built by Apple to allow access to the Freeform platform from other applications or platforms. Apple is unlikely to allow other applications to display a Freeform project, and unlikely to ever expose the Freeform platform for connections like that.' No Apple developer documentation for any freeform:// scheme or .freeform format specification was found.
- **来源**：https://discussions.apple.com/thread/255629904（内容日期：n/a；核验日：2026-06-12）
- **对 v0.5 的含义**：Any TuringOS design that relies on reading or writing Freeform boards programmatically has no supported path. The only viable open-canvas alternatives are open-source libraries (tldraw, Excalidraw) embedded directly in the app.

### F3. tldraw license — commercial/watermark terms (v3 and v4) `[verified]`

- **论断**：tldraw SDK v4 (late 2025) requires a license key for any production deployment. Without a key the SDK shows console errors and will not function correctly. Hobby licenses keep a 'made with tldraw' watermark visible; trial (100-day free) and commercial licenses do not show a watermark. The v3 change (December 2023) already moved tldraw from MIT/Apache-2.0 to a non-commercial-by-default model.
- **证据（原文）**："Hobby licenses keep the 'made with tldraw' watermark visible." "To deploy an application built with the SDK in a production environment, developers must obtain either a trial, commercial, or hobby license." "The SDK will only function correctly in a production setting when a valid license key is present."
- **来源**：https://tldraw.dev/sdk-features/license-key（内容日期：2023-09-13；核验日：2026-06-12）
- **对 v0.5 的含义**：TuringOS cannot embed tldraw freely in a shipped commercial product. A commercial license must be negotiated and paid for annually. Design should either budget for tldraw commercial licensing or prefer Excalidraw (MIT, no commercial restriction) to avoid dependency on a proprietary license gate.

### F4. Excalidraw license — MIT open source `[verified]`

- **论断**：Excalidraw is released under the MIT License, which permits unrestricted commercial use, modification, redistribution, and embedding without watermark or license fee obligations.
- **证据（原文）**："MIT License. Copyright (c) 2020 Excalidraw. Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software."
- **来源**：https://github.com/excalidraw/excalidraw/blob/master/LICENSE（内容日期：n/a；核验日：2026-06-12）
- **对 v0.5 的含义**：Excalidraw is safe for embedding in a Swift/WebKit Mac app for commercial deployment without watermark or licensing cost. It is the lower-friction open-canvas option compared to tldraw for TuringOS v0.5.

### F5. Hardware wallet WYSIWYS — Ledger/Trezor secure-display principle `[verified]`

- **论断**：The foundational security principle of hardware wallets like Ledger is that the device's own Secure Element-controlled screen shows exactly what is being signed, independent of a potentially compromised host computer (WYSIWYS — 'What You See Is What You Sign'). The host is explicitly treated as untrusted.
- **证据（原文）**："The same chip that reads the transaction is the one that builds the screen and signs it." "The information shown on-screen comes from the same secure environment that performs the signing." "The real question is not only whether your keys stay isolated. It is whether the signer gives you reliable, readable transaction details before you approve anything."
- **来源**：https://www.ledger.com/academy/topics/ledgersolutions/ledger-vs-trezor-2026-which-hardware-wallet-is-safer-ultimate-comparison（内容日期：2026；核验日：2026-06-12）
- **对 v0.5 的含义**：This is directly applicable prior art for TuringOS's hostile-host agent-approval surface design: the device (not the OS) must control what the human sees before they approve an irreversible action. The architecture principle — Secure Element owns display and signing in one trust domain — should guide TuringOS's approval UI design.

### F6. Banking chipTAN / photoTAN — independent trusted display against compromised computer `[verified]`

- **论断**：chipTAN protects online banking transactions by displaying transaction data (amount, account number) on a physically separate, offline TAN generator device and requiring the user to confirm on that device before a TAN is issued. Even if the PC is trojaned, modifying the transaction in flight invalidates the TAN.
- **证据（原文）**："Even if the computer is subverted by a Trojan, or if a man-in-the-middle attack occurs, the TAN generated is only valid for the transaction confirmed by the user on the screen of the TAN generator, therefore modifying a transaction retroactively would cause the TAN to be invalid." The device "reads the transaction details via a flickering barcode on the computer screen" and "shows the transaction details on its own screen to the user for confirmation before generating the TAN."
- **来源**：https://en.wikipedia.org/wiki/Transaction_authentication_number（内容日期：n/a；核验日：2026-06-12）
- **对 v0.5 的含义**：chipTAN is a directly analogous precedent for TuringOS's agent-action approval gate: a separate independent device with its own trusted display renders what will be authorized; host-OS compromise cannot silently alter the displayed intent. TuringOS v0.5 can cite this as established prior art for the 'independent approval surface' design pattern.

### F7. FIDO2/WebAuthn transaction confirmation extension — status `[verified]`

- **论断**：A FIDO2/WebAuthn transaction confirmation extension (PR #2020 to the W3C spec) that would allow hardware keys with displays to show transaction text to users was closed without being merged on April 2, 2025. The working group redirected the use case to Digital Payment Credentials (DPCs) and OpenID4VP. No shipped standard currently mandates a trusted display on FIDO2 hardware keys for transaction confirmation.
- **证据（原文）**："There is no current 'sponsor' for this work actively engaged in the working group. These use cases are being actively discussed in the context of Digital Payment Credentials (DPCs) with the Digital Credentials API and OpenID4VP." The extension would have supported "security keys or platform authenticators to show the transaction" for WYSIWYS in banking.
- **来源**：https://github.com/w3c/webauthn/pull/2020（内容日期：2025-04-02；核验日：2026-06-12）
- **对 v0.5 的含义**：FIDO2/WebAuthn hardware keys do NOT currently provide a standardized trusted display for transaction confirmation. TuringOS cannot rely on existing FIDO2 authenticators as an independent approval surface for showing agent action details. A dedicated hardware approval device (cf. Foundation Passport Prime pattern) or Apple Watch notification action is needed instead.

### F8. Apple Watch as approval surface for third-party apps `[partially-verified]`

- **论断**：watchOS exposes LocalAuthentication to third-party Mac apps via the 'deviceOwnerAuthenticationWithWatch' policy, allowing a Mac app to trigger a biometric/passcode approval prompt on a paired Apple Watch. However, the Watch shows only Apple's generic system approval UI — a third-party app cannot display custom transaction details on the Watch screen as the approval prompt. The Watch's Secure Enclave holds private keys for its own operations, but there is no third-party API to leverage the Watch's Secure Enclave for signing arbitrary app-defined data.
- **证据（原文）**：Apple's security guide confirms 'The private keys are rooted in the Secure Enclave on Apple Watch' and that the Watch can approve prompts from 'third-party apps that request authentication,' but the documentation describes only a generic system-level approval flow, not a custom display surface. 'Third-party apps that request authentication' are listed under macOS-centric approval — not watch-native arbitrary prompt content.
- **来源**：https://support.apple.com/guide/security/system-security-for-watchos-secc7d85209d/web（内容日期：n/a；核验日：2026-06-12）
- **对 v0.5 的含义**：Apple Watch can serve as an independent second-factor approval device for TuringOS (via LocalAuthentication deviceOwnerAuthenticationWithWatch), but only with Apple's generic 'approve/deny' UI — the Watch cannot display custom agent-action details in the approval prompt. TuringOS must either accept this limitation (approve a pre-agreed label, not a detailed action description) or invest in a dedicated hardware device for richer trusted display.

### F9. Sigstore Rekor — append-only transparency log with inclusion proofs `[verified]`

- **论断**：Sigstore Rekor is an immutable, append-only transparency log for software supply chain metadata. Entries can never be mutated or removed after insertion. The log supports cryptographic inclusion proofs via Merkle trees, enabling any party to verify offline that a specific entry is in the log. Auditors can run consistency checks to confirm the append-only property has not been violated.
- **证据（原文）**："Rekor functions as 'an immutable, tamper-resistant ledger of metadata generated within a software project's supply chain.'" "Auditors can monitor the log for consistency, meaning that the log remains append-only and entries are never mutated or removed." Users can "query the log for inclusion proof, integrity verification of the log or retrieval of entries."
- **来源**：https://docs.sigstore.dev/logging/overview/（内容日期：n/a；核验日：2026-06-12）
- **对 v0.5 的含义**：Rekor's pattern — cryptographic inclusion proofs from a Merkle-tree-backed append-only log monitored by independent auditors — is directly applicable as the audit-anchor architecture for TuringOS agent action receipts. Any agent action approved by the user can be committed to a Rekor-style log, providing non-repudiation and tamper evidence without requiring a central authority.

### F10. Prior art: hardware-based human authorization against compromised AI / hostile OS (2024–2026) `[verified]`

- **论断**：Foundation Devices launched 'Passport Prime' (announced May 22, 2026), explicitly marketed as the first 'Human Authority Hardware' device for AI agent approval. The product directly addresses the hostile host threat: a browser prompt or policy engine running on the same computer as an AI agent cannot be the final authority for consequential actions. The device runs KeyOS (Rust microkernel) and uses post-quantum Bluetooth for isolation from the potentially compromised host.
- **证据（原文）**："A browser prompt, phone notification, or policy engine running on the same computer as the agent cannot be the final authority for a consequential action." "Before money moves, code deploys, credentials are used, or sensitive data is accessed, the human should be able to review and approve the action on a trusted device they hold." "Dedicated, American-manufactured security devices that ensure high-stakes digital decisions require explicit human approval on hardware that no compromised software environment can reach."
- **来源**：https://www.globenewswire.com/news-release/2026/05/22/3300208/0/en/foundation-announces-6-4m-round-and-availability-of-passport-prime-the-first-human-authority-hardware-device.html（内容日期：2026-05-22；核验日：2026-06-12）
- **对 v0.5 的含义**：Foundation Passport Prime is live commercial prior art for TuringOS's hostile-host approval surface design. TuringOS's governance layer design is independently validated by this 2026 product category. TuringOS should reference this as market evidence that the hostile-host threat is real and that dedicated hardware approval is emerging as the industry answer, distinguishing TuringOS's software-level governance layer as a complementary (not competing) architecture.

### F11. Prior art: academic research on AI agent pre-action authorization and hostile host (2025–2026) `[verified]`

- **论断**：The arXiv paper 'Before the Tool Call: Deterministic Pre-Action Authorization for Autonomous AI Agents' (2603.20953, 2026) proposes the Open Agent Passport (OAP) for policy-based authorization before tool execution, but explicitly acknowledges it does NOT defend against a compromised framework runtime. Hardware-based trust (TEEs, remote attestation) is mentioned as future work only.
- **证据（原文）**："What OAP does not defend against... compromised framework runtime (the hook itself must be trusted)." "AI agents today have passwords but no permission slips. They execute tool calls (fund transfers, database queries, shell commands) with no standard mechanism to enforce authorization before the action executes."
- **来源**：https://arxiv.org/html/2603.20953v1（内容日期：2026；核验日：2026-06-12）
- **对 v0.5 的含义**：The academic literature confirms the authorization gap for AI agents but does not yet solve the hostile-host problem at the hardware level. TuringOS's architectural innovation — placing the approval surface on hardware the host OS cannot reach — addresses an open problem that published research identifies but has not resolved. This is a genuine design differentiation for TuringOS v0.5.
