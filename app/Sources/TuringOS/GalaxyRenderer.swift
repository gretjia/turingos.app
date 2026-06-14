// GalaxyRenderer.swift — Metal instanced renderer for the galaxy (A1_51c)
//
// Instanced rendering of the dense visual layer (stars / node dots / edges /
// commit swimlane points) via ONE drawIndexedPrimitive(instanceCount:).
// Shader compiled inline via device.makeLibrary(source:) — NO .metal resource
// file, NO Package.swift change.
//
// Fail-safe: MTLCreateSystemDefaultDevice() == nil (headless / probe)
//   → Coordinator.device is nil → draw() is a no-op
//   → makeNSView returns an NSHostingView(GalaxyFallbackView)
//   → no crash, no black screen, probe exits 0.
//
// macOS-27-only API: lives exclusively in GalaxyRenderer27.swift; called only
// inside `if #available(macOS 27, *)` blocks in this file.

import AppKit
import MetalKit
import SwiftUI

// MARK: - Inline Metal shader source (MSL 2.0)

/// Compiled at runtime via device.makeLibrary(source:).
/// One quad per instance; shader positions it at instance.center in NDC.
private let galaxyShaderSource: String = """
#include <metal_stdlib>
using namespace metal;

struct InstanceData {
    float2 center;
    float4 color;
    float  size;
    uint   kind;
};

struct VertexIn {
    float2 localPos [[attribute(0)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

vertex VertexOut galaxy_vertex(
    VertexIn               in         [[stage_in]],
    constant InstanceData* instances  [[buffer(1)]],
    uint                   instanceId [[instance_id]]
) {
    InstanceData inst = instances[instanceId];
    float2 pos = inst.center + in.localPos * inst.size;
    VertexOut out;
    out.position = float4(pos, 0.0, 1.0);
    out.color    = inst.color;
    return out;
}

fragment float4 galaxy_fragment(VertexOut in [[stage_in]]) {
    return in.color;
}
"""

// MARK: - Per-instance GPU layout

// Note: Float is required here for the GPU buffer layout (Metal uses float32).
// This file is intentionally excluded from the Float/Float32 audit applied to
// RadarModel.swift and RadarViews.swift by the Float32 test.
private struct GalaxyInstanceData {
    var centerX: Float
    var centerY: Float
    var colorR: Float
    var colorG: Float
    var colorB: Float
    var colorA: Float
    var size: Float
    var kind: UInt32
}

// MARK: - Coordinator (MTKViewDelegate)

extension GalaxyRenderer {
    final class Coordinator: NSObject, MTKViewDelegate, @unchecked Sendable {
        // nil when headless (MTLCreateSystemDefaultDevice() returned nil).
        let device: MTLDevice?
        var scene: RadarScene
        var camera: RadarCamera
        var mood: RadarMood

        private var commandQueue: MTLCommandQueue?
        private var pipelineState: MTLRenderPipelineState?
        private var vertexBuffer: MTLBuffer?
        private var indexBuffer: MTLBuffer?
        private var instanceBuffer: MTLBuffer?
        private var instanceCapacity: Int = 0

        init(device: MTLDevice?, scene: RadarScene, camera: RadarCamera, mood: RadarMood) {
            self.device = device
            self.scene  = scene
            self.camera = camera
            self.mood   = mood
            super.init()
            guard let device else { return }
            commandQueue = device.makeCommandQueue()
            buildPipeline(device: device)
            buildQuadMesh(device: device)
        }

        // MARK: Pipeline

        private func buildPipeline(device: MTLDevice) {
            do {
                let library = try device.makeLibrary(source: galaxyShaderSource, options: nil)
                let desc = MTLRenderPipelineDescriptor()
                desc.vertexFunction   = library.makeFunction(name: "galaxy_vertex")
                desc.fragmentFunction = library.makeFunction(name: "galaxy_fragment")
                desc.colorAttachments[0].pixelFormat = .bgra8Unorm
                // Alpha blending for nebula / cross-fades.
                let ca = desc.colorAttachments[0]!
                ca.isBlendingEnabled             = true
                ca.sourceRGBBlendFactor          = .sourceAlpha
                ca.destinationRGBBlendFactor     = .oneMinusSourceAlpha
                ca.sourceAlphaBlendFactor        = .one
                ca.destinationAlphaBlendFactor   = .oneMinusSourceAlpha

                let vd = MTLVertexDescriptor()
                vd.attributes[0].format     = .float2
                vd.attributes[0].offset     = 0
                vd.attributes[0].bufferIndex = 0
                vd.layouts[0].stride        = MemoryLayout<Float>.stride * 2
                desc.vertexDescriptor = vd

                pipelineState = try device.makeRenderPipelineState(descriptor: desc)
            } catch {
                // Shader compile failure → no-op draws (fail-visible, not crash).
                NSLog("GalaxyRenderer: shader compile error: \(error)")
                pipelineState = nil
            }
        }

        // MARK: Quad mesh (unit quad centred at origin, two triangles)

        private func buildQuadMesh(device: MTLDevice) {
            // 4 vertices × (x,y) in [-1,+1] → scaled by inst.size in NDC-delta space.
            let verts: [Float] = [-1, -1, 1, -1, 1, 1, -1, 1]
            let idxs: [UInt16] = [0, 1, 2, 0, 2, 3]
            vertexBuffer = device.makeBuffer(
                bytes: verts, length: verts.count * MemoryLayout<Float>.stride,
                options: .storageModeShared)
            indexBuffer = device.makeBuffer(
                bytes: idxs, length: idxs.count * MemoryLayout<UInt16>.stride,
                options: .storageModeShared)
        }

        // MARK: Instance data construction

        private func buildInstances(viewportSize: CGSize) -> [GalaxyInstanceData] {
            var out: [GalaxyInstanceData] = []
            out.reserveCapacity(Tokens.LOD.instanceBatchSize)

            let grayMul: Float = mood.live ? 1.0 : 0.0
            let viewW = Double(viewportSize.width)
            let viewH = Double(viewportSize.height)
            guard viewW > 0, viewH > 0 else { return out }

            // 1. Background star grid.
            let spacing = Double(Tokens.Space.starGridSpacing)
            let stepsX = Int(viewW / spacing) + 2
            let stepsY = Int(viewH / spacing) + 2
            for iy in 0..<stepsY {
                for ix in 0..<stepsX {
                    guard out.count < Tokens.LOD.instanceBatchSize else { break }
                    let sx = (Double(ix) + 0.5) * spacing
                    let sy = (Double(iy) + 0.5) * spacing
                    let ndcX = Float(sx / viewW * 2.0 - 1.0)
                    let ndcY = Float(1.0 - sy / viewH * 2.0)
                    out.append(GalaxyInstanceData(
                        centerX: ndcX, centerY: ndcY,
                        colorR: 0.9 * grayMul, colorG: 0.9 * grayMul,
                        colorB: 0.95 * grayMul, colorA: 0.07,
                        size: 0.0015, kind: 0))
                }
            }

            // 2. Node dots (near and far).
            for node in scene.nodes {
                guard out.count < Tokens.LOD.instanceBatchSize else { break }
                guard let worldPos = scene.positions[node.id] else { continue }
                let screenPt = camera.toScreen(worldPos)
                // Viewport cull (50pt margin).
                if screenPt.x < -50 || screenPt.x > Double(viewportSize.width) + 50 { continue }
                if screenPt.y < -50 || screenPt.y > Double(viewportSize.height) + 50 { continue }

                let ndcX = Float(screenPt.x / viewW * 2.0 - 1.0)
                let ndcY = Float(1.0 - screenPt.y / viewH * 2.0)

                var r: Float = grayMul; var g = r; var b = r
                var a: Float = node.isAnchor ? 0.9 : 0.45
                if node.kind == .worktree, let sem = node.form.semantic {
                    let h = sem.hex
                    r = Float((h >> 16) & 0xFF) / 255.0 * grayMul
                    g = Float((h >>  8) & 0xFF) / 255.0 * grayMul
                    b = Float( h        & 0xFF) / 255.0 * grayMul
                    a = 0.9
                }
                let dotPx: Double = node.isAnchor ? 14.0 : 9.0
                let size = Float(dotPx / viewW * camera.z.clamped(1.0, 4.0))
                out.append(GalaxyInstanceData(
                    centerX: ndcX, centerY: ndcY,
                    colorR: r, colorG: g, colorB: b, colorA: a,
                    size: size, kind: 1))
            }

            // 3. Edge midpoint quads (thin elongated) — only in node/detail band.
            let band = camera.currentBand()
            if band == .node || band == .detail {
                for edge in scene.edges {
                    guard out.count + 1 < Tokens.LOD.instanceBatchSize else { break }
                    guard let fw = scene.positions[edge.from],
                          let tw = scene.positions[edge.to] else { continue }
                    let fs = camera.toScreen(fw); let ts = camera.toScreen(tw)
                    let mx = Float((fs.x + ts.x) / 2.0 / viewW * 2.0 - 1.0)
                    let my = Float(1.0 - (fs.y + ts.y) / 2.0 / viewH * 2.0)
                    let lenNDC = Float(hypot(ts.x - fs.x, ts.y - fs.y) / viewW)
                    let edgeA: Float
                    switch edge.kind {
                    case .conflictTension: edgeA = 0.7
                    case .membership: edgeA = 0.18
                    case .fork: edgeA = 0.12
                    case .parent: edgeA = 0.08
                    }
                    out.append(GalaxyInstanceData(
                        centerX: mx, centerY: my,
                        colorR: grayMul, colorG: grayMul, colorB: grayMul,
                        colorA: edgeA, size: lenNDC * 0.5, kind: 2))
                }
            }

            return out
        }

        // MARK: MTKViewDelegate

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            // Headless / no-pipeline → no-op (fail-safe, not a crash).
            guard let device, let commandQueue, let pipelineState,
                  let drawable = view.currentDrawable,
                  let passDesc = view.currentRenderPassDescriptor,
                  let vb = vertexBuffer, let ib = indexBuffer else { return }

            let viewSize = view.drawableSize
            let instances = buildInstances(viewportSize: viewSize)

            // Grow instance buffer if needed.
            let needed = max(instances.count * MemoryLayout<GalaxyInstanceData>.stride, 64)
            if instanceBuffer == nil || (instanceBuffer?.length ?? 0) < needed {
                instanceBuffer = device.makeBuffer(length: needed, options: .storageModeShared)
            }
            guard let instBuf = instanceBuffer else { return }
            if !instances.isEmpty {
                instBuf.contents().copyMemory(from: instances,
                    byteCount: instances.count * MemoryLayout<GalaxyInstanceData>.stride)
            }

            passDesc.colorAttachments[0].clearColor = MTLClearColorMake(0.012, 0.012, 0.020, 1.0)
            passDesc.colorAttachments[0].loadAction  = .clear
            passDesc.colorAttachments[0].storeAction = .store

            guard let cmdBuf = commandQueue.makeCommandBuffer() else { return }

            // macOS-27-only configuration (source-isolated in GalaxyRenderer27.swift).
            if #available(macOS 27, *) { configureCommandBufferForMacOS27(cmdBuf) }

            guard let enc = cmdBuf.makeRenderCommandEncoder(descriptor: passDesc) else {
                cmdBuf.commit(); return
            }
            enc.setRenderPipelineState(pipelineState)
            enc.setVertexBuffer(vb, offset: 0, index: 0)
            enc.setVertexBuffer(instBuf, offset: 0, index: 1)

            if !instances.isEmpty {
                enc.drawIndexedPrimitives(
                    type: .triangle, indexCount: 6, indexType: .uint16,
                    indexBuffer: ib, indexBufferOffset: 0,
                    instanceCount: instances.count)
            }
            enc.endEncoding()
            cmdBuf.present(drawable)
            cmdBuf.commit()
        }
    }
}

// MARK: - Double clamping helper (avoids importing Foundation just for clamp)

extension Double {
    fileprivate func clamped(_ lo: Double, _ hi: Double) -> Double {
        max(lo, min(hi, self))
    }
}

// MARK: - GalaxyRenderer: NSViewRepresentable

/// Metal MTKView for the galaxy's dense instanced visual layer.
/// Fail-safe: coordinator.device == nil → returns GalaxyFallbackView (no crash).
struct GalaxyRenderer: NSViewRepresentable {
    let scene: RadarScene
    let camera: RadarCamera
    let mood: RadarMood

    func makeCoordinator() -> Coordinator {
        Coordinator(
            device: MTLCreateSystemDefaultDevice(),
            scene: scene, camera: camera, mood: mood)
    }

    func makeNSView(context: Context) -> NSView {
        guard let device = context.coordinator.device else {
            // Headless fail-safe: a plain Canvas placeholder (no GPU).
            let fallback = NSHostingView(rootView: GalaxyFallbackView())
            fallback.setAccessibilityElement(false)
            return fallback
        }
        let mtkView = MTKView(frame: .zero, device: device)
        mtkView.delegate = context.coordinator
        mtkView.clearColor = MTLClearColorMake(0.012, 0.012, 0.020, 1.0)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.preferredFramesPerSecond = 30
        mtkView.setAccessibilityElement(false) // a11y is the SwiftUI overlay
        return mtkView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.scene  = scene
        context.coordinator.camera = camera
        context.coordinator.mood   = mood
        // NSHostingView (fallback) has no update needed.
        if let mtk = nsView as? MTKView { mtk.setNeedsDisplay(mtk.bounds) }
    }
}

// MARK: - Fallback view (headless / no GPU)

/// Shown instead of Metal when MTLCreateSystemDefaultDevice() returns nil.
/// Does NOT claim to be a rendered galaxy (fail-visible, not black screen).
struct GalaxyFallbackView: View {
    var body: some View {
        ZStack {
            Tokens.Space.background
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 24))
                    .foregroundStyle(Tokens.Text.secondary)
                Text("Metal 不可用 — 降级模式")
                    .font(Tokens.Typography.ui(12))
                    .foregroundStyle(Tokens.Text.secondary)
            }
        }
        .accessibilityLabel("galaxy renderer degraded: Metal not available")
    }
}
