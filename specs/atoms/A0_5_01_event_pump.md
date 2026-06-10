---
atom: A0_5_01_event_pump
phase: "0.5"
intent: >
  存在一个事件泵脚本：把任意 fixture 事件流原样重放到 stdout（可选节奏延时），
  作为渲染管道的标准输入源。泵不生成数据（M3：fixtures 是唯一事件真相）。
allowlist:
  - "scripts/simulate_event_stream.sh"
max_new_files: 1
predicates:
  - "bash scripts/shipgate.sh p0.5"
verified_external_facts: []
ux_touchpoints: >
  演示模式（--delay）让评审者看到事件逐条驱动界面状态的过程。
gate: "bash scripts/shipgate.sh p0.5"
---

# 代码思路

bash while-read 循环逐行输出 fixture；参数 1 = fixture 路径（默认 p1），参数 2 = 行间延时秒（默认 0）。无 JSON 解析（泵不理解内容，校验是 validate_contracts 的职责——单一职责）。
