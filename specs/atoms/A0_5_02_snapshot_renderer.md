---
atom: A0_5_02_snapshot_renderer
phase: "0.5"
intent: >
  存在一个确定性渲染器：stdin 吃事件 JSONL，fold 成投影（项目/worktree/会话/提案/仪式），
  输出携带投影三件套头部的 markdown 仪表板。同输入必同字节。p1 流的渲染结果锁为 golden。
allowlist:
  - "scripts/render_snapshot_placeholder.sh"
  - "fixtures/snapshots/**"
  - "scripts/shipgate.sh"
max_new_files: 3
predicates:
  - "bash scripts/shipgate.sh p0.5"
verified_external_facts: []
ux_touchpoints: >
  这是 Radar/Proposals 视图的最早占位证明：评审者第一次看见 contracts 事件变成界面状态；
  徽章以 VISUAL_SEMANTICS 语义词文本呈现（色彩绑定留给 SwiftUI design tokens 阶段）。
gate: "bash scripts/shipgate.sh p0.5"
---

# 代码思路

python3 stdlib：读全部事件 → 按 kind fold 状态字典（排序遍历保证确定性）→ 渲染 markdown 段落
（头部三件套 + as_of_seq=max(seq) + Worktrees/Sessions/Proposals/Ratifications/事件尾表）。
shipgate p0.5 追加两检：四条流双渲染 sha256 一致；p1 渲染 == fixtures/snapshots/p1_worktree_radar.golden.md。
