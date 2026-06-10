---
atom: A1_07_onboarding_connect_select
phase: "1"
intent: >
  Onboard（四次裁决三段式 × 五次裁决每屏一个决定）：Connect 屏 = 一个按钮 + 一句话
  状态（自动探测 gh 登录态；降档逐级可见）；Select 屏 = 单列表每 repo 一行（名字 +
  一句话近况）勾选即注册（写 A1_06 注册表格式）+ 拉起/连接 registry 模式 daemon；
  完成落 Home。repo 清单 = GitHub /user/repos（经 gh token）+ 本地约定目录发现
  （remote URL 归一化去重，SSH/HTTPS 同仓识别）；无本地 clone 的勾选项落 remote-only。
  token 只进 Keychain，永不入 tape/事件流/日志/回执。
  **范围裁决**：OAuth Device Flow 需要先在 GitHub 创建 OAuth App 取得 client_id
  （用户动作）——本卡实现 gh 复用 + 纯本地两级，Device Flow 入口以"待配置"可见态占位，
  client_id 供给列为停机磋商项。
allowlist:
  - "app/**"
  - "research/R1_auth_memo.md"
  # 2026-06-10 修订留痕：法证测试下限 MIN_TESTS 必须随真实测试数增长（11→24），
  # 该常量在 build_app.sh —— 扩入 allowlist 而非绕过（M5）。
  - "scripts/build_app.sh"
  # 2026-06-10 二次留痕：S-stage blocker「socket 偷窃/裂脑」的正确修复点在
  # daemon bind_socket（活性探测后才 unlink）——内核侧防线是本 atom 拉起 daemon
  # 行为的直接对偶，扩入 allowlist（M5）。
  - "daemon/**"
max_new_files: 12
predicates:
  - "bash scripts/build_app.sh"
  - "bash scripts/shipgate.sh p1"
verified_external_facts:
  - fact: "三级降档的端点/参数/存储事实以 research/R1_auth_memo.md 为准（后台调研产出，入卡前逐条核 verified_on；UNVERIFIED 项本卡实测销项）"
    source: "research/R1_auth_memo.md"
    verified_on: "2026-06-10"
ux_touchpoints: >
  Onboard 时刻（DESIGN.md）：fail-closed 以可理解方式呈现——每级降档显式说明
  「为什么落到这一级 + 如何升级」；Select 列表压缩展示 repo 元数据；勾选后直达
  Global Workspace 压缩态。auth 状态徽章用语义色（连接成功≠verified 绿，用 blue active）。
gate: "bash scripts/shipgate.sh p1"
---

# 代码思路

AuthService actor：detect gh（`gh auth token` 子进程，exit≠0 即降级）→ Device Flow
（URLSession 轮询，slow_down/authorization_pending 错误码状态机）→ local-only；
KeychainTokenStore（kSecClassGenericPassword）；RepoCatalog：GitHub 分页拉取 +
本地 mdfind/目录扫描发现 .git 主仓（worktree 链接仓去重）+ remote URL 归一化
（git@github.com:a/b.git ≡ https://github.com/a/b）；SelectView 勾选 → registry 写入。
单测：归一化表驱动；Device Flow 状态机 mock URLProtocol；Keychain 往返。

## 开工实测补录（2026-06-10 本机，销 R1_auth_memo §6 部分项）

- gh 2.92.0 @ /opt/homebrew/bin/gh；`gh auth token` 登录态：exit 0 + 单行 40 字符 token（§6.2 登录半边销项；登出半边不实测——不打扰用户登录态，代码用 exit≠0 OR stdout 空 双判据兜底）。
- `gh auth status --json hosts` 真实 schema：`hosts.{host}[] = {state,active,host,login,tokenSource,scopes,gitProtocol}`，scopes 为逗号+空格分隔字符串（§6.3 销项）。
- 约定目录扫描（~/Developer ~/Projects ~/src ~/code ~/workspace，maxdepth 4）实测 25ms 命中 4 仓（§6.8 销项：约定目录策略成立，无需全 home find）。
- `GET /user/repos` 字段形状实测确认：full_name/private/pushed_at/clone_url/ssh_url（经 gh api 一页探针）。
- **不实测项**（避免无人值守干扰）：keychain ACL 直读（可能弹对话框，且已被红线否决）、gh 登出路径（会破坏用户登录态）。
- **安全裁决**：gh 路径的 token 永不持久化（不进我们的 Keychain）——每次启动经 `gh auth token` 重取，比 memo 的 Keychain 方案更小暴露面；Keychain 仅留给未来 Device Flow 自有 token。

## S-stage 评审裁决落地（2026-06-11 留痕）

- ① [blocker] app 退出后 daemon 孤儿（Darwin 子进程不随父死，原注释为假）→
  DaemonController 注册 willTerminateNotification 同步 terminate 子进程，注释改为真话；
- ② [blocker] socket 偷窃/裂脑 → 双侧防线：app 端 socketIsLive 探测先「收养」现有
  daemon；daemon 端 bind_socket 改 **flock 锁文件证人**——首版 connect-probe 被真题否决
  （Darwin 上 connect 到刚关闭监听者的 socket 会瞬时成功，全量并发跑实测翻车），flock
  由内核保证与持有进程同生死、零竞态窗口；回归 uds_bind_refuses_live_socket_but_clears_stale；
- ③ [risk] token 进 @Published 反射面 → ConnectLevel 去 token 化（ConnectResult 分离
  携带），token 只活在 detached task 局部直至喂给 listAllRepos；
- ④ [risk] 30 页上限静默截断 → listAllRepos 返回 truncated 标志，Select 句子可见声明；
- ⑤ [risk] symlink 致扫描放大/重复发现 → 扫描永不跟随 symlink 目录，回归（祖先环）；
- ⑥ [risk] 同 remote 双 clone 被 merge 覆盖丢行 + id 碰撞 → 每个 clone 独立行，
  id 含本地路径，回归 testMergeKeepsEveryCloneOfOneRemote；
- ⑦ [info] runConnect 模型级重入卫；isPrivate 死字段删除（反模式：可得≠应展示）；
  sanitize 注释改为如实（与 Rust 在组合字符上非字节同构，无害）；
- ⑧ veto RiskFinding（两处注释 over-claim）→ 以「把注释变成真话」方式修复：registry
  耦合探针真正入 gate（build_app.sh：--onboard-probe 写出 → daemon --registry 加载 →
  断言 ProjectRegistered 指向同一 canonical 路径）；
- ⑨ 五问补登（NAVIGATION_MODEL 法务）：Onboarding=导航前一次性门面。①来看什么=
  接入状态与可看管清单 ②typed actions=RegisterProject(L1) 语义的批量注册（写注册表）
  ③投影=catalog 全部为派生展示 ④签名=无（L0 探测+L1 本地写）⑤inferred=remote-only
  行直至 daemon 对账。
- **停机磋商项（按用户指示）**：GitHub OAuth Device Flow 需要用户在 GitHub 创建
  OAuth App 取得 client_id（Settings→Developer settings→OAuth Apps，启用 Device Flow）。
  当前 gh 复用 + 纯本地两级已全功能；client_id 到位后 Device Flow 即可按 memo §3
  端点实现。
