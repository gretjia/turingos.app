// AppCommandBus.swift — A1_30 menu-bar command channel.
//
// 用户裁决 2026-06-12：left sidebar 完全去除，功能迁入 macOS 系统菜单栏。
// Software 3.0 compliance (docs/02 §6): the menu bar is the QUIET
// discoverability escape hatch — not primary navigation. Orb stays the
// only first screen (P4); the menu is the formal entry for what you could
// otherwise type into the Orb.
//
// Design: menu item → bus.send(command) → views consume. The bus is pure
// state (one pending slot, send/consume) so it is unit-testable without
// SwiftUI rendering. Command metadata (titles, shortcut keys) lives on the
// enum as data only — scenes render it, nothing here imports SwiftUI views.

import Foundation
import Combine

// MARK: - AppCommand

/// Every command reachable from the system menu bar (A1_30 charter):
///   项目: 立项⌘N / 连接仓库⌘O / 项目总览⌘1
///   视图: Orb 主屏⌘0 / 内核调试面⌘D / Radar / Attention / CI
///   检查: CI 检查⌘R / Morning Ritual⌘M
public enum AppCommand: String, CaseIterable, Sendable {
    case newInit
    case connectRepo
    case projectOverview
    case showOrb
    case showKernelDebug
    case showRadar
    case showAttention
    case showCI
    case runCICheck
    case morningRitual

    /// Menu item label (Chinese-first per charter; data only).
    public var menuTitle: String {
        switch self {
        case .newInit:          return "立项"
        case .connectRepo:      return "连接仓库"
        case .projectOverview:  return "项目总览"
        case .showOrb:          return "Orb 主屏"
        case .showKernelDebug:  return "内核调试面"
        case .showRadar:        return "Radar"
        case .showAttention:    return "Attention"
        case .showCI:           return "CI"
        case .runCICheck:       return "CI 检查"
        case .morningRitual:    return "Morning Ritual"
        }
    }

    /// Keyboard shortcut key (nil = menu item without a shortcut).
    /// All chartered shortcuts use the command modifier.
    public var keyboardShortcutKey: Character? {
        switch self {
        case .newInit:          return "n"
        case .connectRepo:      return "o"
        case .projectOverview:  return "1"
        case .showOrb:          return "0"
        case .showKernelDebug:  return "d"
        case .showRadar, .showAttention, .showCI:
            return nil
        case .runCICheck:       return "r"
        case .morningRitual:    return "m"
        }
    }

    /// Human-readable modifier prefix ("⌘" for shortcut-bearing commands,
    /// "" otherwise). Data only — the scene applies the real modifiers.
    public var shortcutModifiersDescription: String {
        keyboardShortcutKey == nil ? "" : "⌘"
    }
}

// MARK: - AppCommandBus

/// One-slot command bus: the menu bar publishes, views consume.
///
/// `@unchecked Sendable`: every access happens on the main thread (SwiftUI
/// menu actions + view `onReceive`); the class holds no other shared state.
public final class AppCommandBus: ObservableObject, @unchecked Sendable {
    /// The command awaiting a consumer. `@Published` so views replay the
    /// current value on subscription (a sheet presented AFTER `send` still
    /// receives the command).
    @Published public var pending: AppCommand?

    public init() {}

    /// Publish a command. A newer send overwrites an unconsumed one
    /// (last intent wins — the user changed their mind).
    public func send(_ command: AppCommand) {
        pending = command
    }

    /// Return the pending command and clear it (nil afterwards). Pure
    /// state transition — testable without SwiftUI.
    @discardableResult
    public func consume() -> AppCommand? {
        defer { pending = nil }
        return pending
    }
}
