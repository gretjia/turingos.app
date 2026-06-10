---
atom: A1_07_onboarding_connect_select
phase: "1"
intent: >
  Onboard 三段式的 Connect+Select（四次裁决）：三级降档接入（gh CLI 登录态复用 →
  GitHub OAuth Device Flow → 纯本地模式，每级 fail-visible 不静默）；repo 清单 =
  GitHub /user/repos + 本地发现（remote URL 归一化去重，SSH/HTTPS 同仓识别）；
  用户勾选纳管 = RegisterProject(L1) 批量写注册表（A1_06 格式）；无本地 clone 的勾选项
  落注册表为 remote-only。token 只进 Keychain，永不入 tape/事件流/日志/回执。
allowlist:
  - "app/**"
  - "research/R1_auth_memo.md"
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
