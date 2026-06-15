# R1 增补备忘 — 无限缩放 Galaxy 望远镜（2026-06-14）

> R→D→S 的 R-stage 持久化产物。`research/R1_memo.md` 仍是 Phase 1 主门禁备忘；本文件是
> 无限缩放望远镜子项目的专门 R-stage 记录（研究综述 + 关键实证 + 重铸模型 + 用户裁决 +
> 待决项），把 `handover/INFINITE_ZOOM_GALAXY_HANDOFF.md` 与一次性 workflow 输出固化为
> 仓内可溯артifact（workflow 临时输出不留存，跨 session 须有此 memo）。
>
> 上游法源（不在此重写，只投影）：`constitution/constitution.md`（sha256 钉定）+ `WHITEPAPER.md`
> + `docs/UPSTREAM_CONTRACT.md` + `docs/VISUAL_SEMANTICS.md` + `docs/TRUST_STATES.md`
> + `design/V6_RECONCILIATION.md` + `design/SOFTWARE3_UX.md`。裁决登记于 ADR-016。

## 0. 一句话

把 galaxy 从「每项目一条横轨道 + 分支计数」重做成一台**无边际画布 + 无限语义缩放的望远镜**：
zoom out=深空里散布的项目星系全局；zoom in=项目星系→分支/worktree→commit→（P5+）ChainTape
决策节点。每档**只渲已观测的**；单节点 Software 3.0 极简；绿 BY LAW 保留（不假绿）；
项目辨识色=第二通道。这是子项目级重做（相机/渲染架构 + 跨粒度数据模型 + LOD）。

## 1. 决定性实证：daemon 可观测深度（**纠正交接文档 §3 的层级模型**）

深读 `daemon/src/{branch_poller,events,projection}.rs`（2026-06-14 本仓真跑核源）实锤：

- **今天 daemon 可观测的最深粒度 = 分支顶点（branch-tip）**。`BranchObserved` payload 字段集
  （`branch_poller.rs:407-422`）：`project_id / branch_ref / head_sha / is_default /
  provenance / merge_status∈{ahead,behind,identical,diverged,unknown} / ahead:u32 /
  behind:u32 / merge_base:sha / contained_in_default:bool / merged_into_default:false(常量)`。
- **没有 per-commit 事件、没有 commit 列表、没有 commit DAG**。`ahead:3` 是标量计数，不是 3 个
  可渲 commit 节点。23 个 `EventKind`（`events.rs:67-93`）里**无 `CommitObserved`**；
  `DiffSnapshot`/`FileChanged` 是文件级、非 commit-graph。
- **ChainTape 决策节点不可观测**：`DeriveSource::Chaintape` 存在但 `rebuild_command =
  "replay the upstream ChainTape (P5+ wiring)"`（`projection.rs:129`），今天 live hub 是
  `Git`、该源**发空**。决策粒度的 EventKind（`ProposalCandidate/PredicateResult/VetoVerdict/
  AgentSession*` 等）schema 已声明但只 fold 计数、非 git-derivable，等 P5+ `ClaudeHook/
  CodexAppserver` 源接进 ChainTape 才有。

**含义（约束计划的硬事实）**：研究综述 §4C 设计的「git commit-graph 在线泳道布局」**现在无源
可渲**——画出来=渲染未观测数据=违 Art.0 诚实律（`assert(view==derive_from_tape(tape))`，
constitution Art.0.2:81）。故 commit 层与 decision 层都在 **DeferredRef 缝之下**，原因不同：
decision=P5+ runtime ChainTape；commit=daemon 观测缺口（git 里有、daemon 当前不发）。

**用户裁决（见 §4 决策①）**：本轮**补一颗 daemon commit 观测原子**（A1_52）让 commit 层可观测，
故 commit-graph 泳道在本轮回归。

## 2. 重铸的望远镜模型（按"真可观测"分层）

| 档 | 表征 | 数据源 | 状态 |
|---|---|---|---|
| 项目（深空全局） | 星云晕 + 巨型幽灵项目名 | `ProjectRegistered` + 注册表 | ✅ 现可观测 |
| 项目星系 / 簇 | 簇泡（聚合 glyph） | 派生分组 | ✅ |
| 分支 / worktree | 节点卡（玻璃）；默认分支=中心锚 | `BranchObserved`/`WorktreeDiscovered` | ✅ |
| commit（git） | commit-graph 在线泳道节点 | `CommitObserved`（A1_52 新增） | 🟡 本轮接通 |
| ChainTape 决策节点（动作/提案/批准/失败） | — | `DeriveSource::Chaintape` 发空 | ⛔ P5+ leaf-until-provider |

**星系内布局**：默认分支=中心恒星锚；分支角度=`stableHash(branch_ref)`、半径=`base +
k·(ahead+behind)` 截断（contained 近主干、diverged 远）；fork 边=分支→其 `merge_base` 在
主干上的锚点（merge_base 是今天唯一可得的跨分支 DAG 锚）；commit 泳道在分支内展开
（row=时序拓扑排序、lane=active-branches 列表，pvigier/gitk 在线泳道算法）。

**诚实律映射（每档都绑）**：① 绿 BY LAW 缺席——`merged_into_default` 恒 false
（`branch_poller.rs:421`），`contained_in_default` 只是「可达性」（revert 后仍 true 但内容已撤），
**绝不渲染成 merged-green**；sound merged-green=未来 A1_53（内容/树级核验或人工确认）。
② `merge_status=unknown`（gh 失败）渲成真实「未观测」，不补桩不冻旧值。③ trust 色只从
`event_stream.schema.json` 的 11 值 `trust_state` 枚举映射（分支/commit 观测=`observed_unsigned`
=gray），禁止自造红黄绿。④ 项目辨识色=第二通道，只上星云/巨字/轨道（VISUAL_SEMANTICS rules
5-7），分支/commit 节点不上语义绿。⑤ 远景聚合 tile 显示**抽象计数/命名类**，绝不喷原始报错日志
（Art.II.1:442「灾难性上下文污染」）；原始细节只在钻到单叶时可见。⑥ 失败节点（P5+ `verified=false`）
必须诚实渲染、绝不藏进 graveyard（Art.0.2:85；`failure_node.schema.json` `verified` const=false）。

**语义缩放 = Art.III.2「细节封装/渐进披露」的视觉化**（constitution:528-542「百科全书的目录
接口，不是百科全书」，与项目 CLAUDE.md「目录，不是百科全书」同一条法）。定 z 阈值 band
（galaxy/cluster/node/detail），每 band 换表征 + cross-fade + 滞回防闪；远景成本 O(#簇) 非 O(#节点)。

## 3. 架构骨架（全部 app 侧原生 SwiftUI/Metal，零 git 调用，ADR-005）

- **Camera（A1_51a）**：抄 tldraw `Camera{x,y,logZoom}`，`screenToPage/pageToScreen`、
  zoom-to-cursor 闭式、floating-origin（每帧 renderOrigin 贴近相机）、世界坐标全 Double（审掉任何
  Float32——jitter 病根）。log 空间 z∈[~0.01,256]，logerp 平滑；替掉现 `RadarCamera` 的
  scale+offset、0.1–2.0 线性、单一 isFar 阈值。
- **Tile-tree（A1_51c，内部结构非契约）**：照搬 OGC 3D Tiles `tileset.json` 从空间泛化到语义
  粒度。`tile{level∈{project,branch,commit,decision}, bounds(语义 extent: refRange/commitRange/
  timeRange，子 bounds⊆父), summary/rollup, detailThreshold(=geometricError 标量), refine:REPLACE}`。
- **LayerProvider 接口（A1_51c）**：`getTile/getChildren`；`GitProvider` 现服务
  project/branch/commit（A1_52 后）；`ChainTapeProvider` 以后注册服务 decision 子树。
- **DeferredRef 缝（A1_51c）**：commit→decision 边界返回 `DeferredRef("chaintape", …)`，
  未注册=**leaf-until-provider 一等公民**（不是错误、不渲合成决策节点）；命名对齐
  `DeriveSource::Chaintape`。P5+ 同一 DeferredRef 解析成 decision 子树缝进来——**零重设计**。
- **渲染（A1_51c）= Metal 实例化 + SwiftUI a11y overlay 混合**（用户裁决③）：MTKView 一次
  `drawIndexedPrimitive(instanceCount:)` 画密集视觉层（星场/星云/边/远景光点 glyph/commit 泳道）；
  **节点卡 + a11y 镜像层保留 SwiftUI overlay**——VISUAL_SEMANTICS rule 3「可达性 0/1 谓词覆盖」
  + 现有 `RadarNode.accessibilityLabel` 测试钉死每节点 a11y，Metal 绘制不在 a11y 树，故必须
  混合（远景光点也要 a11y-only SwiftUI 层兜底）。配空间索引（GKQuadtree/KD-tree）+ 每帧视口剔除 +
  预聚合簇金字塔（Supercluster 模型）。
- **节点身份**（对齐 Art.0.3 CAS / Art.0.4 Q_t 三元组）：今天 branch=`(project_id,branch_ref)`、
  `head_sha`=变更检测内容哈希；worktree=`worktree_id`；project=`project_id`；commit=`commit_sha`
  （CommitObserved）。将来 decision 落地 id=`TapeNode.node_hash`（CAS Merkle-DAG，
  `tape_node.schema.json`），相机地址=`HEAD_t 路径 + 内容哈希`——4 层共用一套 Merkle-DAG 布局引擎
  （白皮书 §4.2/§4.3：git 即基质，decision 节点身份与 git commit 同模型）。
- **渲染路径澄清**：`ViewIR`（14 block 类型）是**模型输出契约**，非外壳布局引擎。galaxy 外壳是
  原生 SwiftUI/Metal，**不需要也不应**为它加 `galaxy_view` block；galaxy 直接从事件流 fold 出
  `RadarScene`（确定性 + golden 即守恒证明），不走 ViewIR。

## 4. 用户裁决（2026-06-14，本 session，/goal 授权自主执行）

1. **Commit 层**：本轮**加 daemon commit 观测原子**（A1_52，新 `CommitObserved` 事件，
   有界窗），让 commit-graph 泳道现在就能渲。（备选「渲到分支层、commit 留 DeferredRef」未采纳。）
2. **相机模型**：**整体换 tldraw 模型**（log-zoom + floating-origin + Float32 审计）。
3. **渲染选型**：**现在就上 Metal 实例化**（混合 SwiftUI a11y overlay）。（备选「Canvas+剔除起步」未采纳。）
4. **A1_51 拆卡**：**采纳 4 颗 a/b/c/d**（+ A1_52 daemon = 5 颗）。

## 5. 守宪法对账

**OBEYS（不重开）**：ADR-009 零跨项目边；A1_30 菜单导航不加侧边栏（`NavigationSplitView`
grep=0）；ADR-003 UI=派生投影 + 守恒；ADR-015 runtime/ trust-root 只读、外壳经接口消费不重写
ChainTape 语义（grep 红线）；ADR-005 SwiftUI+UDS 纯投影消费者零 git 调用；ADR-008 macOS-26
target / 27-SDK `#available` 源文件级隔离 / arm64 / 禁 beta-only（`glassEffect()` 深底发白
beta bug 已知不用）；M6 谓词 {PASS,FAIL}、主观走 RiskFinding。

**框架精确化**：交接文档「ADR-012 停点已解锁」是简写。**ADR-012 = 运行授权协议（钥匙）**；被冻结的
V6 默认宏观视图（centerWorld scale 0.25）立法在 **`design/V6_RECONCILIATION.md` §1（锁）**。
2026-06-14 用户用 ADR-012 停点/共创权**授权偏离那个 V6 默认**。推翻它走 `ADR.md:3`「新 ADR 条目 +
RATIFICATION_POLICY」（不静默改默认）= 本 memo 配套的 **ADR-016**；ADR-012 自身不被修改。

**唯一人类闸（不可自证）**：改 V6 默认收工配**真机截图视觉签字**（主观判据走 RiskFinding +
用户签字，不冒充机械 predicate）；UI 实现期间执行 agent 持设计自主权（用户授予，重大转向呈报）。

## 6. Atom 拆分与排序

| Atom | Lane | 交付 | 依赖 | 签字 |
|---|---|---|---|---|
| **A1_52** daemon commit 观测 | Rust + 契约增量 | `CommitObserved`（有界窗）+ fixtures | — | 机械门 |
| **A1_51a** 相机骨架 | Swift | tldraw Camera + log-zoom + floating-origin + Float32 审计 + z-band token（布局/外观不变） | — | 无（外观不变） |
| **A1_51b** 分支+commit 节点派生 + 星系/泳道布局 | Swift | BranchFact 补 A1_50 字段 + CommitFact fold；分支/commit 节点派生；星系散布+fork+泳道；诚实律不变式；golden 重生 | a, A1_52 | 视觉 |
| **A1_51c** Metal 实例化 + LOD + tile-tree + DeferredRef | Swift/Metal | MTKView 实例化 + 空间索引/视口剔除 + 簇金字塔 + LOD band + tile-tree/LayerProvider + DeferredRef leaf；**SwiftUI a11y 层保留** | b | 视觉 |
| **A1_51d** V6 美学 | Swift/Metal | 字体打包+注册、手工玻璃、多停止点星云、巨型幽灵字、星网边缘渐隐、源色贝塞尔边、三层分离 | c | 重视觉 |

序：a/A1_52（独立两 lane，谁先都行）→ b → c → d。**Metal 实例化已采纳为起点**；进一步性能
（>数万同屏图元）按需再优化，明确写阈值不静默封顶。

## 7. verified_external_facts（带溯源 + 日期）

- **无限缩放相机**：tldraw `Camera{x,y,z}`（(x,y)=视口左上 page 坐标，z=缩放，z=1→100%），
  只经 `screenToPage/pageToScreen`；缩放走 log 空间（存 logZoom，z=pow(2,logZoom)，logerp 平滑），
  范围按内容定（如 z∈[~0.01,256]）；zoom-to-cursor 闭式 `camera.x += pointer.x*(1/oldZ−1/newZ)`；
  floating-origin `screen=(world−renderOrigin)*z+offset`。**jitter 病根 = 任何 Float/Float32 进
  世界/变换数学**（Float32 ~7 位有效数字、超 ~8.4M 单位丢小数）；64-bit macOS 上 CGFloat 即 Double。
  来源：tldraw 源码/文档 + 浮点精度分析；workflow wf_1de05afa research:infinite-zoom。verified_on 2026-06-14。
- **海量节点 LOD**：三层缺一不可——① 空间索引视口剔除（kdbush KD-tree 静态点 / rbush R-tree 移动点
  / GameplayKit GKQuadtree）；② 预算 LOD 簇层级（Supercluster 自底向上 zoom 金字塔，
  `getClusters(bbox,zoom)` 返回有界簇+点，6M 点可交互）；③ Metal 实例化（一次
  `drawIndexedPrimitive(instanceCount:)`，Apple 样例 240k 三角/帧 60fps 几个%CPU）。阈值：
  <~500 画/帧 Canvas 够；>数千同屏 或 总图>10k–100k Metal 实例化必须；标签/文字只在最深 LOD+可见集渲。
  来源：mapbox/supercluster + Apple Metal 样例 + GameplayKit docs；workflow wf_1de05afa research:huge-graph-lod。verified_on 2026-06-14。
- **跨粒度场景模型**：可缩放场景=一棵 LOD tile-tree，照搬 OGC 3D Tiles `tileset.json`
  （tile: level/bounds/geometricError/refine:REPLACE，子 bounds⊆父→剔除 O(1)）；多源缝合用
  external-tileset 间接引用（tile content=指向另一来源子树的指针，懒加载后 re-bind）。落地：
  `LayerProvider{getTile,getChildren}`；commit tile content=`DeferredRef("chaintape",commitId)`，
  provider 未注册→getChildren 返回「无更深层」=叶子（只渲已观测），接通后同一 DeferredRef 解析成
  decision 子树。2D 布局=git commit-graph 在线泳道（row=时序拓扑排序、lane=active-branches 列表、
  空 lane 置 nil 不删防列抖、merge 横转竖），dense 交叉回退 Sugiyama。
  来源：OGC 3D Tiles spec + pvigier git-graph 系列；workflow wf_1de05afa research:granularity-model。verified_on 2026-06-14。
- **V6 字体**：运行时注册最稳——`Package.swift` executableTarget `resources:[.copy("Resources/Fonts")]`
  → 产出 `TuringOS_TuringOS.bundle`（PackageName_TargetName）；`build_app.sh` 建
  `Contents/Resources` 后 `cp -R` 它进去（实证：放别处则首次 `Bundle.module` 访问崩
  'unable to find bundle'）；`TuringOSApp.init()` 内 `CTFontManagerRegisterFontsForURL(.process)`
  遍历 `Bundle.module` 的 Fonts/（**view 创建前**，否则 SwiftUI 静默回退系统字且永不重试）；
  `Font.custom` 用 family 名（'Inter'/'JetBrains Mono'，非文件名）；用静态分重 .ttf；fc-scan 核名；
  本机 PATH 的 swift 坏、必须 xcrun+DEVELOPER_DIR=Xcode-beta（build_app.sh 已设）。
  来源：workflow wf_ebac4b99-036 research:fonts（本机 macOS27/Swift6.4 实证 + nilcoalescing.com + christiantietze.de + Apple InfoPlistKeyReference）。verified_on 2026-06-14。
- **V6 深色玻璃**：SwiftUI 同窗内无法真模糊一个 SwiftUI Canvas 兄弟层（.ultraThinMaterial 近黑底
  发白；NSVisualEffectView .withinWindow 看不见 SwiftUI 兄弟=空白板，Apple Forums 711559）。
  忠实做法=手工配方：`RoundedRectangle` 填 `Color(.sRGB,0.059,0.059,0.078,opacity:0.5)`
  + `strokeBorder(.white.opacity(0.05),1)` + `.shadow(.black.opacity(0.5),radius:30,y:20)`
  + 顶边 linear-gradient(.white.opacity(0.12)→clear) overlay 拟 inset 辉光 + cornerRadius 16
  + 顶部 currentColor glow-line。要真 backdrop-blur 则另渲预模糊星场副本 clip 到卡形垫底。
  macOS26 `glassEffect()` 深底发白 beta bug，不可靠。
  来源：workflow wf_ebac4b99-036 research:dark-glass（Apple Forums 711559/790260 + NSVisualEffectView docs + onmyway133）。verified_on 2026-06-14。
- **V6 柔星云/性能**：**绝不 animate `.blur`**（macOS 动画 blur ~50% CPU；静态一次性 blur 才安全）。
  柔星云=多停止点(8-13)缓出径向渐变拟 150px 模糊、零 blur pass、Canvas 内
  `context.fill(.radialGradient(Gradient(stops:)))`；2 停止点会带状硬盘化。幽灵巨字=静态
  `Text(.white.opacity(0.03))`（+一次性 .blur 可选）。静态层（星云+幽灵字）必须与动画星场分离，
  否则每帧重栅化。`TimelineView(minimumInterval)` 限频。
  来源：workflow wf_ebac4b99-036 research:nebula-blur（OskarGroth/AuroraView + swiftui-lab + css-tricks easing-gradients + Apple GraphicsContext docs）。verified_on 2026-06-14。

## 8. 待决 / 未来

- **A1_53**：sound merged-green（内容/树级核验或人工确认信号）——廉价 gh ancestry/PR 信号无法
  sound 证明 merged-and-live（`reference_github_merged_detection_unsound`；A1_50 对抗复核实证）。
- **P5+ ChainTapeProvider**：decision 子树接入（runtime ChainTape replay 经接口/CLI-ABI），
  经现有 DeferredRef 缝缝入，零重设计。
- **Metal 性能上限**：当前实例化够用；总图 >数万同屏图元再做边捆绑/更激进 LOD（写明阈值）。
- **tile-tree/LayerProvider 提契约**：暂为内部 app 结构；若 ChainTapeProvider 需跨进程边界
  （P5+）再提 `contracts/*.schema.json`（避免过早契约锁）。
