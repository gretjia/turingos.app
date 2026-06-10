# R1_memo — Worktree Radar V0（只读）研究备忘

> R-stage 研究备忘。Phase 1 授权范围：只读 Worktree Radar。所有外部事实均带 source URL + verified 日期（2026-06-10）。
> **方法学说明**：git-scm.com、developer.apple.com、docs.rs 对调研环境的 WebFetch 返回 403/JS 空壳。因此 git 行为均以**本机 git 2.43.0 实测输出**为第一手权威证据（实测 = 真值，比文档更硬），文档语义以 git 官方仓库 raw 源文件（`Documentation/*.txt`，与 git-scm.com 同源）佐证；Apple/Rust 事实以官方仓库 raw 源、GitHub code search 命中实际源码、及 xcodereleases / actions runner-images 权威清单佐证。无法核验项显式标 **UNVERIFIED**。

---

## 1. git worktree 机制

### 1.1 `git worktree list --porcelain` 字段与顺序

**结论 — 每个属性一行；属性顺序固定为 `worktree <path>` → `HEAD <oid>` → `branch <ref>` | `detached` | `bare`，可选追加 `locked [reason]` / `prunable [reason]`；条目之间以空行分隔（newline 模式）；`-z` 模式改为 NUL 终止且条目间无空行。** — 实测本机 git 2.43.0 输出（authoritative，verified 2026-06-10）；语义佐证 https://raw.githubusercontent.com/git/git/v2.43.0/Documentation/git-worktree.txt (verified 2026-06-10)。

实测三种条目（main / detached / branch，输出按 main-first 后字典序排列）：

```
worktree /tmp/.../origin
HEAD 70d564f9dc4f44cf84a6a84bc2ce22424ff1c29c
branch refs/heads/main
                                  <- 空行分隔
worktree /tmp/.../wt-detached
HEAD 70d564f9dc4f44cf84a6a84bc2ce22424ff1c29c
detached                          <- detached HEAD：无 branch 行，单独一行 "detached"

worktree /tmp/.../wt-feature
HEAD 70d564f9dc4f44cf84a6a84bc2ce22424ff1c29c
branch refs/heads/feature
```

**结论 — 文档原文：「The porcelain format has a line per attribute. … If `-z` is given then the lines are terminated with NUL rather than a newline.」** — 同上 raw 文档 (verified 2026-06-10)。

**Radar 解析要点**：必须用 newline-block 解析（空行=分隔符）；若 path 可能含换行须用 `--porcelain -z`（NUL 分隔，已实测 NUL 字节存在）。`bare` 行只在裸仓主条目出现（本次未造裸仓，UNVERIFIED 具体行文，文档列其为属性之一）。

### 1.2 locked / prunable 状态

**结论 — `locked` 表示该 worktree 的 admin 文件被保护、不会被自动 prune，也不能被 move/delete；porcelain 中表现为单独 `locked` 行，若有原因则 `locked <reason>`。`prunable` 表示该条目可被 `git worktree prune` 清理（通常因 admin 元数据指向不存在的位置），porcelain 中为 `prunable <reason>` 行。** — 同上 raw 文档 (verified 2026-06-10)。原文：「lock it to prevent its administrative files from being pruned automatically. This also prevents it from being moved or deleted.」

**实测细节**：`git worktree lock --reason "testing lock"` 后，admin 目录下生成 `locked` 文件，内容即 reason 文本。— 本机实测（verified 2026-06-10）。
> 提取时应按 `worktree` 路径行定位整块再找 `locked`/`prunable`，不要假设固定行号。

### 1.3 git 是否阻止同一分支被两个 worktree 检出

**结论 — 是。默认 `add` 拒绝；实测精确错误：`fatal: '<branch>' is already used by worktree at '<path>'`，退出码 128。** — 本机实测（verified 2026-06-10）；文档佐证同上 raw（verified 2026-06-10）。

**结论 — `--force` 覆盖该保护，实测成功检出第二个同分支 worktree（退出 0）。** — 本机实测（verified 2026-06-10）。
> 双 `--force`（同时绕过 locked worktree）语义来自文档，标 **partially-UNVERIFIED**（实测仅覆盖同分支单 force 路径）。

**Radar 含义**：理论上「两个 worktree 同分支」不该出现；但 `--force` 能造成，Radar 必须**容忍并显式标注**该异常（见 §2.e）。

### 1.4 detached HEAD 添加

**结论 — `git worktree add --detach <path> <commit>` 创建无分支 worktree；porcelain 中 = `HEAD <oid>` 行 + 单独 `detached` 行、无 `branch` 行。** — 本机实测（verified 2026-06-10）。

### 1.5 admin 文件位置与 gitdir 文件内容

**结论 — 每个 linked worktree 的私有 admin 目录位于 `$GIT_DIR/worktrees/<id>/`；实测含：`HEAD ORIG_HEAD commondir gitdir index logs/`（lock 后多 `locked`）。** — 本机实测（verified 2026-06-10）。

**结论 — 双向指针实测**：工作目录内 `.git` **文件**内容 `gitdir: /…/.git/worktrees/wt-feature`（指向 admin 目录）；admin 目录内 `gitdir` 文件内容为工作树 `.git` 文件的绝对路径（反指）；admin `HEAD` 内容 `ref: refs/heads/feature`。— 本机实测（verified 2026-06-10）。

**结论 — 手动移动 linked worktree 后须更新 `gitdir` 或用 `git worktree repair`。** — 同上 raw 文档（verified 2026-06-10）。
> Radar 只读策略：**只读 `gitdir`/`commondir`/`HEAD` 文本定位与判活，绝不写**。`gitdir` 指向的工作树不存在 → 视作 prunable（与 git 语义一致）。

---

## 2. 只读 Radar 的六个边界条件

### 2.a symlink / 路径穿越（canonicalize）

**结论 — Swift 两个相关 API：`URL.resolvingSymlinksInPath`（解析符号链接+标准化）与 `URL.standardizedFileURL`（仅 `.`/`..` 语法标准化，不解析 symlink）。** — https://developer.apple.com/documentation/foundation/url/resolvingsymlinksinpath 与 https://developer.apple.com/documentation/foundation/url/2293229-standardizedfileurl（搜索摘要核验，verified 2026-06-10）。

**结论 — macOS 关键陷阱：`/tmp`→`/private/tmp`、`/var`→`/private/var` 是符号链接；同一路径经不同 API 解析可能得到两个字符串，做相等/包含判断会误判。比较前一律 canonical 到真实路径。** — 现实案例 https://github.com/modelcontextprotocol/servers/issues/3253 等（verified 2026-06-10）。
> `URL.resolvingSymlinksInPath` 对**不存在的路径**通常原样返回，行为不保证等同 POSIX `realpath`；安全敏感的「是否在授权根内」判定建议经 C 桥接 `realpath(3)` 硬解析。— 标 **partially-UNVERIFIED**（未在 Linux 环境实测 macOS 行为）。

**Radar 含义**：①授权根目录登记时 canonical 一次并缓存；②每个 worktree path canonical 后再与授权根做前缀比较，防 symlink 逃逸。

### 2.b submodules

**结论 — submodule 不作为独立条目出现在 `git worktree list`（实测）。** — 本机实测（verified 2026-06-10）。

**结论 — `git submodule status` 行格式：`<前缀><SHA1> <path> (<describe>)`；前缀：空格=干净；`-`=未初始化；`+`=检出 commit 与父仓记录不符；`U`=合并冲突。** — https://git-scm.com/docs/git-submodule（搜索摘要核验）+ 本机实测干净态（verified 2026-06-10）。

**结论 — `git status --porcelain=v2` 用 `<sub>` 字段 `S<c><m><u>` 报告 submodule：实测修改时输出 `1 .M S.M. 160000 160000 160000 <sha> <sha> sub`（mode `160000` = gitlink）。** — 本机实测 + https://raw.githubusercontent.com/git/git/v2.43.0/Documentation/git-status.txt（verified 2026-06-10）。

**只读处理建议**：不下钻 submodule 内部；仅用父仓 porcelain v2 的 `S<c><m><u>` 标志位显示「子模块脏/版本漂移」，零写入、零递归 fetch。

### 2.c git-lfs / 大二进制

**结论 — LFS pointer 是小文本：`version` 永远第一行，其余键字典序；`oid sha256:<hex>`、`size <bytes>`。** — https://raw.githubusercontent.com/git-lfs/git-lfs/main/docs/spec.md（verified 2026-06-10）。

**结论 — diff 指纹实测：真二进制 `--numstat` 给 `-\t-\t<path>`、`--stat` 给 `Bin 0 -> N bytes`；LFS pointer 是 3 行普通文本（`--numstat` 给 `3\t0`）。**识别 LFS 不能靠 numstat，要靠首行嗅探或 `.gitattributes` 的 `filter=lfs`。** — 本机实测（verified 2026-06-10）。

**结论 — `core.bigFileThreshold` 默认未设置（实测）；默认值 512 MiB 来自 git config 文档。** — 标 partially-UNVERIFIED（数字未直连核字）。

**防 UI 卡死策略**：①总览一律 `git diff --numstat -z`（不拉全文）；②摘要用 `--shortstat`；③单文件渲染字节上限，超限只显示 `Bin N bytes`/LFS 摘要；④diff 调用带超时 + 后台线程。

### 2.d 未跟踪文件

**结论 — porcelain v2 前缀：`1`=普通变更、`2`=改名/复制、`u`=冲突、`?`=未跟踪、`!`=忽略；普通行 `1 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <path>`。** — raw git-status.txt + 本机实测 `1 AM N... ... a.txt` 与 `? new.txt`（verified 2026-06-10）。

**结论 — `--branch` 头：`# branch.oid`、`# branch.head <branch>|(detached)`、`# branch.upstream`、`# branch.ab +A -B`；实测 detached 时 `# branch.head (detached)`。** — 同上（verified 2026-06-10）。

**结论 — `-z` 模式路径原样无引号、NUL 终止（实测 od -c 确认）。非 `-z` 模式特殊字符 path 会被加引号转义——Radar 解析务必 `--porcelain=v2 -z`。** — 同上（verified 2026-06-10）。

**结论 — 枚举成本：`normal` 在大树「may take some time」；`all` 更贵；`no` 最快但丢 untracked；`core.untrackedCache=true` 可降本。** — raw git-status.txt（verified 2026-06-10）。
**tradeoff 建议**：V0 默认 `normal`；提供「大仓性能模式」（`-uno` 或开 untrackedCache）；ignored 默认不枚举。

### 2.e 分支身份 / 同分支双 worktree 检测

**结论 — detached 的两种机器表示已实测（§1.4、§2.d）。检测同分支冲突：对 worktree list 的 `branch refs/heads/<X>` 分组，同名 ≥2 即异常——正常 git 不允许但 `--force`/外部工具可造成，Radar 必须主动检测并醒目标注。** — 推断自 §1.3 实测（verified 2026-06-10）。detached 条目无 branch 不参与该判定。

### 2.f FSEvents（API 面选型确认）

**结论 — 递归目录监听正解是 FSEvents（`FSEventStreamCreate`），而非 DispatchSource(vnode)（单 fd、不递归）或 NSFilePresenter（文档协调器，不是高频监听工具）。** — https://developer.apple.com/documentation/coreservices/1443980-fseventstreamcreate、https://developer.apple.com/documentation/dispatch/dispatch_source_type_vnode（verified 2026-06-10）。

**结论 — FSEvents 是 best-effort + 目录粒度 coalesced；`latency` 控制合并窗口；`kFSEventStreamCreateFlagFileEvents` 可拿文件级路径。** — Apple FSEvents Programming Guide（verified 2026-06-10）。
> 与 R0 一致：FSEvents 当**脏信号**，去抖后触发一次 git 只读快照重算，绝不逐事件做重活。监听路径登记前先 canonical（呼应 §2.a，历史 realpath bug 背景 https://github.com/andreyvit/FSEventsFix）。

---

## 3. Stable 构建车道事实

**结论 — 当前最新 STABLE Xcode = 26.5（2026-05-11），bundled Swift = 6.3.2。映射：26.0–26.3→Swift 6.2；26.4→6.3；26.4.1→6.3.1；26.5→6.3.2。** — https://xcodereleases.com/（verified 2026-06-10）。

**结论 — `MenuBarExtra` SwiftUI scene 最低部署目标 = macOS 13.0+，macOS-only。** — https://developer.apple.com/documentation/swiftui/menubarextra（verified 2026-06-10）。

**结论 — Liquid Glass 于 macOS 26 引入；macOS 27 是精修（统一圆角、可读性调整），大多 **SDK 重编自动生效**，非必须调用的新 API。** — https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass 等（verified 2026-06-10）。

**部署目标建议**：**deployment target = macOS 26**——全量 Liquid Glass 能力、覆盖 26+27 两代；27 无值得抬高下限的 hard API delta（标 judgement/monitor，27.x 复核）；不下探 13（产品前提是 Software 3.0 原生 + P2 需现代 SE/CryptoKit 栈，目标用户为前沿采用者）。

---

## 4. GitHub Actions macOS runner

**结论 — 可用镜像：`macos-26`（arm64，2026-02-26 GA）与 `macos-15`（arm64）；`macos-latest` 自 2026-06 指向 `macos-26`。** — https://github.blog/changelog/2026-02-26-macos-26-is-now-generally-available-for-github-hosted-runners/（verified 2026-06-10）。

**结论 — `macos-26-arm64` 镜像：macOS 26.4 (25E246)；预装 Xcode 26.5 / 26.4.1(default) / 26.3 / 26.2 / 26.1.1 / 26.0.1。** — https://raw.githubusercontent.com/actions/runner-images/main/images/macos/macos-26-arm64-Readme.md（verified 2026-06-10，raw 直读成功）。

**CI 车道建议**：`runs-on: macos-26` 主 lane；钉死 Xcode 用 `sudo xcode-select -s /Applications/Xcode_26.5.app`。镜像 Readme 未列 Swift 版本字符串（标 UNVERIFIED-via-readme），由映射推定 26.5→6.3.2。

---

## 5. Rust daemon（Linux-first 开发）

**结论 — git2 crate 支持 worktree 枚举：`Repository::worktrees() -> StringArray`、`find_worktree(name)`；`git2::Worktree` 提供 `name/path/validate/is_locked/is_prunable`（只读全套）。** — GitHub code search 命中 `rust-lang/git2-rs/src/repo.rs` + https://raw.githubusercontent.com/rust-lang/git2-rs/master/src/worktree.rs（verified 2026-06-10）。`validate()` 可替代手工判 §1.5 的 gitdir 死链。

**结论 — UDS peer credential 跨平台：Rust std `UCred` 分平台实现（Linux `SO_PEERCRED` / BSD `getpeereid` / Apple 专有 impl）；macOS `xucred` 只可靠给 uid/gid，**pid 需 `LOCAL_PEERPID` 单独取**。** — https://github.com/rust-lang/rust/issues/42839 + std 源（verified 2026-06-10）。

**Linux 容器测试策略**：peer-cred 认证逻辑抽象成 trait——Linux 容器覆盖 uid/gid 路径；macOS 专有 pid 取法以 `#[cfg(target_os="macos")]` 隔离，列为 macOS CI 实测项。
> **UNVERIFIED**：macOS `LOCAL_PEERCRED` pid 可得性与 `LOCAL_PEERPID` 确切语义——P1 在 macos-26 CI 实测后补录。

---

## UNVERIFIED 待补清单（P1 期间在 macOS CI 实测后逐项替换）

1. 双 `--force` 绕过 locked worktree 的 add（§1.3）
2. `URL.resolvingSymlinksInPath` 对不存在路径的行为 vs POSIX realpath（§2.a）
3. `core.bigFileThreshold` 默认 512 MiB 文档原文（§2.c）
4. macOS 27 是否存在 Radar 必需 hard API delta（§3，judgement/monitor）
5. runner 镜像内 Swift 版本字符串（§4）
6. ~~macOS UDS peer-cred pid 可得性（§5，最优先）~~ **已销项（2026-06-10，A1_03）**：
   tokio `UnixStream::peer_cred()` 在 macOS 真实 socket 上 uid/gid/pid 全可得
   （`daemon/tests/uds_subscription.rs::uds_peer_cred_uid_and_pid` 本机实测 PASS，
   cfg 断言同时覆盖 linux/macos，macos-26 CI rust lane 持续复证）
7. ~~notify crate FSEvents backend 能力（§2.f / 设计简报 D4 风险登记）~~
   **已销项（2026-06-10，A1_04）**：`notify` v8.2 RecommendedWatcher 在 macOS
   （FSEvents backend）对真实文件写入递归送达事件，自实现 800ms 级去抖聚合正常
   （`daemon/src/watch.rs::tests` watch_real_fs_event_arrives /
   watch_debounce_coalesces_bursts 本机实测 PASS；Linux inotify 路径由 CI 复证）。
   降级路径保留：watcher 建立失败 → 可见 stderr + 纯周期对账，契约不变
