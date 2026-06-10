# R1_auth_memo — Onboarding/Auth 接入调研备忘（P1 补充 memo，A1_07 引用源）

> R-stage 研究备忘。范围：macOS 原生 App 的 GitHub 身份接入（onboarding/auth atom 卡引用源）。所有外部事实带 source URL + verified 日期（2026-06-10）。
> **方法学说明**：以下结论来自三份独立调研收敛。WebFetch 一手页可达者已标注；凡**未在本机实测/未直连一手页核验**的语义，显式标 **UNVERIFIED** 并附实测方法。与裁决相关项给出明确推荐 + 被否方案及理由。
> **与 P1 一致的纪律**：auth 只读探测，零写入第三方 keychain item；fail-visible 不静默。

---

## 1. 推荐的接入梯队（裁决建议）

**裁决 — 三级检测梯队，逐级降级且每次降级必须 fail-visible（可见 stderr/UI 状态，绝不静默跳过）。** 设计依据见各级触发条件与红线。

```
L-gh   gh CLI 复用（零 secret、零 keychain 权限）
  │   触发：command -v gh 命中 且 `gh auth token` exit 0 且 stdout 非空
  │   降级 → 显式提示「未发现 gh 登录态」后进 L-oauth
  ▼
L-oauth OAuth Device Flow（无 server、无 client_secret）
  │   触发：用户选择联网授权；申请 device_code 成功
  │   降级 → expired_token/access_denied/网络不可达 → 可见错误 + 回到入口，可重试或进 L-local
  ▼
L-local 纯本地模式（只读 repo 发现，不取 token）
      触发：用户拒绝联网 或 离线
      能力域：本地 repo 枚举 + remote 归一化得 OWNER；不调 GitHub API、不显示需鉴权的字段
```

**裁决理由（被否方案 + 理由）：**

- **被否：直接 `security find-generic-password` 读 gh 的 keychain item 作为首选。** 理由 — gh 写入的 keychain item ACL 默认限于 gh 自身，第三方 app 触发读取会被 Keychain ACL 拒绝（或弹用户授权框，非静默）。这是最重要的可行性红线，不能作为稳定路径。改用 `gh auth token` 子进程（gh 自己持有 ACL，我们只读其 stdout）。
- **被否：ASWebAuthenticationSession 作为联网授权主路径。** 理由 — code 换 token 阶段必须传 `client_secret`，而无 server 的客户端 app 无法安全内嵌 secret（可被反编译），且沙箱 macOS 下 ASWebAuthenticationSession 有已知无法呈现 UI 的问题。Device Flow 设计上不需要 secret，是无 server 场景的官方正解。
- **被否：直接解析 `~/.config/gh/hosts.yml` 作为 L-gh 实现。** 理由 — 对 keychain-backend 登录（macOS 默认）或 SSH protocol 登录，hosts.yml 中**不含** `oauth_token`，会拿到空结果；且绑定 gh 内部文件格式，迁移即静默失效。仅作 L-gh 内的末位 fallback，不作首选。

**梯队的 fail-visible 纪律**：每级降级写一条结构化原因（如 `gh_not_found` / `gh_logged_out` / `device_flow_access_denied` / `user_offline`），UI 显示当前所处级别与降级原因。符合 MANIFESTO 报忧义务与 §3 谓词纪律。

---

## 2. gh CLI 复用 — verified facts

**结论 — `gh auth token [--hostname <host>] [--user <user>]` 输出单行 token 到 stdout，无多余格式，是一级公开接口（文档收录、未标实验性）。** — https://cli.github.com/manual/gh_auth_token (verified 2026-06-10)

**结论 — `gh auth token` 的设计意图就是替代难解析的 `gh auth status` 人读输出（issue #4865 → #5227 已 closed），脚本惯例 `TOKEN=$(gh auth token)` 为官方/社区认可。** — https://github.com/cli/cli/issues/5227, https://github.com/cli/cli/issues/4865 (verified 2026-06-10)

**结论 — 未登录时 `gh auth token` 输出空字符串且 exit 非零；探测应同时检查 exit code 与 stdout 是否为空（早期版本 exit code 有历史 bug，v2.42.1 后 `gh auth status` 修复）。** — 同上 issue 串 (verified 2026-06-10)

**结论 — `gh auth token` 命令在 gh ≥ 2.19.0 引入；版本门控建议 `gh --version` ≥ 2.19.0。** — UNVERIFIED（引入版本号未直连 changelog 核验，见 §6.1）

**结论 — scope 检查首选 `gh auth status --json hosts`（PR #11544 已合并加 `--json`）；`scopes` 为逗号分隔字符串，`token` 字段默认隐藏需 `--show-token`；`--json` 模式除 fatal error 外恒 exit 0，适合脚本解析。** — https://github.com/cli/cli/pull/11544 (verified 2026-06-10)

**结论 — scope 检查备选：任意 GitHub API 调用返回 `X-OAuth-Scopes` 响应头（`gh api user -i 2>&1 | grep -i x-oauth-scopes`），同时验证 token 有效 + 网络可达。** — 调研1 综合（verified 2026-06-10，依据 GitHub API header 行为）

**结论 — 环境变量优先级（github.com / `*.ghe.com`）：`GH_TOKEN` > `GITHUB_TOKEN` > 存储凭证；任一存在即完全覆盖存储凭证（不 merge）。GHES 自托管为 `GH_ENTERPRISE_TOKEN` > `GITHUB_ENTERPRISE_TOKEN` > `GH_TOKEN` > `GITHUB_TOKEN`。** — https://cli.github.com/manual/gh_help_environment (verified 2026-06-10)

**结论 — macOS app 进程若继承父进程 `GH_TOKEN`/`GITHUB_TOKEN`（如从 CI 环境启动），会覆盖用户 gh 登录态；探测前需考虑此污染并按梯队优先消费环境变量或显式标注来源。** — 同上 (verified 2026-06-10)

**结论 — gh 凭证 macOS 默认优先写 Keychain（generic password，服务名 `gh:github.com`），除非 `--insecure-storage` 或无 keyring；gh 会写两条 entry（一条带用户名、一条 account 为空作活跃槽指针），`security find-generic-password` 可能歧义。** — https://github.com/cli/cli/issues/12953, https://github.com/cli/cli/issues/13330 (verified 2026-06-10)

**结论 — 红线：第三方 app 直接 `security find-generic-password` 读 gh 的 keychain item 会被 Keychain ACL 拒绝（gh item 的 access group 限于 gh 自身）；服务名 `gh:github.com` 官方文档未公开承诺，属黑盒依赖。** — issue #12953/#13330 + 调研1 综合 (verified 2026-06-10) → **故 L-gh 必走 `gh auth token` 子进程，不读 keychain。**

**结论 — gh 探测与 PATH：App Sandbox/继承环境下子进程 PATH 极窄，需显式探测 `/opt/homebrew/bin`(Apple Silicon)、`/usr/local/bin`(Intel)、`~/.local/bin`；`command -v gh` 或绝对路径启动。** — 调研1 综合 + Homebrew 默认路径事实 (verified 2026-06-10)

---

## 3. OAuth Device Flow — verified facts

**结论 — Device Flow 端点序列：① `POST https://github.com/login/device/code`（Accept: application/json）申请设备码；② `POST https://github.com/login/oauth/access_token` 轮询令牌。两端点 OAuth App 与 GitHub App 完全一致。** — https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#device-flow (verified 2026-06-10)

**结论 — 申请设备码请求参数：`client_id`（必填）、`scope`（可选，空格分隔）。响应字段：`device_code`(40字符,轮询用不展示)、`user_code`(8字符含连字符,展示给用户)、`verification_uri`(用户去 `https://github.com/login/device` 输入)、`expires_in`(默认 900 秒/15 分钟)、`interval`(轮询最短间隔,通常 5 秒)。** — 同上 (verified 2026-06-10)

**结论 — 轮询请求参数：`client_id`、`device_code`、`grant_type` 固定值 `urn:ietf:params:oauth:grant-type:device_code`；Device Flow 不需要 `client_secret`（官方明文）。** — 同上 (verified 2026-06-10)

**结论 — 成功响应：`access_token`（OAuth App 无前缀；GitHub App 用户令牌前缀 `ghu_`，刷新令牌 `ghr_`）、`token_type: bearer`、`scope`(实际授权)。** — https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app#using-the-device-flow-to-generate-a-user-access-token (verified 2026-06-10)

**结论 — 轮询错误码处理：`authorization_pending`(继续按 interval 轮询)、`slow_down`(interval+5 秒后继续)、`expired_token`(15 分钟到期,重新申请设备码)、`access_denied`(用户取消,终止)、`unsupported_grant_type`/`incorrect_client_credentials`/`incorrect_device_code`/`device_flow_disabled`(均为配置/代码错误,修复)。** — https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#device-flow (verified 2026-06-10)

**结论 — 轮询限额：每应用每小时最多 50 次用户验证码提交。** — 同上 (verified 2026-06-10)

**结论 — OAuth App vs GitHub App 选型：OAuth App = 粗粒度 scope(`repo`=全仓读写)、令牌永久、用户直接授权、最低复杂度；GitHub App = 细粒度权限(最小权限)、用户令牌默认 1h 过期(需 refresh)、需先安装 App 步骤；GitHub 官方推荐优先 GitHub App。两者 Device Flow 端点一致,迁移成本低。** — https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/differences-between-github-apps-and-oauth-apps (verified 2026-06-10)

> **裁决建议（选型）**：onboarding 首版若仅需「列出用户自己的 repos」，**推荐 OAuth App + Device Flow**（最低复杂度、令牌永久免 refresh 逻辑）。被否方案 GitHub App 的细粒度权限/1h refresh 复杂度在单用户只读场景不偿付；但端点一致，留迁移口。最终 scope/选型在 onboarding atom 卡 `verified_external_facts` 钉死。

**结论 — 列出全部 repos：`GET https://api.github.com/user/repos`，`Authorization: Bearer <token>`；关键参数 `visibility`(all/public/private)、`affiliation`、`type`、`sort`、`per_page`(最大 100,默认 30)、`page`；分页用响应头 `Link` 的 `rel="next"` 循环至无 next。** — https://docs.github.com/en/rest/repos/repos?apiVersion=2022-11-28#list-repositories-for-the-authenticated-user (verified 2026-06-10)

**结论 — Rate Limit：已认证 5000 请求/小时；REST GET 次级限制每分钟 900 点(GET 计 1 点)；监控 `X-RateLimit-Remaining`/`X-RateLimit-Reset`。所需 scope：私有仓需 `repo`,仅公开 `public_repo`,用户信息 `read:user`。** — https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api, https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/scopes-for-oauth-apps (verified 2026-06-10)

**结论 — Token 持久化推荐 `kSecClassInternetPassword`(含 server 属性,语义优于 GenericPassword)：`kSecAttrServer="github.com"`、`kSecAttrAccount=username`、`kSecAttrLabel`、`kSecValueData=tokenData`、`kSecAttrAccessible=kSecAttrAccessibleWhenUnlockedThisDeviceOnly`(不随 iCloud 同步,OAuth token 推荐)。** — https://developer.apple.com/documentation/security/keychain-services (verified 2026-06-10)

**结论 — Keychain 操作：存 `SecItemAdd`、读 `SecItemCopyMatching`、更新 `SecItemUpdate`(刷新)、删 `SecItemDelete`(登出)；首次写若已存在返回 `errSecDuplicateItem`,需先 update 或先删后存;`kSecAttrAccessibleAlways` 禁用(不安全)。GitHub App 开启过期则同存 `refresh_token`,1h 后 `POST /login/oauth/access_token?grant_type=refresh_token` 续期。** — 同上 + GitHub App refresh 文档 (verified 2026-06-10)

**结论 — ASWebAuthenticationSession 在沙箱 macOS 有时无法呈现 UI;且 code 换 token 必须传 client_secret——无 server 客户端无法安全内嵌。故联网授权用 Device Flow 而非 ASWebAuthenticationSession。** — https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession, https://developer.apple.com/forums/thread/750051 (verified 2026-06-10)

---

## 4. 本地模式 — verified facts

**结论 — repo 发现红线：Spotlight/`mdfind` 不索引 `.` 开头的隐藏目录，`.git` 本身即隐藏目录,故 `mdfind` 找 `.git` 必然落空(macOS 设计行为非 bug);`~/.Spotlight-V100`/`.Trash`/`.DS_Store`/Privacy 排除路径/未启用 Spotlight 的外置盘同样盲。** — https://osxdaily.com/2012/07/21/hide-anything-from-spotlight-in-mac-os-x-with-the-library-folder/, https://yurisk.info/2023/03/28/mdfind-macos-examples-cheat-sheet/ (verified 2026-06-10)

**结论 — repo 发现主路径用 `find`(不依赖索引):`find /Users/<user> -maxdepth 6 -name ".git" -type d 2>/dev/null`,跳过 `-not -path "*/Library/*" -not -path "*/.Trash/*"`;优先扫约定目录 `~/Developer`/`~/Projects`/`~/src`/`~/code`/`~/workspace` 提命中率;每个候选用 `git -C <path> rev-parse --git-dir` 验证。** — 调研3 综合 (verified 2026-06-10) ｜ 与 §6 注意:与 R1 的 worktree-list 解析共用 git 调用纪律

**结论 — worktree 主仓判定:`git worktree list --porcelain` 第一条记录永远是 main worktree(linked worktree 无专属标记,仅依排序);linked worktree 的 `.git` 是 file(非目录),内容 `gitdir: /path/to/main/.git/worktrees/<name>`,可反向找主仓。** — https://git-scm.com/docs/git-worktree (verified 2026-06-10) ｜ 与 R1 §1.5 实测一致

**结论 — credential.helper 发现层级:仓库级 `.git/config` → 用户级 `~/.gitconfig`/`~/.config/git/config` → 系统级 `/etc/gitconfig`;`git -C <repo> config --list --show-origin credential.helper` 得合并值+来源,`git config --show-scope --list` 区分作用域;在 repo 目录内 `git config credential.helper` 即得生效 helper,无需解析 .git 内部。** — https://git-scm.com/docs/gitcredentials, https://git-scm.com/book/en/v2/Git-Tools-Credential-Storage (verified 2026-06-10)

**结论 — helper 调用规则:纯名称(如 `osxkeychain`)→ 执行 `git credential-osxkeychain`;绝对路径→直接执行;`!` 开头→当 shell 片段;多 helper 按文件顺序逐一尝试至同时得 username+password。** — 同上 (verified 2026-06-10)

**结论 — git-credential-osxkeychain 以 `kSecClassInternetPassword` 存储(`kSecAttrServer`=host、`kSecAttrAccount`=username、`kSecAttrProtocol`、`kSecValueData`=token);`security find-internet-password -s github.com` 可定位同一条目,`-w` 返回明文。** — https://github.com/git/git/blob/master/contrib/credential/osxkeychain/git-credential-osxkeychain.c, https://docs.github.com/en/get-started/git-basics/updating-credentials-from-the-macos-keychain (verified 2026-06-10)

**结论 — 红线(同 §2):读 git-credential-osxkeychain 条目需调用进程过 Keychain ACL 审查或用户在弹窗点「允许」;条目 ACL 限 git 时第三方触发会弹框,不可静默读取。macOS 设计为每次访问需明确同意,非一次性授权。** — Git 源码 + 调研3 伦理边界 (verified 2026-06-10) → **本地模式不读 git keychain token,只做无 token 的只读发现。**

**结论 — TCC 现实(非沙盒直发 app):Desktop/Documents/Downloads 三目录受 TCC 保护(`kTCCServiceSystemPolicy{Desktop,Documents,Downloads}Folder`),首次访问弹 per-folder 同意框,需稳定代码签名(Developer ID 或 ad-hoc)+ plist 声明 `NSDesktopFolderUsageDescription`/`NSDocumentsFolderUsageDescription`/`NSDownloadsFolderUsageDescription`(缺键=静默拒绝)。** — https://support.apple.com/guide/security/controlling-app-access-to-files-secddd1d86a6/web, https://developer.apple.com/forums/thread/663889, https://developer.apple.com/documentation/bundleresources/information-property-list/nsdesktopfolderusagedescription (verified 2026-06-10)

**结论 — 关键事实:`~/Developer`/`~/Projects` 等**非三大保护目录**的子目录,非沙盒 app 无需 TCC 同意、无弹框直接读写,仅受 UNIX DAC(文件所有者=当前用户)约束。git repo 通常不放保护目录→默认无 TCC 摩擦。NSOpenPanel(用户主动选目录)走「用户意图」路径授权,不弹标准 TCC 框、不入 Privacy 记录。** — https://eclecticlight.co/2026/04/20/privacy-how-locations-are-protected/, https://lapcatsoftware.com/articles/FullDiskAccess.html (verified 2026-06-10)

> **裁决建议(发现策略)**:repo 发现优先扫 `~/Developer` 等约定目录(无 TCC 摩擦),需扩到 Desktop/Documents/Downloads 时**推荐 NSOpenPanel 让用户选**(用户意图路径,免 TCC 弹框且语义=用户明确授权)。被否方案:全 home `find` + 提前请求 Full Disk Access——过度索权、与「最小权限+用户主权」价值观冲突。

**结论 — SSH remote 归一化:`git -C <repo> remote get-url origin` 得 URL;SSH 形态 `git@github.com:OWNER/REPO.git` 截冒号后去 `.git` 按 `/` 分割得 `[OWNER,REPO]`;HTTPS 形态 `https://github.com/OWNER/REPO.git` 解析 path 取 path[1]。得到的是账户名(org slug 或 user login)非显示名;验证 user vs org 须 `GET /users/{owner}` 或 `GET /orgs/{owner}`;多 remote 时取 `origin` 为主或枚举过滤 github.com。** — https://docs.github.com/en/get-started/git-basics/about-remote-repositories, https://docs.github.com/en/get-started/git-basics/managing-remote-repositories (verified 2026-06-10)

---

## 5. 与 TuringOS 法律的接口

**接口 1 — auth token 永不入 tape / 事件流（投影安全）。** Device Flow 的 `device_code`/`access_token`/`refresh_token`、gh 取得的 token、本地 keychain token 一律**不得**作为字段或派生进入任何 event_stream / projection / receipt。token 唯一落点 = macOS Keychain（§3 持久化）；事件流只携带**非机密派生**（如 OWNER、repo 名、`token_source` 枚举如 `gh_cli`/`device_flow`/`local_only`、scope 摘要）。对齐 shipgate #6 禁忌断言（无第二套 source of truth、机密不入 contracts）与 PROJECTION_POLICY 三级 API 字段分级——auth secret 属最高敏感级，投影面零暴露。

**接口 2 — trust_state 不因 auth 方式而变。** onboarding 的 auth 方式（gh 复用 / Device Flow / 纯本地）决定的是「App 能否代用户读 GitHub」，**不是** ActorTrustState（`docs/TRUST_STATES.md` 的 11 态:`observed_unsigned`…`human_root_signed`）。后者描述 worktree/proposal/identity 的签名信任,由 P2 manifest+签名体系裁决,与「用什么 token 调 API」正交。onboarding atom **禁止**自造任何随 auth 方式变化的红黄绿——纯本地模式下 repo 仍可是 `observed_unsigned`(observe-only),与是否联网取 token 无关。

**接口 3 — auth/onboarding 全程落在 L0 只读操作域(`docs/RATIFICATION_POLICY.md`)。** repo 发现、`gh auth token` 探测、remote 归一化、`git config` 读取、`user/repos` 列举均为 Observe(L0:无确认、只记录)。唯二可能抬级:① `RegisterProject`/`OpenWorktree` 是 L1(普通确认、可撤销、无签名);② Device Flow 用户授权发生在 GitHub 端浏览器,App 侧仍是 L0 轮询。auth 接入**不触及 L2+ 签名仪式**,不消耗签名注意力预算(防签名疲劳立法)。token 写 Keychain 是本地 L1 副作用,非 ratification。

---

## 6. UNVERIFIED 待补清单（需本机/直连一手实测，逐条写实测方法）

1. **`gh auth token` 引入版本号(声称 ≥ 2.19.0)。**(§2)
   实测:`gh --version` 确认本机版本;直连 https://github.com/cli/cli/releases 或 changelog grep 该命令首次出现版本;版本门控阈值据此钉死。

2. **gh 未登录时 `gh auth token` 的精确 exit code(声称非零,早期有 bug)。**(§2)
   实测:本机 `gh auth logout` 后跑 `gh auth token; echo "exit=$?"`,记录 exit code + stdout 是否真空;再 `gh auth login` 后复测,固化「exit≠0 OR stdout 空 = 无认证」判据。

3. **`gh auth status --json hosts` 的确切 schema 字段名与 `scopes` 分隔符。**(§2)
   实测:本机 `gh auth status --json hosts` 抓真实 JSON,核对 `state`/`active`/`login`/`tokenSource`/`scopes`/`gitProtocol` 字段是否齐全、`scopes` 是否真逗号分隔。

4. **第三方进程 `security find-generic-password -s "gh:github.com" -w` 是否真被 ACL 拒绝/弹框。**(§2 红线)
   实测:从非 gh 进程(如 Terminal 下脚本)跑该命令,观察是返回 token、弹授权框、还是 `errSecAuthFailed`;确认 L-gh 不能绕 `gh auth token` 直读 keychain。

5. **Device Flow 真实往返(端点/字段/错误码逐一对照)。**(§3)
   实测:用真实 OAuth App client_id 跑 `POST /login/device/code` 抓全响应字段;再轮询 `/login/oauth/access_token` 触发并记录 `authorization_pending`/`slow_down`/到期 `expired_token` 真实 JSON;核对 `interval`/`expires_in` 真值。

6. **`kSecAttrAccessibleWhenUnlockedThisDeviceOnly` + `kSecClassInternetPassword` 在目标签名/沙箱配置下的存读改删全链。**(§3)
   实测:本机 Swift 跑 SecItemAdd/CopyMatching/Update/Delete 四件套,验证 `errSecDuplicateItem` 触发路径与登出删除生效;在直发(非 MAS)签名形态下确认 access group 行为。

7. **非沙盒签名 app 访问 `~/Developer` 无 TCC 弹框、访问 Desktop 触发 per-folder 弹框的实测分界。**(§4)
   实测:用 ad-hoc 或 Developer ID 签名的测试 app,分别读 `~/Developer/<repo>` 与 `~/Desktop/<repo>`,记录哪个弹框、plist 缺 `NSDesktopFolderUsageDescription` 时是否静默拒绝;确认 NSOpenPanel 选 Desktop 是否免框。

8. **`find` 全 `~` 扫描在真实大 home 的耗时与 maxdepth 命中率。**(§4)
   实测:本机 `time find /Users/<user> -maxdepth 6 -name .git -type d 2>/dev/null` 计时,对比仅扫约定目录的覆盖率,定 onboarding 默认扫描策略与深度上限。

9. **ASWebAuthenticationSession 在目标沙箱配置下「无法呈现 UI」是否复现。**(§3,选型佐证)
   实测:仅当未来考虑该方案时验证;当前裁决已否,标 monitor,不阻塞 onboarding atom。

---

落盘说明：本文件为 **Phase 1 补充 memo**（A1_07_onboarding_connect_select 的
verified_external_facts 引用源），**不是** P2 的 R-stage 门禁文件——P2（Identity & Wallet）
仍处「待 R2」状态，`research/R2_memo.md` 不存在是有意为之（R→D→S 门禁）。
法律接口依据：docs/TRUST_STATES.md、docs/RATIFICATION_POLICY.md、docs/PROJECTION_POLICY.md。
