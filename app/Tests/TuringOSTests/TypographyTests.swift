// TypographyTests.swift — A1_51d: font registration predicate
//
// Predicate: registerBundledFonts() returns true (real CTFontManagerRegisterFontsForURL
// fired from TuringOS_TuringOS.bundle) AND NSFont resolves both families.
//
// Two-step design prevents false green on machines where Inter/JetBrains Mono
// happen to be installed system-wide: if Bundle.module can't find the bundled
// TTFs, registerBundledFonts() returns false and the first assertion fails.

import AppKit
import XCTest
@testable import TuringOS

final class TypographyTests: XCTestCase {

    func testBundledFontsRegister() {
        // registerBundledFonts() must return true — every TTF in
        // TuringOS_TuringOS.bundle/Fonts/ was registered without error.
        // A false here means Bundle.module can't locate the Fonts/ directory
        // (bundle not copied / Package.swift resources missing).
        XCTAssertTrue(
            registerBundledFonts(),
            "registerBundledFonts() returned false — bundled TTFs not registered. "
            + "Check that swift build produced TuringOS_TuringOS.bundle/Fonts/ "
            + "and Bundle.module resolves it from the test binary.")
    }

    func testBundledFontFamiliesAvailable() {
        // Call registration before querying (idempotent — already-registered is OK).
        registerBundledFonts()

        XCTAssertNotNil(
            NSFont(name: "Inter", size: 12),
            "NSFont(name:\"Inter\") is nil after registration — "
            + "check fc-scan family name matches \"Inter\"")

        XCTAssertNotNil(
            NSFont(name: "JetBrains Mono", size: 12),
            "NSFont(name:\"JetBrains Mono\") is nil after registration — "
            + "check fc-scan family name matches \"JetBrains Mono\"")
    }
}
