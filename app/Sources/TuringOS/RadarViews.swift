// A1_09: galaxy radar - the exploratory drill-down surface (NOT the home;
// 五次裁决降格). V6 material language (nebula / axis sweep / glass nodes)
// with Software 3.0 information hierarchy: a node is title + status glow
// until SELECTED; far zoom compresses nodes to glow dots and raises the
// giant project labels. All node forms/edges come from RadarScene - the
// view invents no facts - and RadarMood gray-washes the whole galaxy the
// moment the stream is not live (no breathing over stale data).

import AppKit
import SwiftUI

// MARK: - Layout preference store (local pref, never on tape)

public protocol RadarLayoutPrefs {
    func offset(for nodeId: String) -> CGSize
    func setOffset(_ offset: CGSize, for nodeId: String)
}

public struct DefaultsLayoutPrefs: RadarLayoutPrefs {
    public init() {}
    public func offset(for nodeId: String) -> CGSize {
        guard let arr = UserDefaults.standard.array(forKey: key(nodeId)) as? [Double],
              arr.count == 2 else { return .zero }
        return CGSize(width: arr[0], height: arr[1])
    }

    public func setOffset(_ offset: CGSize, for nodeId: String) {
        UserDefaults.standard.set(
            [Double(offset.width), Double(offset.height)], forKey: key(nodeId))
    }

    private func key(_ id: String) -> String { "radar.offset.\(id)" }
}

// MARK: - Transient gesture state (auto-reset on cancellation - S-stage
// blocker: manual *Last state survives a cancelled gesture and teleports
// the next one, persisting corrupted offsets)

struct MagnifyDelta: Equatable {
    var factor: CGFloat
    var anchor: CGPoint
}

struct NodeDragDelta: Equatable {
    var nodeId: String
    var translation: CGSize
}

// MARK: - Radar canvas

public struct RadarCanvasView: View {
    @ObservedObject var store: GlanceStore
    @Binding var focus: AttentionTarget?
    private let prefs: RadarLayoutPrefs

    /// Committed camera. Transient pan/magnify deltas live in @GestureState
    /// and are COMPOSED at render time (displayCamera), so a cancelled
    /// gesture can never corrupt the committed state.
    @State private var camera = RadarCamera()
    @State private var selectedNodeId: String?
    @State private var evidenceNode: RadarNode?
    @State private var userOffsets: [String: CGSize] = [:]

    @GestureState private var panDelta: CGSize = .zero
    @GestureState private var magnifyDelta: MagnifyDelta?
    @GestureState private var nodeDragDelta: NodeDragDelta?

    public init(
        store: GlanceStore,
        focus: Binding<AttentionTarget?>,
        prefs: RadarLayoutPrefs = DefaultsLayoutPrefs()
    ) {
        self.store = store
        self._focus = focus
        self.prefs = prefs
    }

    private var displayCamera: RadarCamera {
        var c = camera
        if let m = magnifyDelta { c.zoom(by: m.factor, anchor: m.anchor) }
        c.pan(by: panDelta)
        return c
    }

    public var body: some View {
        let scene = store.radarScene
        let mood = RadarMood.derive(connection: store.connection)
        GeometryReader { geo in
            let dc = displayCamera
            ZStack(alignment: .bottomTrailing) {
                Group {
                    // Bottom: Metal instanced visual layer (stars, node dots, edges).
                    // Fail-safe: headless → GalaxyFallbackView (no crash, exit 0).
                    GalaxyRenderer(scene: scene, camera: dc, mood: mood)
                        .contentShape(Rectangle())
                        .gesture(panGesture)
                        .gesture(magnifyGesture)
                        .onTapGesture { selectedNodeId = nil }

                    // Low-middle: project lane / nebula / axis sweep Canvas (SwiftUI,
                    // O(#projects)). The heavy per-node rendering moved to Metal above.
                    projectLaneCanvas(scene, mood: mood, camera: dc)
                        .allowsHitTesting(false)

                    // Middle: SwiftUI node card overlay (near/selected, from A1_51b).
                    nodeOverlay(scene, mood: mood)

                    // Top: a11y mirror layer (transparent SwiftUI elements, VoiceOver).
                    // 1:1 with visibleA11yElements output (including far-dot band).
                    a11yMirrorLayer(scene: scene, camera: dc, viewport: geo.size)
                        .allowsHitTesting(false)
                }
                // 未对账 ⇒ the whole galaxy visibly drains of color: stale
                // facts stay readable but stop pretending to be current.
                .grayscale(mood.live ? 0 : 1)
                .opacity(mood.live ? 1 : 0.75)

                RadarHUD(
                    zoomIn: { zoom(1.25, viewport: geo.size) },
                    zoomOut: { zoom(0.8, viewport: geo.size) },
                    reset: { camera = RadarCamera() }
                )
                .padding(16)

                if let banner = mood.banner {
                    MoodBanner(sentence: banner)
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .top)
                        .padding(.top, 14)
                        .allowsHitTesting(false)
                }

                ScrollWheelMonitor { deltaY, local in
                    camera.zoom(by: exp(deltaY * 0.01), anchor: local)
                }
                .allowsHitTesting(false)
            }
            .onChange(of: focus) { _, target in
                guard let target else { return }
                flyTo(target, scene: scene, viewport: geo.size)
                focus = nil // consumed
            }
            .onChange(of: store.radarScene) { _, newScene in
                loadOffsets(for: newScene)
            }
            .onAppear {
                loadOffsets(for: scene)
                if let target = focus {
                    flyTo(target, scene: scene, viewport: geo.size)
                    focus = nil
                }
            }
        }
        .background(Tokens.Space.background)
        .popover(item: $evidenceNode) { node in
            EvidenceDrawer(title: node.accessibilityLabel, evidence: node.evidence)
        }
    }

    /// Saved offsets are merged for every node currently in the scene, so
    /// worktrees discovered AFTER appear keep their persisted layout too.
    private func loadOffsets(for scene: RadarScene) {
        for node in scene.nodes where userOffsets[node.id] == nil {
            userOffsets[node.id] = prefs.offset(for: node.id)
        }
    }

    private func worldPosition(_ nodeId: String, in scene: RadarScene) -> CGPoint {
        let base = scene.positions[nodeId] ?? .zero
        let off = userOffsets[nodeId] ?? .zero
        return CGPoint(x: base.x + off.width, y: base.y + off.height)
    }

    private func screenPosition(_ nodeId: String, in scene: RadarScene) -> CGPoint {
        var p = displayCamera.toScreen(worldPosition(nodeId, in: scene))
        if let drag = nodeDragDelta, drag.nodeId == nodeId {
            p.x += drag.translation.width
            p.y += drag.translation.height
        }
        return p
    }

    private func zoom(_ factor: CGFloat, viewport: CGSize) {
        camera.zoom(
            by: factor,
            anchor: CGPoint(x: viewport.width / 2, y: viewport.height / 2))
    }

    private func flyTo(_ target: AttentionTarget, scene: RadarScene, viewport: CGSize) {
        guard let nodeId = scene.resolve(target) else { return }
        // Instant repositioning: Canvas (TimelineView) and node overlays
        // would desync during an implicit animation of non-Animatable
        // camera state - a tweened camera is a registered debt.
        camera = .focusing(
            on: worldPosition(nodeId, in: scene), scale: 1.0, viewport: viewport)
        selectedNodeId = nodeId
    }

    // MARK: gestures (@GestureState resets itself on cancellation)

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .updating($panDelta) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                camera.pan(by: value.translation)
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .updating($magnifyDelta) { value, state, _ in
                state = MagnifyDelta(
                    factor: value.magnification, anchor: value.startLocation)
            }
            .onEnded { value in
                camera.zoom(by: value.magnification, anchor: value.startLocation)
            }
    }

    private func nodeDrag(_ nodeId: String) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .updating($nodeDragDelta) { value, state, _ in
                state = NodeDragDelta(nodeId: nodeId, translation: value.translation)
            }
            .onEnded { value in
                var off = userOffsets[nodeId] ?? .zero
                off.width += value.translation.width / camera.scale
                off.height += value.translation.height / camera.scale
                userOffsets[nodeId] = off
                prefs.setOffset(off, for: nodeId)
            }
    }

    // MARK: drawing

    /// A11y mirror layer: transparent SwiftUI accessibility elements 1:1 with
    /// every visible node (including far-dot band). VoiceOver reads each label.
    /// Pure function source: visibleA11yElements(scene:camera:viewport:).
    private func a11yMirrorLayer(
        scene: RadarScene, camera: RadarCamera, viewport: CGSize
    ) -> some View {
        let mirrors = visibleA11yElements(scene: scene, camera: camera, viewport: viewport)
        return ZStack {
            ForEach(mirrors, id: \.nodeId) { mirror in
                Color.clear
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .position(mirror.screenPoint)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(mirror.label)
                    .accessibilityAddTraits(.isButton)
            }
        }
    }

    /// Project lane Canvas: nebula, lane track, axis sweep, far-mode project
    /// labels. These are O(#projects) elements — NOT instanced in Metal.
    /// The dense per-node/per-edge rendering has moved to GalaxyRenderer.
    private func projectLaneCanvas(
        _ scene: RadarScene, mood: RadarMood, camera: RadarCamera
    ) -> some View {
        // The sweep tide pauses on a dead stream - motion is an activity
        // claim (and an all-quiet battery courtesy at 30fps).
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !mood.live)) { timeline in
            Canvas { context, size in
                let sweep = timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: Tokens.Motion.axisSweepPeriod)
                    / Tokens.Motion.axisSweepPeriod
                for (row, project) in scene.projects.enumerated() {
                    drawProjectLane(
                        context, scene: scene, project: project, row: row,
                        camera: camera,
                        sweepPhase: mood.live ? sweep : -1)
                }
            }
        }
    }

    private func laneSpan(_ project: RadarProject, scene: RadarScene, row: Int) -> (CGPoint, CGPoint) {
        let xs = project.nodeIds.compactMap { scene.positions[$0]?.x }
        let y = RadarLayout.topMargin + CGFloat(row) * RadarLayout.laneHeight
        let minX = (xs.min() ?? RadarLayout.anchorX) - 140
        let maxX = (xs.max() ?? RadarLayout.anchorX) + 140
        return (CGPoint(x: minX, y: y), CGPoint(x: maxX, y: y))
    }

    private func drawProjectLane(
        _ context: GraphicsContext, scene: RadarScene, project: RadarProject,
        row: Int, camera: RadarCamera, sweepPhase: Double
    ) {
        let accent = Tokens.Accent.color(forProjectId: project.id)
        let (a, b) = laneSpan(project, scene: scene, row: row)
        let sa = camera.toScreen(a)
        let sb = camera.toScreen(b)

        // Nebula: identity surface (VISUAL_SEMANTICS rule 5) - accent only.
        let center = CGPoint(x: (sa.x + sb.x) / 2, y: sa.y)
        let radius = max(120 * camera.scale, 40)
        context.fill(
            Path(ellipseIn: CGRect(
                x: center.x - radius * 2.4, y: center.y - radius,
                width: radius * 4.8, height: radius * 2)),
            with: .radialGradient(
                Gradient(colors: [accent.opacity(0.14), .clear]),
                center: center, startRadius: 0, endRadius: radius * 2.4))

        // Mainline track (thicker in far mode, V6 §7.2 boost).
        var track = Path()
        track.move(to: sa)
        track.addLine(to: sb)
        context.stroke(
            track, with: .color(.white.opacity(0.12)),
            lineWidth: camera.isFar ? 4 : 2)

        // Axis sweep: one slow light tide (suppressed when not live).
        if sweepPhase >= 0 {
            let t = CGFloat(sweepPhase)
            let sweepX = sa.x + (sb.x - sa.x) * t
            let sweepLen = max((sb.x - sa.x) * 0.12, 24)
            var sweep = Path()
            sweep.move(to: CGPoint(x: sweepX - sweepLen / 2, y: sa.y))
            sweep.addLine(to: CGPoint(x: sweepX + sweepLen / 2, y: sa.y))
            context.stroke(
                sweep,
                with: .linearGradient(
                    Gradient(colors: [.clear, .white.opacity(0.35), .clear]),
                    startPoint: CGPoint(x: sweepX - sweepLen / 2, y: sa.y),
                    endPoint: CGPoint(x: sweepX + sweepLen / 2, y: sa.y)),
                lineWidth: camera.isFar ? 4 : 2)
        }

        // Far mode: the giant project label rises (V6 §7.2 Show).
        if camera.isFar {
            context.draw(
                Text(project.id)
                    .font(Tokens.Typography.ui(28, weight: .bold))
                    .foregroundStyle(accent.opacity(0.85)),
                at: CGPoint(x: sa.x, y: sa.y - 34 * camera.scale - 22),
                anchor: .leading)
            // A1_51b: branch node count per lane (derived from scene nodes,
            // not a separate branchCounts map; branch/commit nodes are galaxy
            // children, not counters).
            let branchNodeCount = scene.nodes.filter {
                $0.projectId == project.id && $0.kind == .branch
            }.count
            if branchNodeCount > 0 {
                context.draw(
                    Text("\(branchNodeCount) 分支")
                        .font(Tokens.Typography.mono(13, weight: .medium))
                        .foregroundStyle(accent.opacity(0.55)),
                    at: CGPoint(x: sa.x, y: sa.y - 34 * camera.scale - 2),
                    anchor: .leading)
            }
        }
    }

    // drawEdge retained for reference; edge rendering moved to GalaxyRenderer
    // for the dense instanced path. A thin SwiftUI overlay would duplicate them.
    // Kept private to avoid "unused" warnings while preserving structure for A1_51d.
    @inline(__always)
    private func drawEdge(_ context: GraphicsContext, edge: RadarEdge, scene: RadarScene) {
        let fromScreen = screenPosition(edge.from, in: scene)
        let toScreen = screenPosition(edge.to, in: scene)
        let camera = displayCamera
        var path = Path()
        path.move(to: fromScreen)
        let cpOff = max(abs(toScreen.x - fromScreen.x) * 0.4, 30 * camera.scale)
        path.addCurve(
            to: toScreen,
            control1: CGPoint(x: fromScreen.x + cpOff, y: fromScreen.y),
            control2: CGPoint(x: toScreen.x - cpOff, y: toScreen.y))
        switch edge.kind {
        case .membership:
            context.stroke(path, with: .color(.white.opacity(0.18)),
                lineWidth: camera.isFar ? 8 : 1.5)
        case .conflictTension:
            context.stroke(path, with: .color(Tokens.Semantic.yellow.color.opacity(0.7)),
                lineWidth: camera.isFar ? 8 : 4)
        case .fork:
            context.stroke(path, with: .color(.white.opacity(0.12)),
                lineWidth: camera.isFar ? 4 : 1)
        case .parent:
            context.stroke(path, with: .color(.white.opacity(0.08)),
                lineWidth: camera.isFar ? 3 : 0.8)
        }
    }

    private func nodeOverlay(_ scene: RadarScene, mood: RadarMood) -> some View {
        ForEach(scene.nodes) { node in
            RadarNodeCard(
                node: node,
                content: .derive(
                    node: node,
                    selected: selectedNodeId == node.id,
                    far: displayCamera.isFar),
                selected: selectedNodeId == node.id,
                live: mood.live,
                onSelect: {
                    selectedNodeId = selectedNodeId == node.id ? nil : node.id
                },
                onEvidence: { evidenceNode = node }
            )
            .position(screenPosition(node.id, in: scene))
            .gesture(nodeDrag(node.id))
        }
    }
}

// MARK: - Mood banner (visible staleness, M2: no silent states)

struct MoodBanner: View {
    let sentence: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Tokens.Semantic.gray.color)
                .frame(width: 8, height: 8)
            Text(sentence)
                .font(Tokens.Typography.ui(12, weight: .medium))
                .foregroundStyle(Tokens.Text.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Tokens.Space.glassBase, in: Capsule())
        .overlay(Capsule().stroke(Tokens.Space.glassBorder))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(sentence)
    }
}

// MARK: - Node card (renders ONLY what NodeCardContent allows)

struct RadarNodeCard: View {
    let node: RadarNode
    let content: NodeCardContent
    let selected: Bool
    let live: Bool
    let onSelect: () -> Void
    let onEvidence: () -> Void

    private var chrome: Color {
        // A1_51b: branch/commit nodes use kind-based NEUTRAL chrome (never
        // a semantic claim; position encodes relationship, not color).
        guard node.kind == .worktree else {
            return node.isAnchor ? .white : Tokens.Text.tertiary
        }
        if let semantic = node.form.semantic { return semantic.color }
        // Worktree neutral material: anchors wear the white truth weight.
        return node.isAnchor ? .white : Tokens.Text.tertiary
    }

    var body: some View {
        Group {
            if !content.showsTitle {
                farDot
            } else {
                card
            }
        }
        .onTapGesture(perform: onSelect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(node.accessibilityLabel)
        .accessibilityValue(content.accessibilityValue ?? "")
        .accessibilityAddTraits(.isButton)
        .accessibilityActions {
            // The drill-down must be REACHABLE for assistive tech (law 2),
            // and only when it is actually offered - no phantom actions.
            if content.showsEvidenceAction {
                Button("查看证据", action: onEvidence)
            }
        }
    }

    /// Far mode: a glow dot is the whole node (semantic zoom hide-list).
    private var farDot: some View {
        Circle()
            .fill(chrome.opacity(node.form == .quiet && !node.isAnchor ? 0.45 : 0.9))
            .frame(width: node.isAnchor ? 14 : 9, height: node.isAnchor ? 14 : 9)
            .shadow(color: chrome.opacity(0.8), radius: 6)
            .breathing(active: live && node.form == .active)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Image(systemName: node.form.iconName)
                    .font(.system(size: node.isAnchor ? 12 : 10))
                    .foregroundStyle(chrome)
                Text(node.title)
                    .font(Tokens.Typography.mono(
                        node.isAnchor ? 14 : 12,
                        weight: node.isAnchor ? .bold : .medium))
                    .foregroundStyle(Tokens.Text.primary)
            }
            if !content.detailRows.isEmpty {
                Divider()
                ForEach(content.detailRows, id: \.0) { row in
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.0)
                            .font(Tokens.Typography.ui(10))
                            .foregroundStyle(Tokens.Text.tertiary)
                        Spacer(minLength: 12)
                        Text(row.1)
                            .font(Tokens.Typography.mono(10))
                            .foregroundStyle(Tokens.Text.secondary)
                    }
                }
            }
            if content.showsEvidenceAction {
                Button("查看证据", action: onEvidence)
                    .buttonStyle(.plain)
                    .font(Tokens.Typography.ui(11))
                    .foregroundStyle(Tokens.Text.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(minWidth: selected ? 180 : 0, alignment: .leading)
        .background(
            Tokens.Space.glassBase.opacity(node.form == .quiet && !node.isAnchor ? 0.6 : 1.0),
            in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    chrome.opacity(
                        node.form == .conflict ? 0.8
                            : node.isAnchor ? 0.5 : 0.3),
                    style: StrokeStyle(
                        lineWidth: node.isAnchor ? 1.5 : 1,
                        dash: node.form == .orphan ? [4, 3] : []))
        )
        .shadow(color: chrome.opacity(selected ? 0.5 : 0.25), radius: selected ? 10 : 5)
        .opacity(node.form == .orphan ? 0.7 : 1.0)
        .overlay(alignment: .topLeading) {
            if node.form == .conflict {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Tokens.Semantic.yellow.color)
                    .offset(x: -8, y: -8)
                    .breathing(active: live)
            }
        }
        .breathing(active: live && node.form == .active && !selected)
    }
}

// MARK: - HUD (glass zoom controls, V6 §3.3)

struct RadarHUD: View {
    let zoomIn: () -> Void
    let zoomOut: () -> Void
    let reset: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            hudButton("plus.magnifyingglass", "放大", zoomIn)
            hudButton("minus.magnifyingglass", "缩小", zoomOut)
            hudButton("scope", "回到全景", reset)
        }
        .padding(6)
        .background(Tokens.Space.glassBase, in: Capsule())
        .overlay(Capsule().stroke(Tokens.Space.glassBorder))
    }

    private func hudButton(
        _ icon: String, _ label: String, _ action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Tokens.Text.secondary)
                .frame(width: 28, height: 24)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Scroll-wheel zoom (SwiftUI has no wheel gesture on macOS; a
// local NSEvent monitor is the standard bridge. The monitor view exactly
// overlays the radar, so conversion happens INSIDE the view with AppKit's
// own convert() - no titlebar/toolbar arithmetic to get wrong (S-stage
// live-probe blocker). It never swallows events and is hit-test inert;
// headless probes have no window, so it never fires there.)

struct ScrollWheelMonitor: NSViewRepresentable {
    let onWheel: (_ deltaY: CGFloat, _ local: CGPoint) -> Void

    func makeNSView(context: Context) -> MonitorView {
        let view = MonitorView()
        view.onWheel = onWheel
        return view
    }

    func updateNSView(_ nsView: MonitorView, context: Context) {
        nsView.onWheel = onWheel
    }

    final class MonitorView: NSView {
        var onWheel: ((CGFloat, CGPoint) -> Void)?
        private var monitor: Any?

        override var isFlipped: Bool { true } // SwiftUI top-left convention

        override func hitTest(_ point: NSPoint) -> NSView? { nil } // inert

        // Install/remove strictly on window membership (deinit is
        // nonisolated under Swift 6 and may not touch this state; SwiftUI
        // always detaches the view from its window on dismantle).
        override func viewWillMove(toWindow newWindow: NSWindow?) {
            super.viewWillMove(toWindow: newWindow)
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            guard newWindow != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) {
                [weak self] event in
                if let self, let window = self.window, event.window === window {
                    let local = self.convert(event.locationInWindow, from: nil)
                    if self.bounds.contains(local) {
                        self.onWheel?(event.scrollingDeltaY, local)
                    }
                }
                return event // pass through, never swallow
            }
        }
    }
}
