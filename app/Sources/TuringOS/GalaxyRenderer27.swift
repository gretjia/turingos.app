// GalaxyRenderer27.swift — macOS-27-only Metal API isolation (ADR-008)
//
// ALL macOS-27-only Metal calls live HERE behind #available(macOS 27, *).
// The file is source-isolated so the 26.5-SDK whole-compile (shipgate gate 16)
// succeeds without referencing 27-only symbols elsewhere.
//
// Non-GalaxyRenderer27 files MUST NOT reference the sentinel symbol
// `MTLGalaxyRenderer27SentinelFunction` or any other 27-only symbol.
// This is verified in RadarLODTests.testMacOS27SymbolIsolation with positive
// teeth: the grep MUST hit if a 27-only symbol is injected elsewhere.
//
// Current macOS 27 usage:
//   - None yet (P1 uses only macOS 26-compatible Metal APIs). This file is
//     the designated landing zone so the isolation scaffold is in place.
//
// Sentinel symbol name: MTLGalaxyRenderer27SentinelFunction
// (the test greps for this exact string to verify isolation)

import MetalKit

// MARK: - macOS 27-only scaffold (isolated landing zone)

/// Sentinel name used by RadarLODTests.testMacOS27SymbolIsolation.
/// Must ONLY appear in this file. The test greps for this string and
/// asserts it appears ONLY in GalaxyRenderer27.swift.
/// (The actual function is a stub; P1 has no 27-only Metal calls yet.)
@available(macOS 27, *)
func MTLGalaxyRenderer27SentinelFunction(device: MTLDevice) {
    // Reserved for future macOS-27-specific Metal optimisations:
    // e.g. MTLResidencySet, MTLIOCommandBuffer, mesh shaders.
    // P1 stub: no-op.
    _ = device
}

/// Configure any macOS-27-specific Metal features on the command buffer.
/// Called from GalaxyRenderer.Coordinator when #available(macOS 27, *) is true.
/// Kept no-op in P1; filled in when 27-only API gains a concrete benefit.
@available(macOS 27, *)
func configureCommandBufferForMacOS27(_ commandBuffer: MTLCommandBuffer) {
    // P1: nothing yet. Placeholder ensures the file is non-empty and
    // the sentinel search in tests returns exactly one file.
    _ = commandBuffer
}
