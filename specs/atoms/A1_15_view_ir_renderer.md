---
atom: A1_15_view_ir_renderer
phase: "1"
intent: >
  Sprint 1 第一颗：View IR v0 的 Swift 落地（执行裁决红线 1 的工程主体）。
  (a) contracts/view_ir.schema.json + fixture（IR 文档：schema_version/kind/
  derive_source[]/blocks[]；14 种 block 类型枚举，与 docs/02 §3.3 完全一致）；
  (b) app 内 ViewIR Codable 模型（未知 block 类型 → 惰性 unknown 呈现，永不可执行）
  + ViewIRRenderer（每种 block 映射第一方 SwiftUI 组件；approval_request 只经
  第一方 ApprovalCard；credential_field 只经 SecureField）+ 确定性模板投影工厂
  （降级模式：无模型时从类型化状态产 IR）；(c) 单元测试 + 渲染描述 golden。
  不接 Orb（A1_16 的事）；不接真实模型。
allowlist:
  - "app/Sources/TuringOS/"
  - "app/Tests/TuringOSTests/"
  - "contracts/view_ir.schema.json"
  - "contracts/README.md"
  - "fixtures/"
  - "scripts/build_app.sh"
  - "scripts/validate_contracts.sh"   # retroactive amendment 2026-06-12: view_ir entry added to sprint0_map is functionally necessary for the fixture predicate; scope expansion noted per CLAUDE.md §铁律 rule 2
  - "specs/atoms/CURRENT"             # retroactive amendment 2026-06-12: CURRENT advanced A1_14→A1_15 as part of this atom's activation
max_new_files: 12
predicates:
  - "contracts/view_ir.schema.json 存在且 validate_contracts.sh PASS（含 fixture）"
  - "swift 测试含：未知 block 安全降级 / approval_request→ApprovalCard 唯一映射 / credential_field→SecureField / IR 解码 golden"
  - "MIN_TESTS 计数上调且 shipgate #16 app lane 绿"
  - "bash scripts/shipgate.sh p1"
verified_external_facts:
  - fact: "无新外部论断；全部派生自 docs/02_SOFTWARE_3_UI_PRD.md §3 与执行裁决红线 1"
    source: "docs/02_SOFTWARE_3_UI_PRD.md"
    verified_on: "2026-06-12"
gate: "bash scripts/shipgate.sh p1"
---

# 工序

1. Sonnet 实现（读 docs/02 §3 + 既有 app 代码风格 + contracts 纪律），含 schema、
   模型、渲染器、模板工厂、测试、MIN_TESTS。
2. Sonnet 对抗核验（自跑 build+test + 负控：往 IR fixture 塞 script/html block →
   解码必须落 unknown 惰性路径；approval_request 渲染路径唯一性断言）。
3. 架构师终审 → shipgate 全绿 → 回执 → PR（堆叠 A1_14 分支）。
