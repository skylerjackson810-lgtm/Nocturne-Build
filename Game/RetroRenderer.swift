import RealityKit
import Metal
import Foundation
import simd

// Nonisolated callback object: RealityKit invokes render() on its rendering thread.
final class RetroRenderer: @unchecked Sendable {
    private let lock = NSLock()
    private var cameraToWorld = matrix_identity_float4x4
    private var pipelines: [String: any MTLRenderPipelineState] = [:]
    private var reportedFailure = false
    private let onFailure: @Sendable (String) -> Void
    private let fog: SIMD4<Float>
    private struct Uniforms {
        var inverseProjection: simd_float4x4
        var cameraToWorld: simd_float4x4
        var fog: SIMD4<Float>
        var style: SIMD4<Float>
        var viewport: SIMD4<Float>
    }

    init(map: MapID, onFailure: @escaping @Sendable (String) -> Void) {
        self.onFailure = onFailure
        fog = map == .volcano ? [0.24, 0.009, 0.003, 0.047] : [0.013, 0.025, 0.065, 0.025]
    }

    func update(camera: simd_float4x4) {
        lock.lock(); cameraToWorld = camera; lock.unlock()
    }

    private func pipeline(context: ARView.PostProcessContext, fragment: String) throws -> any MTLRenderPipelineState {
        let key = "\(context.device.registryID):\(context.targetColorTexture.pixelFormat.rawValue):\(context.targetColorTexture.sampleCount):\(fragment)"
        if let cached = pipelines[key] { return cached }
        guard let library = context.device.makeDefaultLibrary(),
              let vertex = library.makeFunction(name: "nocturneFullscreen"),
              let shader = library.makeFunction(name: fragment) else {
            throw NSError(domain: "NocturneGraphics", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "The compiled volcano shaders are missing."])
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertex; descriptor.fragmentFunction = shader
        descriptor.colorAttachments[0].pixelFormat = context.targetColorTexture.pixelFormat
        descriptor.rasterSampleCount = context.targetColorTexture.sampleCount
        let state = try context.device.makeRenderPipelineState(descriptor: descriptor)
        pipelines[key] = state
        return state
    }

    func render(_ context: ARView.PostProcessContext) {
        lock.lock(); defer { lock.unlock() }
        let target = context.targetColorTexture
        guard target.usage.isEmpty || target.usage.contains(.renderTarget) else {
            report("RealityKit output is not a render attachment. Retro effects disabled.")
            return
        }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: Double(fog.x), green: Double(fog.y), blue: Double(fog.z), alpha: 1)
        // Rendering to the native attachment supports sRGB/XR formats and requires
        // neither a pixel-format view nor compute shader-write access on the target.
        guard let encoder = context.commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
            report("RealityKit could not create the volcano render pass."); return
        }
        defer { encoder.endEncoding() }
        guard context.sourceColorTexture.textureType == .type2D else {
            report("Unsupported RealityKit color texture type. Retro effects disabled."); return
        }
        let depth = context.sourceDepthTexture
        let nativeDepth: Bool
        switch depth.pixelFormat {
        case .depth32Float, .depth16Unorm, .depth32Float_stencil8: nativeDepth = true
        default: nativeDepth = false
        }
        let supportedDepth = depth.textureType == .type2D &&
            (nativeDepth || depth.pixelFormat == .r32Float || depth.pixelFormat == .r16Float)
        let shader = supportedDepth ? (nativeDepth ? "nocturneRetroDepth" : "nocturneRetroColorDepth") : "nocturneCopy"
        do {
            let state = try pipeline(context: context, fragment: shader)
            var uniforms = Uniforms(inverseProjection: simd_inverse(context.projection), cameraToWorld: cameraToWorld,
                fog: fog, style: [640, 0, 0, 4],
                viewport: [Float(target.width), Float(target.height), 0, 0])
            encoder.setRenderPipelineState(state)
            encoder.setCullMode(.none)
            encoder.setFragmentTexture(context.sourceColorTexture, index: 0)
            if supportedDepth { encoder.setFragmentTexture(depth, index: 1) }
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            let failure = onFailure
            context.commandBuffer.addCompletedHandler { buffer in
                if buffer.status == .error {
                    failure("Volcano GPU work failed: \(buffer.error?.localizedDescription ?? "unknown Metal error"). Retro effects disabled.")
                }
            }
            if !supportedDepth { report("Unsupported RealityKit depth format. Retro effects disabled.") }
        } catch { report("Retro rendering unavailable: \(error.localizedDescription)") }
    }

    private func report(_ message: String) {
        guard !reportedFailure else { return }
        reportedFailure = true
        onFailure(message)
    }
}
