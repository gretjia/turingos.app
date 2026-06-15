---
atom: A1_51_galaxy_starsystems
phase: "1"
superseded_by: ["A1_51a_camera_spine", "A1_51b_galaxy_layout", "A1_51c_metal_lod_tiletree", "A1_51d_v6_aesthetics", "A1_52_commit_observation"]
intent: >
  【SUPERSEDED 2026-06-14 by ADR-016 — 本卡预于「无限缩放望远镜」裁决，已拆为 A1_51a（相机骨架）/
  A1_51b（分支+commit 节点派生 + 星系/泳道布局）/ A1_51c（Metal+LOD+tile-tree+DeferredRef）/
  A1_51d（V6 美学），并新增 A1_52（daemon commit 观测）。研究综述/字体/玻璃/星云实证迁入
  research/R1_infinite_zoom_memo.md §7 与 A1_51d。保留本卡以存历史（M5 留痕），**不再作为开工卡**。】

  galaxy 名副其实——把 A1_49 的「每项目分支计数」临时占位换成真正的 galaxy：每条分支（与 worktree）
  充分展开成自己的节点，每个项目布局成一个独立星系（默认分支=中心锚/恒星；分支按 A1_50 的 git 关系
  数据从主干分叉铺开：merge_base=分叉点、ahead/behind=离主干远近），所有星系散布在同一片深空里、
  合起来才是 galaxy。V6 美学做到位（打包 Inter/JetBrains Mono；手工深色玻璃节点卡；多停止点柔星云；
  巨型幽灵项目名；星网边缘渐隐；源色贝塞尔 DAG 边）。Software 3.0 极简**逐节点**保留（节点选中前
  只是带标题的安静光点；远景=安静光点群+幽灵项目名；近景=节点细节）。**绿 BY LAW 保留**（分支节点
  不上 merged-green，A1_50 已令 merged_into_default 恒 false；sound merged-green=A1_53）。项目辨识色=
  第二通道（VISUAL_SEMANTICS rules 5-7），只上身份表面（星云/巨字/轨道），绝不冒充语义色。

  用户裁决（2026-06-14）：① 授权改已裁决的 V6 默认宏观视图（ADR-012 停点已解锁，收工配视觉签字）；
  ② galaxy 的本意=节点充分展开、每项目一星系、聚合成 galaxy，不是压缩计数；③ 极简只约束单节点 chrome。

  研究背书（workflow wf_ebac4b99，本机实证，见 verified_external_facts）：字体走运行时注册（Bundle.module +
  CTFontManagerRegisterFontsForURL，App.init() 内）；深色玻璃走手工配方（同窗内无法真模糊 SwiftUI Canvas
  兄弟层，且 CSS 规范本就是固定深填充非 Material）；柔星云走多停止点缓出径向渐变（绝不 animate .blur）。
allowlist: []   # SUPERSEDED（ADR-016）：清空 allowlist——即便被误开为 CURRENT 也授予零编辑面（belt-and-suspenders；对抗复核 wf_49c47696 建议）。真实工作面在 A1_51a/b/c/d + A1_52。
max_new_files: 0
predicates:
  - "bash scripts/shipgate.sh p1 全绿（16 门；过门前 pkill 'turingosd serve' 防 wire-probe flake；MIN_TESTS 随新增 Swift 测试同步上调）"
  - "字体真打包+真注册（非静默回退）：TypographyTests 注册后断言 NSFont(name:\"Inter\",size:12)!=nil ∧ NSFont(name:\"JetBrains Mono\",size:12)!=nil；build_app.sh 守卫 TuringOS_TuringOS.bundle 存在并 cp 进 Contents/Resources/（实证放别处崩）"
  - "分支→节点派生测：inline BranchObserved（含 ahead/behind/merge_status/contained/is_default）fold → RadarScene 每条分支一个节点（不是计数）；默认分支节点 isAnchor=true；同 ledger ⇒ 同 positions（确定性）"
  - "绿保留不变式测：任何分支节点的 form/chrome 都不产出 .green（断言 merged-green 永不渲染——A1_50 令 merged_into_default 恒 false + RadarModel 诚实律）；contained/merge_status 用中性 chrome/位置呈现，不上色"
  - "星系布局测：每项目=空间一区（项目间最小间距断言、零跨项目边）；分支按 merge_base 锚分叉点、按 ahead/behind 定半径；fork 边存在；canonicalDump 含逐分支节点；committed golden 重生后逐字节相等"
  - "语义缩放测：far 阈值下节点压成光点 + 幽灵项目名升起（V6 §7.2 hide-list：分支细节/徽章隐，项目巨字显）"
  - "真机视觉评审（主观判据，走 RiskFinding + 用户签字，**不冒充机械 predicate**）：截图运行中的 galaxy，用户确认忠于 V6 气质且读得出「星系聚成 galaxy、节点充分展开、单节点安静」"
verified_external_facts:
  - fact: "自定义字体打包进 swift-build 手装配 .app：运行时注册最稳——Package.swift executableTarget 加 `resources:[.copy(\"Resources/Fonts\")]` → 产出 `TuringOS_TuringOS.bundle`（PackageName_TargetName）；build_app.sh 在建 Contents/Resources 后 `cp -R .build/debug/TuringOS_TuringOS.bundle Contents/Resources/`（实证：放别处则首次 Bundle.module 访问崩 'unable to find bundle'）；App.init() 内 CTFontManagerRegisterFontsForURL(.process) 遍历 Bundle.module 的 Fonts/（**必须 view 创建前**，否则 SwiftUI 静默回退系统字体且永不重试）；Font.custom 用 family 名（'Inter'/'JetBrains Mono'，非文件名）；用静态分重 .ttf（Inter-Regular/Medium/SemiBold/Bold）+ .fontWeight() 最可靠；名字用 fc-scan 核。注意：本机 PATH 的 swift 坏的，必须 xcrun+DEVELOPER_DIR=Xcode-beta（build_app.sh 已设）。"
    source: "workflow wf_ebac4b99-036 research:fonts（本机 macOS27/Swift6.4 实证：装配真 .app 跑通；nilcoalescing.com + christiantietze.de + Apple InfoPlistKeyReference）"
    verified_on: "2026-06-14"
  - fact: "深色玻璃：SwiftUI 同窗内无法真模糊一个 SwiftUI Canvas 兄弟层——.ultraThinMaterial 在近黑底上发白（方向反），NSVisualEffectView .withinWindow 看不见 SwiftUI 兄弟（渲染成空白板，Apple Forums 711559），.behindWindow 模糊的是桌面。CSS 规范本就是固定深填充非 Material，故忠实做法=手工配方：RoundedRectangle 填 Color(.sRGB,0.059,0.059,0.078,opacity:0.5)=rgba(15,15,20,0.5) + strokeBorder(.white.opacity(0.05),1) + .shadow(.black.opacity(0.5),radius:30,y:20) + 顶边 linear-gradient(.white.opacity(0.12)→clear) overlay 拟 inset 辉光。要真 backdrop-blur 则另渲一份预模糊星场副本 clip 到卡形垫底（非模糊卡本身）。macOS26 glassEffect() 有深底发白 beta bug，不可靠。"
    source: "workflow wf_ebac4b99-036 research:dark-glass（Apple Forums 711559/790260 + NSVisualEffectView docs + onmyway133）"
    verified_on: "2026-06-14"
  - fact: "柔星云+幽灵字+星场性能：**绝不 animate .blur**（macOS 上动画 blur ~50% CPU；静态一次性 blur 才安全）。柔星云=多停止点(8-13)缓出径向渐变拟 150px 模糊、零 blur pass、Canvas 内可 context.fill(.radialGradient(Gradient(stops:)))；2 停止点会带状硬盘化。幽灵巨字=静态 Text .white.opacity(0.03)（+一次性 .blur 可选）。静态层（星云+幽灵字）必须与动画星场 Canvas 分离，否则每帧重栅化。TimelineView(minimumInterval) 限频。"
    source: "workflow wf_ebac4b99-036 research:nebula-blur（OskarGroth/AuroraView + swiftui-lab + css-tricks easing-gradients + Apple GraphicsContext docs）"
    verified_on: "2026-06-14"
ux_touchpoints: >
  默认 galaxy 视图重做：宏观=深空里散布的项目星系（各自星云晕+巨型幽灵项目名+主干脊柱+分支光点群），
  近观=分支节点卡（玻璃配方）。改了已裁决的 V6 默认宏观（scale 0.25）——用户 2026-06-14 解锁 ADR-012 停点，
  收工配真机截图视觉签字。导航仍走 macOS 菜单（A1_30，不加回侧边栏）。
gate: "bash scripts/shipgate.sh p1"

# 代码思路

## 字体（Package.swift / TuringOSApp.swift / build_app.sh / Resources/Fonts）
- Resources/Fonts/ 放 Inter-{Regular,Medium,SemiBold,Bold}.ttf + JetBrainsMono-{Regular,Medium,Bold}.ttf + 两份 OFL.txt（OFL 合规）。来源=官方 Google Fonts OFL 镜像（raw.githubusercontent.com，允许域）；fc-scan 核 family 名。
- Package.swift：executableTarget 加 `resources:[.copy("Resources/Fonts")]`。
- TuringOSApp.init()：registerBundledFonts()——Bundle.module.url(forResource:"Fonts") 遍历 ttf/otf，CTFontManagerRegisterFontsForURL(.process)。view 创建前。
- build_app.sh：`test -d .build/debug/TuringOS_TuringOS.bundle || exit 1`；`cp -R` 进 Contents/Resources/；MIN_TESTS +新测。

## DesignTokens
- Typography.ui/mono 保持 .custom(family).weight()（family 名不变，现在真有字体了）。
- 新增 glass 配方常量（fill/border/outerShadow/insetGlow 值）+ nebula 多停止点 Gradient.Stop 数组（缓出）+ ghost-label 字阶。

## RadarModel（结构核心）
- BranchFact 已有 mergedIntoDefault/provenance；A1_50 的 ahead/behind/merge_status/contained 需在 AttentionModel.BranchFact 补字段并 fold（app 侧承接 A1_50 daemon 输出）。
- RadarScene.derive：除 worktree 节点外，从 ledger.branches 派生**分支节点**（新 RadarNode 或带 kind 区分；默认分支 isAnchor）。
- RadarLayout 改写：从「横轨道 row*laneHeight」→「星系团」：项目中心在世界空间确定性散布（如按 project_id 稳定 hash 落到松散螺旋/网格，项目间留足间距）；星系内：默认分支=中心锚，分支角度=stableHash(branch_ref)、半径=base + k*(ahead+behind) 截断（contained 近、diverged 远）；fork 边=分支→其 merge_base 在主干上的锚点。
- 诚实律：分支节点 form 不含 green；contained 用中性（如近主干位置/暗白），merge_status 经位置+形态表达，绝不上色绿。worktree=贴在对应分支的活跃占用标记。
- canonicalDump 含逐分支节点；golden 重生。

## RadarViews（渲染）
- 三层分离（性能）：① 静态层=多停止点星云径向渐变 + 巨型幽灵项目名 Text(.white.opacity(0.03))（不随星场动画重栅化）；② 动画星场 Canvas（TimelineView 限频，星点+主干脊柱光流扫）；③ 节点 overlay（玻璃配方卡，selected 前 farDot/标题光点）。
- 玻璃卡=手工配方（fill+border+outerShadow+insetGlow 顶边渐变 + cornerRadius 16 + 顶部 card-glow-line currentColor）。
- 边=源色贝塞尔（membership/fork 中性、conflict 黄；可选 flow 虚线但避免每帧重算 gradient）。
- 语义缩放：far 阈值下节点→光点、徽章/分支名隐、幽灵项目名升（V6 §7.2）。
- 星网加边缘渐隐 mask（径向 alpha 衰减）。

## 规模提示
本卡大（结构重做+美学+字体）。实现按「字体→tokens/玻璃→星云/幽灵字/星网（静态层）→分支节点派生+星系布局→节点卡玻璃化→语义缩放→golden→真机视觉评审」推进；任一步过大可中途 checkpoint 拆卡。
