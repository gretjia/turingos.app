---
atom: A1_47_daemon_branch_poller
phase: "1"
intent: >
  galaxy 分支扩展第二颗（让用户 25 仓的分支真正可见）：daemon 新增 registry-hub 级
  BranchPoller —— 对注册表中每个有 remote 的项目（本地或纯远程），用用户已登录的 gh
  shell-out（gh api repos/{o}/{r} 取 default_branch + gh api repos/{o}/{r}/branches
  --paginate 取分支列表），发 BranchObserved 事件（branch_ref/head_sha/is_default/
  provenance=github_api）；与上轮 diff 发 BranchRemoved。跑在 serve_registry 的**独立
  受监督线程**上、慢节奏（启动一次 + 每 5 分钟），绝不阻塞 2s reconcile tick（F1/F2/F3）。
  gh 不可用/网络失败 → 可见降级（eprintln），不崩、不发假事件。这是第一刀：分支节点
  先可见（turingosv4 72 分支等），ahead/behind/merged 富化留后续。pure parse/diff 函数
  单测；poll() 薄壳由真机验证（app 收到 BranchObserved → 渲染节点）。
allowlist:
  - "daemon/src/branch_poller.rs"
  - "daemon/src/lib.rs"
  - "daemon/src/main.rs"
  - "specs/atoms/A1_47_daemon_branch_poller.md"
  - "specs/atoms/CURRENT"
max_new_files: 1
predicates:
  - "bash scripts/shipgate.sh p1 全绿（gate13 fmt / gate14 clippy -D / gate15 rust tests 吃下新单测 / gate16 app lane 不破）"
  - "单测 parse_branches：fixture branches JSON（含 default 分支）→ 每分支一条 BranchObserved payload，branch_ref==refs/heads/<name>、head_sha 正确、is_default 仅 default 为真、provenance==github_api"
  - "单测 diff_removed：上轮 refs - 本轮 refs → 正确的 BranchRemoved ref 集"
  - "单测 owner_repo：github.com/owner/repo → (owner,repo)；非法 remote → None"
  - "真机验证（用户授权 gh 取全仓）：扩 projects.json 到 25 仓后，app 收到各项目 BranchObserved，galaxy 现出真实分支节点（turingosv4 多分支）"
verified_external_facts:
  - fact: "daemon 用 gh shell-out 而非 native HTTP（Cargo 无 reqwest，有 tokio）；EventHub::new→Arc<Self>，publish(kind,source,trust_state,payload) 跨线程 Arc 共享；daemon 非宪法 manifest 钉定（钉 runtime/）。gh api repos/{o}/{r}/branches 返回 [{name,commit:{sha}}]；repos/{o}/{r}.default_branch 给默认分支"
    source: "本会话 2026-06-14 读 daemon main.rs/uds.rs/registry.rs/Cargo.toml + gh api 实测"
    verified_on: "2026-06-14"
ux_touchpoints: >
  galaxy：每项目的远程分支经 daemon 观测成 BranchObserved（A1_49 渲成分支节点）。
  gh 失败 → 该项目无新分支事件 + stderr 可见，不假绿不崩。
gate: "bash scripts/shipgate.sh p1"

# 代码思路
branch_poller.rs：GhClient trait + LiveGhClient（gh 路径发现+shell）；pure
parse_branches(json,default,pid)→Vec<payload>；owner_repo(remote)→Option<(o,r)>；
diff_removed(prev,cur)→Vec<ref>；BranchPoller{registry_path, seen} poll(hub,gh)。
main.rs serve_registry：再开一个受监督线程跑 poller（启动一次 + sleep 300s）。
lib.rs：pub mod branch_poller。
