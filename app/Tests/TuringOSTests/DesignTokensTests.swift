// Design law as tests (DESIGN.md 美学门禁化): the accent channel must stay
// disjoint from the semantic six (VISUAL_SEMANTICS rule 6), and the
// trust_state -> color mapping must match docs/TRUST_STATES.md verbatim.

import XCTest
@testable import TuringOS

final class DesignTokensTests: XCTestCase {
    private func rgbDistance(_ a: UInt32, _ b: UInt32) -> Double {
        func c(_ h: UInt32, _ shift: UInt32) -> Double { Double((h >> shift) & 0xFF) }
        let dr = c(a, 16) - c(b, 16)
        let dg = c(a, 8) - c(b, 8)
        let db = c(a, 0) - c(b, 0)
        return (dr * dr + dg * dg + db * db).squareRoot()
    }

    /// Rule 6 incl. the 近似值 clause (S-stage critique: exact equality was
    /// a loophole - a teal nebula 38 RGB-units from verified-green is the
    /// exact ambiguity the rule exists to prevent). Thresholds: >= 72 from
    /// every semantic anchor, >= 56 between accents.
    func testAccentPaletteDistantFromSemanticSix() {
        for accent in Tokens.Accent.palette {
            for semantic in Tokens.Semantic.allCases {
                let dist = rgbDistance(accent, semantic.hex)
                XCTAssertGreaterThanOrEqual(
                    dist, 72,
                    "accent 0x\(String(accent, radix: 16)) too close to semantic \(semantic) (\(dist))"
                )
            }
        }
        for (i, a) in Tokens.Accent.palette.enumerated() {
            for b in Tokens.Accent.palette.dropFirst(i + 1) {
                XCTAssertGreaterThanOrEqual(rgbDistance(a, b), 56,
                                            "accents 0x\(String(a, radix: 16)) / 0x\(String(b, radix: 16)) confusable")
            }
        }
    }

    func testAccentAssignmentIsStable() {
        let a = Tokens.Accent.stableHash("proj_demo")
        let b = Tokens.Accent.stableHash("proj_demo")
        XCTAssertEqual(a, b, "same project must keep its hue across runs")
        // djb2 reference value pins the algorithm itself (no Hasher seeding).
        XCTAssertEqual(Tokens.Accent.stableHash(""), 5381)
    }

    func testTrustStateMappingMatchesLaw() {
        // docs/TRUST_STATES.md附表, verbatim.
        let law: [TrustState: Tokens.Semantic] = [
            .observedUnsigned: .gray,
            .manifestMissing: .red,
            .manifestRegistered: .blue,
            .signatureValid: .green,
            .signatureInvalid: .red,
            .signerUnregistered: .red,
            .signerRevoked: .red,
            .capabilityMissing: .yellow,
            .humanAdopted: .green,
            .humanRootSigned: .purple,
            .legacyPreRule: .gray,
        ]
        for (state, expected) in law {
            XCTAssertEqual(Tokens.semantic(for: state), expected, "\(state)")
        }
    }
}
