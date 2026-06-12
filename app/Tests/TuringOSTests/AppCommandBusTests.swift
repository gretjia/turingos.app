// AppCommandBusTests.swift — A1_30 menu command bus unit tests.
//
// Predicate coverage (atom card A1_30_menubar_no_sidebar):
//   1. Enum completeness: exactly the 10 chartered menu commands.
//   2. Bus purity: send sets pending; consume returns AND clears it.
//   3. ContentView pure mapping: every 视图 command selects the right
//      NavItem; non-view commands are explicitly NOT ContentView's.
//   4. Menu data: every command carries a non-empty menuTitle; shortcut
//      keys match the charter (立项⌘N/连接仓库⌘O/项目总览⌘1/Orb⌘0/
//      调试面⌘D/CI检查⌘R/Morning Ritual⌘M; Radar/Attention/CI = none).

import Foundation
import XCTest
@testable import TuringOS

final class AppCommandBusTests: XCTestCase {

    // MARK: - Test 1: Enum completeness

    func testCommandEnumCompleteness() {
        XCTAssertEqual(AppCommand.allCases.count, 10,
                       "A1_30 charters exactly 10 menu commands")
    }

    // MARK: - Test 2: Bus send/consume purity

    func testBusSendSetsPendingAndConsumeClears() {
        let bus = AppCommandBus()
        XCTAssertNil(bus.pending, "fresh bus has no pending command")

        bus.send(.newInit)
        XCTAssertEqual(bus.pending, .newInit, "send sets pending")

        XCTAssertEqual(bus.consume(), .newInit, "consume returns the command")
        XCTAssertNil(bus.pending, "consume clears pending")
        XCTAssertNil(bus.consume(), "second consume yields nil")
    }

    func testBusSendOverwritesUnconsumedCommand() {
        let bus = AppCommandBus()
        bus.send(.showRadar)
        bus.send(.showCI)
        XCTAssertEqual(bus.consume(), .showCI, "last intent wins")
        XCTAssertNil(bus.pending)
    }

    // MARK: - Test 3: ContentView pure command->panel mapping

    func testApplyCommandMapsEveryViewCommand() {
        // .showRadar -> worktreeRadar
        var sel: NavItem? = .globalOps
        XCTAssertTrue(ContentView.applyCommand(.showRadar, to: &sel))
        XCTAssertEqual(sel, .worktreeRadar)

        // .showAttention -> globalOps (home == Attention Stack)
        XCTAssertTrue(ContentView.applyCommand(.showAttention, to: &sel))
        XCTAssertEqual(sel, .globalOps)

        // .showCI -> globalOps (P1: CI evidence surfaces in the home stack)
        sel = .worktreeRadar
        XCTAssertTrue(ContentView.applyCommand(.showCI, to: &sel))
        XCTAssertEqual(sel, .globalOps)

        // .showKernelDebug: handled (ContentView IS the pane), selection kept
        sel = .worktreeRadar
        XCTAssertTrue(ContentView.applyCommand(.showKernelDebug, to: &sel))
        XCTAssertEqual(sel, .worktreeRadar, "kernel debug keeps the current panel")
    }

    func testApplyCommandRejectsNonViewCommands() {
        let orbCommands: [AppCommand] = [
            .newInit, .connectRepo, .projectOverview,
            .showOrb, .runCICheck, .morningRitual,
        ]
        for command in orbCommands {
            var sel: NavItem? = .globalOps
            XCTAssertFalse(ContentView.applyCommand(command, to: &sel),
                           "\(command) belongs to OrbView, not ContentView")
            XCTAssertEqual(sel, .globalOps,
                           "\(command) must not change the panel selection")
        }
    }

    // MARK: - Test 4: Menu data completeness

    func testEveryCommandHasNonEmptyMenuTitle() {
        for command in AppCommand.allCases {
            XCTAssertFalse(command.menuTitle.isEmpty,
                           "\(command) menuTitle must be non-empty")
        }
    }

    func testShortcutKeysMatchCharter() {
        XCTAssertEqual(AppCommand.newInit.keyboardShortcutKey, "n")
        XCTAssertEqual(AppCommand.connectRepo.keyboardShortcutKey, "o")
        XCTAssertEqual(AppCommand.projectOverview.keyboardShortcutKey, "1")
        XCTAssertEqual(AppCommand.showOrb.keyboardShortcutKey, "0")
        XCTAssertEqual(AppCommand.showKernelDebug.keyboardShortcutKey, "d")
        XCTAssertNil(AppCommand.showRadar.keyboardShortcutKey)
        XCTAssertNil(AppCommand.showAttention.keyboardShortcutKey)
        XCTAssertNil(AppCommand.showCI.keyboardShortcutKey)
        XCTAssertEqual(AppCommand.runCICheck.keyboardShortcutKey, "r")
        XCTAssertEqual(AppCommand.morningRitual.keyboardShortcutKey, "m")

        // Modifier description is data-consistent with the key.
        for command in AppCommand.allCases {
            let expected = command.keyboardShortcutKey == nil ? "" : "⌘"
            XCTAssertEqual(command.shortcutModifiersDescription, expected,
                           "\(command) modifier description mismatch")
        }
    }
}
