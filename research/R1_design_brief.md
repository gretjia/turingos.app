# R1 设计简报 — Worktree Radar V0（停机点呈交件）

> 依 ADR-012：本简报与五项关键裁决（D1-D5）经用户确认后，方可产出 P1 Atom 卡集。
> 内核问与体验问双轨并答；证据见 [R1_memo.md](R1_memo.md)。

## 产品时刻定位

P1 交付 **Glance** 与 **Radar** 两个 UX 时刻的 V0：用户把项目交给系统后，**零点击**即知一切是否健康（菜单栏），**一眼**即知谁在哪个 worktree 干什么（主窗口）。只读——本 Phase 不写用户仓库一个字节。

## 五项关键裁决（D1-D5，等待用户确认）

### D1 部署目标 = macOS 26（建议）

全量 Liquid Glass；覆盖 26+27（27 精修经 SDK 重编自动生效，无 hard API delta——judgement，27.x 复核）；不下探（产品前提 Software 3.0 原生，P2 需现代 SE 栈）。**确认后 PINS.toml stable lane 钉 Xcode 26.5 / Swift 6.3.2 / target macOS 26（UpdatePins = L3，需您批准——本简报确认即视为批准）。**

### D2 入口形态 = MenuBarExtra 常驻 + 主窗口 Radar 并举（建议）

- **菜单栏（Glance）**：状态点（全产品最高异常等级的色语义）+ 三计数（活跃会话/待审提案/异常 worktree）+ 点击下拉迷你列表。永不弹窗打断。
- **主窗口（Radar）**：项目 → worktree 行视图。NAVIGATION_MODEL 五问已立法，P1 实现其 Worktrees 页。

### D3 Radar 信息架构（行级语义）

每行 = 一个 worktree：`分支(或 detached 徽章) | HEAD 短哈希 | dirty 指纹(±行数/Bin/LFS) | 占用者(agent/human/未知) | trust badge | 活动脉冲(FSEvents 脏信号, blue)`。
特殊行：**同分支双检出冲突**（`--force` 可造成，正常不该有）→ 整行 attention(yellow) + 显式冲突说明；**prunable/gitdir 死链** → foreign(gray) + 「对账发现的孤儿」；外部工具创建的 worktree → gray「未注册来源」。失败与异常永远是看得见的状态。

### D4 数据通路 = Rust daemon 看守 + Swift 纯投影（建议，本裁决影响最深远）

```
git repo ──(git2 枚举 + porcelain -z 快照)──> turingosd(Rust)
FSEvents 脏信号 ──(notify crate, FSEvents backend)──┘   │
                                    UDS + JSONL 事件订阅(契约: event_stream.schema.json)
                                                        ▼
                                              SwiftUI App = 纯投影消费者
```

- 与 ADR-005/011 同构：daemon 是唯一内核，Swift 壳**只消费投影**——未来 iOS 遥控面零返工。
- P0.5 渲染器证明的 `events → projection → view` 链在 P1 原样升级：fixtures 不变，渲染端换成 SwiftUI。
- 备选（被否方案）：Swift 直接读 git——更快出活，但身份/签名/对账逻辑日后必须搬回 daemon，等于把 ADR-005 推迟成债。
- **风险登记**：notify crate 的 FSEvents backend 未实证（R1 UNVERIFIED #7），P1 第一颗内核 Atom 即做 spike，失败则降级为「daemon 周期对账 + Swift 侧 FSEvents 转发」，契约不变。

### D5 验收形态 = 三层

①macOS CI lane（`runs-on: macos-26`，xcodebuild 构建+单测+golden 快照测试）进 shipgate p1；②Rust 测试继续 Linux lane（peer-cred trait 抽象，macOS pid 路径 CI 实测补 UNVERIFIED）；③**Phase 末视觉评审 checkpoint：您的 Mac 首次出场**（Liquid Glass 手感 + VoiceOver 走查，主观美学走人类评审——M8）。

## 双轨反向塑形（本期新增登记）

| UX 需求 | 反向塑形 |
|---|---|
| 活动脉冲要「呼吸感」而非闪烁噪音 | daemon 端 FSEvents 去抖窗口成为协议参数（事件信封新增 debounce 元数据，schema minor 扩展） |
| 菜单栏三计数要恒时可信 | daemon 必须维护常驻聚合投影（不是查询时现算）——投影守恒测试覆盖 |

## P1 不做（防镀金）

不写用户仓库；不做 diff 全文查看器（P6 提案审阅的职责）；不做 worktree 创建/删除（P4-P5）；不递归 submodule 内部；不做多机。

## 确认方式

回复确认/修改 D1-D5 任意项。确认后我自主执行：PINS 钉版 → Atom 卡集（预计 6-8 颗：daemon 骨架/枚举快照/FSEvents spike/UDS 订阅/SwiftUI 壳/MenuBarExtra/golden+CI）→ D-stage 开发 → S-stage 过闸，下次停机即 Phase 末视觉评审。
