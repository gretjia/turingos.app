// DesignTokens - the single visual law file (DESIGN.md 美学门禁化: no magic
// values outside this file). Values come verbatim from the ratified V6
// design (design/mockups/v6/) reconciled with docs/VISUAL_SEMANTICS.md:
// the six semantic colors are the ONLY state vocabulary; project accent
// colors are a separate identity-surface channel (rules 5-7) and must never
// reuse semantic values.

import SwiftUI

public enum Tokens {
    // MARK: - Semantic six (VISUAL_SEMANTICS - the law, V6 token values)

    public enum Semantic: String, CaseIterable, Sendable {
        case green, red, yellow, gray, blue, purple

        /// Hex values exactly as in V6 `:root` design tokens.
        public var hex: UInt32 {
            switch self {
            case .green: 0x34D399 // verified / pass / merged
            case .red: 0xF87171 // failed / veto / invalid
            case .yellow: 0xFBBF24 // attention / conflict / risk finding
            case .gray: 0x9CA3AF // unknown / inferred / foreign
            case .blue: 0x3B82F6 // active / streaming / current
            case .purple: 0xA855F7 // ratification / class-4 / human-root
            }
        }

        public var color: Color { Color(hex: hex) }
    }

    /// trust_state -> semantic color, the unique mapping from
    /// docs/TRUST_STATES.md. Rendering anywhere else is a design-review FAIL.
    public static func semantic(for trustState: TrustState) -> Semantic {
        switch trustState {
        case .observedUnsigned, .legacyPreRule: .gray
        case .manifestMissing, .signatureInvalid, .signerUnregistered, .signerRevoked: .red
        case .manifestRegistered: .blue
        case .signatureValid, .humanAdopted: .green
        case .capabilityMissing: .yellow
        case .humanRootSigned: .purple
        }
    }

    // MARK: - Project accent channel (VISUAL_SEMANTICS rules 5-7)

    /// Identity-surface-only palette (nebula / giant label / axis tint).
    /// VISUAL_SEMANTICS rule 6 bans semantic values AND near-values: this
    /// palette is enforced by RGB-distance tests (every accent >= 72 from
    /// every semantic anchor, >= 56 from every other accent - S-stage
    /// critique closed the exact-equality loophole). Assignment is a stable
    /// hash of project_id so a project keeps its hue across runs.
    public enum Accent {
        public static let palette: [UInt32] = [
            0x06B6D4, // cyan
            0xF0ABFC, // fuchsia
            0xF97316, // orange (V6 heritage hue - not in the semantic six)
            0x84CC16, // lime
            0xE2E8F0, // ice
            0xA16207, // sand
        ]

        public static func color(forProjectId id: String) -> Color {
            Color(hex: palette[abs(stableHash(id)) % palette.count])
        }

        /// djb2 - deterministic across runs (Hasher is seeded per-process).
        static func stableHash(_ s: String) -> Int {
            var h = 5381
            for b in s.utf8 { h = ((h << 5) &+ h) &+ Int(b) }
            return h
        }
    }

    // MARK: - Space / glass material (V6 base materials)

    public enum Space {
        public static let background = Color(hex: 0x030305)
        public static let glassBase = Color(hex: 0x0F0F14).opacity(0.5)
        public static let glassBorder = Color.white.opacity(0.05)
        public static let glassBlurRadius: CGFloat = 40
        public static let starGridSpacing: CGFloat = 80
    }

    public enum Text {
        public static let primary = Color.white
        public static let secondary = Color(hex: 0x9CA3AF)
        public static let tertiary = Color(hex: 0x4B5563)
    }

    // MARK: - Typography (V6: Inter UI / JetBrains Mono code)
    // Fonts resolve by name with system fallback; OFL binaries ship in
    // A1_08 (visual atom). Fallback keeps every label legible meanwhile.

    public enum Typography {
        public static let uiFamily = "Inter"
        public static let monoFamily = "JetBrains Mono"

        public static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .custom(uiFamily, size: size).weight(weight)
        }

        public static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .custom(monoFamily, size: size).weight(weight)
        }
    }

    // MARK: - Motion budget (V6: breathe, don't flicker)

    public enum Motion {
        /// Activity pulse period - matches the daemon debounce philosophy.
        public static let pulsePeriod: Double = 4.0
        public static let cardHover: Double = 0.3
        public static let popIn: Double = 0.2
        /// Semantic zoom threshold: below this scale the universe compresses
        /// (isFar gate for far-mode label/dot/lineWidth — value-equivalent to
        /// the V6 0.6 threshold across the new [0.01,256] z envelope).
        public static let semanticFarThreshold: Double = 0.6
        /// ADR-016: expanded from 0.1–2.0 (V6) to ~0.01–256 (A1_51a).
        public static let zoomRange: ClosedRange<Double> = 0.01...256.0
        /// Mainline-track sweep period (V6 axisSweep - a slow tide, not a blink).
        public static let axisSweepPeriod: Double = 6.0
        /// Fly-to camera glide.
        public static let flyTo: Double = 0.45

        /// Z-band thresholds (A1_51a: defined here, consumed by A1_51c+).
        /// galaxy < cluster < node < detail.
        public enum ZBand {
            public static let clusterThreshold: Double = 0.08
            public static let nodeThreshold: Double = 0.5
            public static let detailThreshold: Double = 2.0
        }
    }
}

extension Color {
    /// Token plumbing only - views take colors from Tokens, never raw hex.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}
