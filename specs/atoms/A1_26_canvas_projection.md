---
atom: A1_26_canvas_projection
phase: "1"
intent: >
  白皮书 §6.7 Canvas Projection v1 正文落地：自建无边界画布的确定性投影核心
  （非第三方 Freeform——已实证仅 1 个 Shortcuts 动作不可用）。(a)
  MarkdownAST 极简解析（heading/para/list/code/quote → 值类型节点，纯函数）；
  (b) CanvasLayout 确定性布局图（AST → 带坐标的布局节点，纯算术，无随机/无
  Date）；(c) 每个画布节点带 derive_source（派生自 Markdown/Spec/ChainTape/
  Receipt，§6.7 铁律：画布不是第二事实源）；(d) CanvasProjection → View IR
  文档（复用既有 block 类型呈现；SwiftUI 渲染走第一方，禁 WKWebView/HTML）；
  (e) 导出形状：纯数据导出描述（PDF/PNG/HTML/MD 的确定性序列化描述，不实际
  调用导出 API——渲染与导出实现属后续，本卡只锁可重建的投影核心）。
  Freeform 桥仅留 TODO 注释（§6.7：Apple 开放官方 API 再做，不逆向私有格式）。
allowlist:
  - "app/Sources/TuringOS/"
  - "app/Tests/TuringOSTests/"
  - "fixtures/"
  - "scripts/build_app.sh"
  - "specs/atoms/CURRENT"
max_new_files: 8
predicates:
  - "Markdown AST + 布局确定性 ×2 字节一致（纯函数，无随机/Date）；每节点 derive_source 非空"
  - "渲染零 HTML/JS 面（grep WKWebView/html/javascript 负控全净）"
  - "不逆向 Freeform：无私有格式写入（grep 负控）；Freeform 仅 TODO 注释"
  - "MIN_TESTS 上调；bash scripts/shipgate.sh p1 全绿"
verified_external_facts:
  - fact: "Freeform 公开自动化面仅 1 个 Shortcuts 动作（Add Files to Board）= A1_13 已核（FEASIBILITY Part IV-4）；Excalidraw MIT 为画布候选；本 atom 不新增外部论断"
    source: "FEASIBILITY.md Part IV + research/R_v05_protocol_live_sources.md"
    verified_on: "2026-06-12"
gate: "bash scripts/shipgate.sh p1"
---

# 工序

1. Sonnet 实现 + Sonnet 对抗核验（确定性 ×2、HTML 面负控、Freeform 不逆向负控、derive_source 强制）。
2. 架构师终审 → shipgate → 回执 → PR → 合 main（ADR-012）。
