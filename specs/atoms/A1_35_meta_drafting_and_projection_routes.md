---
atom: A1_35_meta_drafting_and_projection_routes
phase: "1"
intent: >
  白皮书特性补全三件（lawful-now）：
  (a) Meta AI 真实调用（§5.2 起草职能的合法子集）：MetaDrafting 服务（同
  A1_34 FacilitatorDialogue 模式），preset = DeepSeekPresets .meta
  （deepseek-v4-pro, thinking ENABLED）。触发：意图含 起草/draft/帮我写 且
  wizard session 活跃 → 把已答步骤打包为上下文发给 Meta → 起草建议文本进
  summary_card（红线 1）。红线 4 铁律：Meta output = PROPOSAL ONLY——绝不
  写入 wizard session/spec 状态，用户读后自行作答采纳。
  (b) "预算"/"budget" 意图 → BudgetProjections.budgetDraftCard（A1_19 投影
  首次接入 UI 路由；默认草案 BudgetContract + spec hash 来自活跃 wizard 或
  占位）。确定性，零模型。
  (c) "批准"/"approval" 意图 → A1_23 ApprovalEnvelopeBuilder 构造演示 draft
  + approval_request 块经第一方 ApprovalCard 渲染（验证渲染铁律落 UI）。
  确定性（注入固定 nonce/expiry），零模型，零签名仪式（draft only）。
allowlist:
  - "app/Sources/TuringOS/"
  - "app/Tests/TuringOSTests/"
  - "scripts/build_app.sh"
  - "specs/atoms/CURRENT"
max_new_files: 4
predicates:
  - "Meta golden：起草意图 + wizard 活跃 → 请求体 model==deepseek-v4-pro 且 thinking enabled 且上下文含已答步骤（mock transport 断言）；wizard 状态前后逐字节不变（红线 4 负控）"
  - "起草意图但 wizard 不活跃 → 确定性提示卡（先立项），零 gateway 调用"
  - "预算/批准意图 → 确定性投影 ×2 字节一致，零 gateway 调用（负控）；approval 卡含 approval_request 块"
  - "测试零网络；MIN_TESTS 上调；bash scripts/shipgate.sh p1 全绿"
verified_external_facts:
  - fact: "v4-pro thinking wire 已于 A1_31 真 key probe 验证（PRO_OK + reasoning_content）；零新外部论断"
    source: "specs/atoms/receipts/A1_31_deepseek_live_wiring.receipt"
    verified_on: "2026-06-12"
gate: "bash scripts/shipgate.sh p1"
---

# 工序

1. Workflow：Sonnet 实现 + 2 路对抗验证（红线 4 状态不变性 + golden / 投影确定性 + 零调用负控）。
2. 架构师终审 → shipgate → 回执 → 合 main → computer-use 真实验证（Meta 起草应答 + 预算/批准卡）。
