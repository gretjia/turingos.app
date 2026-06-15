---
atom: A1_67_quit_demodalize
phase: "1"
depends_on: []
adr: "(NAVIGATION_MODEL: Glance 路径必须零模态、零阻塞)"
intent: >
  真机反馈 #3:程序无法退出——菜单「Quit TuringOS」/ ⌘Q / Dock 右键退出全部无效。
  我已真机复现(AX 点 menu item「Quit TuringOS」后 pid 89688 仍存活;System Events 显示
  window 1 上 sheets=1)。根因实锤:galaxy / 内核调试面由 OrbView 以**模态 `.sheet`**
  承载(OrbView.swift:81 `.sheet(isPresented: $showKernelDebug)`),而 macOS 在窗口模态
  sheet 存在期间拒绝 `NSApp.terminate:` ——用户处在 galaxy 时永远有一个 sheet 挂着,故
  Quit 恒被推迟。且 docs/NAVIGATION_MODEL.md 明文「Glance 路径(菜单栏 → Global Ops)
  **必须零模态、零阻塞**」——这个 sheet 本身就是违纪。

  **本卡范围(最小、可 computer-use 验):** 把 kernel-debug `ContentView` 从模态 `.sheet`
  改为 OrbView `ZStack` 内的**非模态全幅覆盖**:
  - `showKernelDebug` 标志保持不变(菜单/⌘D/调试按钮仍切换);为 true 时在 ZStack 顶层条件
    渲染 `ContentView`(opaque 背景 + `maxWidth/Height: .infinity`),`.transition(.opacity)`
    安静淡入。
  - 返回 Orb 的三条路保留并补全:`.showOrb`(⌘0)、`Escape`(`.onExitCommand`)、覆盖层左上角
    一个**安静**的「‹ Orb」玻璃胶囊按钮(发现性,符合「安静即成功」)。
  - 不再有任何模态 sheet → `terminate:` 立即生效 → Quit 复活;同时满足 NAVIGATION_MODEL
    零模态零阻塞。

  **副作用利好(本卡不声称、不验收):** ContentView 现在填满主窗口(可调整大小 / 可全屏),
  为 #2(A1_60 全屏 / resize 重取景)铺路。

  **不做(押后):** #2 的 resize 重取景(A1_60)、#4 细节卡(A1_57/A1_58)、#1 主线布局重构(A1_63)。
allowlist:
  - "app/Sources/TuringOS/OrbView.swift"
  - "app/Sources/TuringOS/ContentView.swift"
  - "specs/atoms/A1_67_quit_demodalize.md"
  - "specs/atoms/NUMBERING.md"
  - "specs/atoms/CURRENT"
# allowlist 扩容留痕(2026-06-15,清洁视角对抗复核 agent ae14cbd5 发现):去模态后 ContentView
# 自带的 `.frame(minWidth:960,minHeight:600)` 会传导到主窗口 → 开 galaxy 把窗口棘轮放大到 ≥960
# 且 AppKit 不回缩 → 回 Orb 后窗口卡在超大尺寸(本卡引入的真回归)。修:把 ContentView 的硬 min
# 放到与 OrbView 主窗 min 一致(640×520,零棘轮),并把残留 "sheet" 注释改 "cover"。属"去模态干净
# 落地"的一部分,非范围蔓延。
max_new_files: 0
predicates:
  - "bash scripts/shipgate.sh p1 全绿(16 门;过门前 pkill GUI app + 'turingosd serve' + 删 lock —— A1_56 自动重生 daemon 会与 app-lane 探针抢锁)"
  - "golden 不变:本卡只动 OrbView 视图 chrome(presentation 模式),不碰 scene/positions/canonicalDump/契约/daemon → 所有 fixtures/snapshots golden 逐字节不变;RadarModelTests/AppCommandBusTests 仍绿(ContentView.applyCommand 未动)"
  - "无回归:swift build+test 绿;galaxy(内核调试面)仍经 内核调试按钮 / ⌘D / 视图菜单可达且渲染;⌘0 / Escape / ‹Orb 按钮三路都能回 Orb"
  - "**真机 UX 验证(我 computer-use,RiskFinding+截屏)**:① 启动 app → 进 galaxy → 菜单『Quit TuringOS』(AX 可靠路径)**真的退出**(pid 消失);② 进 galaxy 时 System Events `sheets=0`(无模态);③ ⌘0/Escape/按钮回 Orb 有效。存证 /tmp/galaxy_evidence/a167_*.png + sheets-count 文本。残留如实记 RiskFinding。"
verified_external_facts:
  - "macOS 在窗口模态 sheet 期间拒绝 NSApp.terminate(经本机 AX 实证:sheets=1 时 Quit menu item 点击后进程存活) — verified_on 2026-06-15"
ux_touchpoints: >
  退出:任何 galaxy 状态下 Quit / ⌘Q / Dock 退出都能干净退出(修 #3)。
  零模态:内核调试面不再是阻塞 sheet(合 NAVIGATION_MODEL)。返回 Orb 的安静 affordance。
gate: "bash scripts/shipgate.sh p1"

# 代码思路
## OrbView.swift
- 删 `.sheet(isPresented: $showKernelDebug) { ContentView... }`。
- ZStack 内 VStack 之后追加条件覆盖层:
  `if showKernelDebug { ContentView(store: store).environmentObject(commandBus)`
  `  .transition(.opacity).zIndex(10)`
  `  .overlay(alignment: .topLeading) { backToOrbButton }`
  `  .onExitCommand { withAnimation { showKernelDebug = false } } }`
- `handleAppCommand` 里 `showKernelDebug = true/false` 包 `withAnimation(.easeInOut(duration:0.2))`;
  调试按钮同。
- 新增 `backToOrbButton`:玻璃胶囊「‹ Orb」,`buttonStyle(.plain)`,点击 `withAnimation{ showKernelDebug=false }`,
  accessibilityLabel「返回 Orb 主屏」。

## 验证
- 机械:shipgate p1 + golden 逐字节不变(纯视图 chrome)。
- 真机:computer-use 启动→进 galaxy→AX 菜单 Quit 真退出 + sheets=0 + 三路返回 Orb。
