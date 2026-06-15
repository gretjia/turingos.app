---
atom: A1_51d_v6_aesthetics
phase: "1"
depends_on: ["A1_51c_metal_lod_tiletree"]
intent: >
  V6 美学落位——A1_51 拆卡第四颗。把望远镜从「结构正确」推到「忠于 V6 气质」：

    - **字体真打包 + 真注册（独立可调函数 + 真注册断言）**：Resources/Fonts/ 放 Inter-{Regular,Medium,SemiBold,
      Bold}.ttf + JetBrainsMono-{Regular,Medium,Bold}.ttf + 两份 OFL.txt（官方 Google Fonts OFL 镜像，允许域）；
      Package.swift `resources:[.copy("Resources/Fonts")]`（A1_51c inline shader 未注册任何 resource，本卡是首个
      resource、`resources:` 全新引入、无冲突）→ 产出 `TuringOS_TuringOS.bundle`；build_app.sh `cp -R` 它进
      Contents/Resources/。`registerBundledFonts()` = **自由函数 / Tokens.registerBundledFonts()**（不藏在
      App.init，因 `swift test` 不实例化 App），由 `TuringOSApp.init()`（生产，view 前）与 `TypographyTests`
      **双方调用**；TypographyTests 先断言 `CTFontManagerRegisterFontsForURL` 返回 true（真注册了），**再**断言
      NSFont(name:)!=nil——防「系统恰好装了 Inter 时 no-op 注册也过」的假绿。
    - **手工深色玻璃配方**：`Color(.sRGB,0.059,0.059,0.078,opacity:0.5)` + strokeBorder + shadow + 顶边渐变 inset
      辉光 + cornerRadius 16 + 顶 glow-line（**不用** ultraThinMaterial/glassEffect）。
    - **柔星云 + 零 blur**：多停止点(8-13)缓出径向渐变拟 150px 模糊；**galaxy 渲染文件一律零 `.blur(`**——软辉光
      全走多停止点渐变（card 已证 8-13 停止点零 blur pass 等效 150px 模糊），**取消静态一次性 .blur 余地**，使
      「禁 animate-blur」成为文件级可判定。巨型幽灵项目名=静态 `Text(.white.opacity(0.03))`。
    - **三层文件分区**（性能 + grep 可判定）：静态层（星云+幽灵字）独立到 **`GalaxyStaticLayer.swift`**；动画星场
      （TimelineView 限频）；节点 overlay（玻璃卡）。星网边缘渐隐 mask + 源色贝塞尔 DAG 边（fork/parent 中性、
      conflict 黄）。
    - **身份色合规（真 teeth）**：项目辨识色只上身份表面（星云/巨字/轨道），且**只经 `Tokens.Accent.color(forProjectId:)`**
      取色——grep 断言 nebula/ghost/axis 渲染路径不内联 raw hex（防绕过距离校验的调色板）。诚实律不变：branch/commit
      节点 chrome 仍永不 .green（承 A1_51b 对实际节点 + 携 merged-flag 对抗 fixture 的不变式；本卡玻璃卡 chrome
      不引入新颜色到节点 chrome）。

  **重视觉签字**：收工配真机截图，用户确认忠于 V6 气质且读得出「星系聚成 galaxy、节点充分展开、单节点安静」
  （主观判据走 RiskFinding + 用户签字，**绝不冒充机械 predicate**）。
allowlist:
  - "app/Package.swift"
  - "app/Sources/TuringOS/Resources/Fonts/**"
  - "app/Sources/TuringOS/TuringOSApp.swift"
  - "app/Sources/TuringOS/DesignTokens.swift"
  - "app/Sources/TuringOS/RadarViews.swift"
  - "app/Sources/TuringOS/GalaxyRenderer.swift"
  - "app/Sources/TuringOS/GalaxyStaticLayer.swift"
  - "app/Tests/TuringOSTests/TypographyTests.swift"
  - "scripts/build_app.sh"
  - "specs/atoms/A1_51d_v6_aesthetics.md"
  - "specs/atoms/NUMBERING.md"
  - "specs/atoms/CURRENT"
max_new_files: 11   # 本卡**新建**：Inter ×4 + JetBrainsMono ×3 + 2×OFL.txt + TypographyTests.swift + GalaxyStaticLayer.swift = 11（GalaxyRenderer.swift 由 A1_51c 创建、本卡只**编辑**、不计入）；M4 扁平预算超 3 = 字体 OFL 二进制 + 静态层文件分区 minimalism RiskFinding 已justify+disclosed
predicates:
  - "bash scripts/shipgate.sh p1 全绿（16 门；app lane 门16 真 swift build+test+bundle+wire-probe；build_app.sh 在 allowlist 内——字体 bundle cp + MIN_TESTS 因 TypographyTests 上调皆合规；过门前 pkill 'turingosd serve'）"
  - "字体真打包+真注册测：TypographyTests **直接调** registerBundledFonts()，先断言 CTFontManagerRegisterFontsForURL 返回 true（真注册），**再**断言 NSFont(name:\"Inter\",12)!=nil ∧ NSFont(name:\"JetBrains Mono\",12)!=nil；build_app.sh 守卫 `test -d .build/debug/TuringOS_TuringOS.bundle` 并 cp 进 Contents/Resources/。【实现期先经验确认 Bundle.module 在 swift test 路径可解析 Fonts/；若否，改用 Bundle(for:) 句柄传入】"
  - "无 .blur 测（**文件级 grep，零余地、可判定**）：`grep -c '\\.blur(' app/Sources/TuringOS/RadarViews.swift app/Sources/TuringOS/GalaxyRenderer.swift app/Sources/TuringOS/GalaxyStaticLayer.swift` 累计 == 0（软辉光全走多停止点渐变、无任何 .blur pass）"
  - "玻璃配方测（**正向耦合，非仅 absence**）：DesignTokens 含手工玻璃配方常量（fill rgba(15,15,20,0.5)/border/outerShadow/insetGlow）；（a）grep 断言节点卡渲染路径无 glassEffect/ultraThinMaterial；**（b）grep 断言节点卡渲染函数引用每个配方常量符号**（Tokens.Space.glassBase/glassBorder + 新 insetGlow/outerShadow）——absence-of-wrong-material ≠ presence-of-right-recipe，防节点卡裸 RoundedRectangle/配方常量声明未用的假绿"
  - "诚实律 + 身份色合规测：（a）绿保留=**继承自 A1_51b 的回归守卫**（A1_51b 已建「对派生 branch/commit 节点断 chrome≠.green + 携 contained/merged flag 对抗 fixture」的测；本卡**不编辑**该测、RadarModelTests 不在本卡 allowlist——开工前 /atom-open 须确认 A1_51b 受理回执含该测、本卡只享其回归保护）；本卡**自有**断言落 RadarViews（在 allowlist）：grep 节点卡玻璃 chrome **不引入任何新颜色/语义色到节点 chrome**；（b）身份色——grep 断言 nebula/ghost/axis 三渲染文件**任何 Color(.sRGB/Color(hex:/Color(red: 字面量 == 0**（身份面只引用 Tokens.Accent.color(forProjectId:)，杜绝绕过距离校验的内联/旁路取色）；Accent palette RGB 距离 ≥72 离每语义六色锚、≥56 离每其它 accent（承现有 DesignTokensTests，回归守卫）"
  - "场景 golden 不变测：fixtures/snapshots/p1_galaxy_scene / p1_radar_scene / a1_09_mixed scene golden **逐字节不变**（vs **A1_51b 重生后的基线**；美学不改 scene 派生，read-only 非变更断言、不入 allowlist 改它们）"
verified_external_facts:
  - fact: "自定义字体打包进 swift-build 手装配 .app：运行时注册最稳——Package.swift executableTarget 加 resources:[.copy(\"Resources/Fonts\")] → 产出 TuringOS_TuringOS.bundle（PackageName_TargetName）；build_app.sh 在建 Contents/Resources 后 cp -R 它进去（实证：放别处则首次 Bundle.module 访问崩 'unable to find bundle'）；注册函数遍历 Bundle.module 的 Fonts/ 调 CTFontManagerRegisterFontsForURL(.process)（必须 view 创建前，否则 SwiftUI 静默回退系统字且永不重试）；Font.custom 用 family 名（'Inter'/'JetBrains Mono'，非文件名）；用静态分重 .ttf；fc-scan 核名；本机 PATH swift 坏、必须 xcrun+DEVELOPER_DIR=Xcode-beta（build_app.sh 已设）。"
    source: "workflow wf_ebac4b99-036 research:fonts（本机 macOS27/Swift6.4 实证：装配真 .app 跑通；nilcoalescing.com + christiantietze.de + Apple InfoPlistKeyReference）"
    verified_on: "2026-06-14"
  - fact: "深色玻璃：SwiftUI 同窗内无法真模糊 SwiftUI/Canvas 兄弟层（.ultraThinMaterial 近黑底发白，NSVisualEffectView .withinWindow 看不见 SwiftUI 兄弟，Apple Forums 711559）。忠实=手工配方：RoundedRectangle 填 Color(.sRGB,0.059,0.059,0.078,opacity:0.5) + strokeBorder(.white.opacity(0.05),1) + .shadow(.black.opacity(0.5),radius:30,y:20) + 顶边 linear-gradient(.white.opacity(0.12)→clear)。macOS26 glassEffect() 深底发白 beta bug。"
    source: "workflow wf_ebac4b99-036 research:dark-glass（Apple Forums 711559/790260 + NSVisualEffectView docs + onmyway133）"
    verified_on: "2026-06-14"
  - fact: "柔星云+性能：绝不 animate .blur（macOS 动画 blur ~50% CPU）。柔星云=多停止点(8-13)缓出径向渐变拟 150px 模糊、零 blur pass，Canvas 内 context.fill(.radialGradient(Gradient(stops:)))；2 停止点会带状硬盘化。幽灵巨字=静态 Text .white.opacity(0.03)。静态层（星云+幽灵字）必须与动画星场分离，否则每帧重栅化。TimelineView(minimumInterval) 限频。"
    source: "workflow wf_ebac4b99-036 research:nebula-blur（OskarGroth/AuroraView + swiftui-lab + css-tricks easing-gradients + Apple GraphicsContext docs）"
    verified_on: "2026-06-14"
ux_touchpoints: >
  galaxy 视觉忠于 V6 气质（星空 / 手工玻璃 / 语义发光 / 星系隐喻）：宏观=星云晕 + 巨型幽灵项目名 + 主干脊柱 +
  分支光点群 + commit 泳道，近观=玻璃节点卡。**收工配真机截图视觉签字**——用户确认忠于 V6 且读得出「星系聚成
  galaxy、节点充分展开、单节点安静」。主观判据走 RiskFinding + 用户签字，绝不冒充机械 predicate。
gate: "bash scripts/shipgate.sh p1"

# 代码思路

## 字体（Package.swift / TuringOSApp.swift / build_app.sh / Resources/Fonts）
- Resources/Fonts/ 放 .ttf + OFL.txt；Package.swift 首引 `resources:[.copy("Resources/Fonts")]`；
  `registerBundledFonts()` = 自由函数（Bundle.module.url(forResource:"Fonts") 遍历，CTFontManagerRegisterFontsForURL(.process)，
  返回 success bool），由 TuringOSApp.init()（view 前）与 TypographyTests 双调；build_app.sh 守卫 bundle + cp + MIN_TESTS +TypographyTests。

## DesignTokens（玻璃/星云/幽灵字常量）
- glass 配方常量；nebula 多停止点 Gradient.Stop；ghost 字阶。Typography.ui/mono 保持 .custom(family).weight()。

## 三层文件分区（GalaxyStaticLayer.swift new / RadarViews / GalaxyRenderer）
- GalaxyStaticLayer.swift：星云多停止点径向渐变 + 巨型幽灵项目名（静态，**零 .blur**）。
- RadarViews：动画星场（TimelineView 限频，**零 .blur**）+ 玻璃节点卡 overlay；星网边缘渐隐 mask；源色贝塞尔边。
- GalaxyRenderer：星云/星场可走 Metal 省 CPU（**零 .blur**）。三文件 `.blur(` 累计 0（谓词 3）。
- 身份色：nebula/ghost/axis 取色只经 Tokens.Accent.color(forProjectId:)，不内联 raw hex（谓词 5b）。
