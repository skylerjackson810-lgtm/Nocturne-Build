import RealityKit
import Metal
import Foundation
import simd

// Immutable GPU pipeline; only the camera snapshot crosses the render/main threads.
final class RetroRenderer: @unchecked Sendable {
    private let pipeline: any MTLComputePipelineState
    private let lock = NSLock()
    private var cameraToWorld = matrix_identity_float4x4
    private let fog: SIMD4<Float>
    private struct Uniforms {
        var inverseProjection: simd_float4x4
        var cameraToWorld: simd_float4x4
        var fog: SIMD4<Float>
        var style: SIMD4<Float> // logical width, elapsed seconds, sRGB target, fog start
    }

    enum Failure: LocalizedError {
        case missingShader
        var errorDescription: String? { "The retro Metal shader is missing. Rebuild using the included Xcode project." }
    }

    init(map: MapID) throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let function = device.makeDefaultLibrary()?.makeFunction(name: "nocturneRetro") else {
            throw Failure.missingShader
        }
        pipeline = try device.makeComputePipelineState(function: function)
        fog = map == .volcano ? [0.24, 0.009, 0.003, 0.047] : [0.013, 0.025, 0.065, 0.025]
    }

    func update(camera: simd_float4x4) {
        lock.lock(); cameraToWorld = camera; lock.unlock()
    }

    func render(_ context: ARView.PostProcessContext) {
        let target = context.targetColorTexture
        let isSRGB = target.pixelFormat == .bgra8Unorm_srgb || target.pixelFormat == .rgba8Unorm_srgb
        let format: MTLPixelFormat = target.pixelFormat == .bgra8Unorm_srgb ? .bgra8Unorm : .rgba8Unorm
        // sRGB textures cannot be shader-write destinations; use their linear view.
        guard let writable = isSRGB ? target.makeTextureView(pixelFormat: format) : target,
              let encoder = context.commandBuffer.makeComputeCommandEncoder() else {
            let blit = context.commandBuffer.makeBlitCommandEncoder()
            blit?.copy(from: context.sourceColorTexture, to: target); blit?.endEncoding()
            return
        }
        lock.lock(); let camera = cameraToWorld; lock.unlock()
        var uniforms = Uniforms(inverseProjection: simd_inverse(context.projection), cameraToWorld: camera,
            fog: fog, style: [640, Float(context.time), isSRGB ? 1 : 0, 4])
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(context.sourceColorTexture, index: 0)
        encoder.setTexture(context.sourceDepthTexture, index: 1)
        encoder.setTexture(writable, index: 2)
        encoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        let width = pipeline.threadExecutionWidth
        let height = min(8, max(1, pipeline.maxTotalThreadsPerThreadgroup / width))
        encoder.dispatchThreads(MTLSize(width: target.width, height: target.height, depth: 1),
                                threadsPerThreadgroup: MTLSize(width: width, height: height, depth: 1))
        encoder.endEncoding()
    }
}
