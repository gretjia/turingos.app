// GalaxyStaticLayer.swift — A1_51d static visual layer (nebula + ghost label)
//
// THREE-LAYER PARTITION (A1_51d):
//   1. GalaxyStaticLayer (this file)  — static: nebula multi-stop + ghost label
//   2. RadarViews projectLaneCanvas   — animated: axis sweep, lane track, edges
//   3. GalaxyRenderer (Metal)         — animated: star grid, node dots
//
// ZERO blur in this file (soft glow via 8-13 eased radial gradient stops).
// Identity colors (nebula / ghost / axis) ONLY via Tokens.Accent.color(forProjectId:)
// — no inline raw-hex color literals on identity surfaces.

import SwiftUI

/// Static galaxy background layer: per-project soft nebula and giant ghost labels.
///
/// This view does NOT use TimelineView and draws at most once per scene change.
/// The multi-stop radial gradient (8 stops) emulates a ~150px Gaussian blur
/// without any blur pass — zero animate-blur CPU cost.
struct GalaxyStaticLayer: View {
    let scene: RadarScene
    let camera: RadarCamera

    var body: some View {
        Canvas { context, size in
            // A1_55: positions now derived from galaxyCenter (not lane-Y).
            for project in scene.projects {
                drawNebula(context, project: project, size: size)
                drawGhostLabel(context, project: project, size: size)
            }
        }
    }

    // MARK: - Nebula (8-stop eased radial gradient, zero .blur)

    /// Emulates a 150px Gaussian blur via 8 eased radial stops.
    /// Color ONLY from Tokens.Accent.color(forProjectId:) — never inline hex.
    /// A1_55: center is now RadarLayout.galaxyCenter (not lane-Y).
    private func drawNebula(
        _ context: GraphicsContext,
        project: RadarProject,
        size: CGSize
    ) {
        // A1_55: anchor to galaxy center (coupled to node positions, not lane-Y).
        let worldCenter = RadarLayout.galaxyCenter(projectId: project.id, in: scene)
        let screenCenter = camera.toScreen(worldCenter)
        let center = CGPoint(x: screenCenter.x, y: screenCenter.y)

        // Base radius scales with zoom — stay visible at galaxy band.
        let baseRadius = max(180 * camera.scale, 60.0)

        // Accent color via identity-channel accessor (never inline RGB/hex).
        let accent = Tokens.Accent.color(forProjectId: project.id)

        // 8-stop eased radial gradient (cubic ease-out distribution):
        // r: 0 → max; opacity: 0.18 → 0 following a cubic curve.
        // This matches the visual softness of a 150px blur without any blur pass.
        let stops: [Gradient.Stop] = [
            .init(color: accent.opacity(0.18), location: 0.00),
            .init(color: accent.opacity(0.15), location: 0.10),
            .init(color: accent.opacity(0.11), location: 0.22),
            .init(color: accent.opacity(0.08), location: 0.36),
            .init(color: accent.opacity(0.05), location: 0.52),
            .init(color: accent.opacity(0.03), location: 0.68),
            .init(color: accent.opacity(0.01), location: 0.84),
            .init(color: accent.opacity(0.00), location: 1.00),
        ]

        context.fill(
            Path(ellipseIn: CGRect(
                x: center.x - baseRadius * 2.2,
                y: center.y - baseRadius,
                width: baseRadius * 4.4,
                height: baseRadius * 2.0)),
            with: .radialGradient(
                Gradient(stops: stops),
                center: center,
                startRadius: 0,
                endRadius: baseRadius * 2.2))
    }

    // MARK: - Ghost label (static Text, white.opacity(0.03))

    /// Giant ghost project label — identity surface, color from Tokens.Accent only.
    /// Opacity 0.03 keeps it subliminal (the star field reads over it).
    /// A1_55: anchored at galaxyCenter (not lane-Y).
    private func drawGhostLabel(
        _ context: GraphicsContext,
        project: RadarProject,
        size: CGSize
    ) {
        // A1_55: anchor ghost label to galaxy center (same origin as nodes).
        let worldCenter = RadarLayout.galaxyCenter(projectId: project.id, in: scene)
        let screenPt = camera.toScreen(worldCenter)

        // Ghost label: accent color at 3% opacity — identity channel.
        // Scale proportional to camera zoom so it stays readable at galaxy band.
        let fontSize = max(72 * camera.scale, 40.0)
        let accent = Tokens.Accent.color(forProjectId: project.id)

        context.draw(
            Text(project.id)
                .font(Tokens.Typography.ui(fontSize, weight: .bold))
                .foregroundStyle(accent.opacity(0.03)),
            at: CGPoint(x: screenPt.x, y: screenPt.y - fontSize * 0.3),
            anchor: .center)
    }
}
