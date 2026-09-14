import RealityKit
import UIKit
import simd

struct LavaZone {
    let minX: Float
    let maxX: Float
    let minZ: Float
    let maxZ: Float
    func contains(_ p: SIMD3<Float>) -> Bool {
        p.x >= minX && p.x <= maxX && p.z >= minZ && p.z <= maxZ
    }
}

enum VolcanoLayout {
    static let bridges: [Float] = [-13, -2, 10]
    static let lava: [LavaZone] = [-8.0 as Float, 8.0].map {
        LavaZone(minX: $0 - 2.8, maxX: $0 + 2.8, minZ: -22, maxZ: 20)
    }
    static func isLava(_ p: SIMD3<Float>) -> Bool {
        lava.contains { $0.contains(p) } && !bridges.contains { abs(p.z - $0) <= 2.4 }
    }
}

@MainActor
enum RetroMaterials {
    private static var textures: [Bool: TextureResource] = [:]
    static func texture(lava: Bool) -> TextureResource? {
        if let cached = textures[lava] { return cached }
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: format)
        let image = renderer.image { context in
            var seed: UInt64 = lava ? 9231 : 173
            for y in 0..<64 { for x in 0..<64 {
                seed = seed &* 6364136223846793005 &+ 1
                let grain = CGFloat((seed >> 32) % 100) / 100
                let vein = sin(Float(x) * 0.3 + sin(Float(y) * 0.4) * 3)
                let c: UIColor
                if lava {
                    let hot = abs(vein) < 0.24
                    c = UIColor(red: hot ? 1 : 0.45 + grain * 0.45,
                                green: hot ? 0.65 + grain * 0.3 : grain * 0.12,
                                blue: hot ? 0.08 : 0.015, alpha: 1)
                } else {
                    let shade = 0.3 + grain * 0.45 + (abs(vein) < 0.08 ? -0.2 : 0)
                    c = UIColor(white: shade, alpha: 1)
                }
                c.setFill(); context.fill(CGRect(x: CGFloat(x), y: CGFloat(y), width: 1, height: 1))
            } }
        }
        guard let cg = image.cgImage,
              let texture = try? TextureResource.generate(from: cg, options: .init(semantic: .color)) else { return nil }
        textures[lava] = texture
        return texture
    }

    static func stone(_ tint: UIColor) -> SimpleMaterial {
        var material = SimpleMaterial(color: tint, roughness: 1, isMetallic: false)
        if let texture = texture(lava: false) { material.color = .init(tint: tint, texture: .init(texture)) }
        return material
    }
    static func lava() -> UnlitMaterial {
        var material = UnlitMaterial(color: .orange)
        if let texture = texture(lava: true) { material.color = .init(tint: .white, texture: .init(texture)) }
        return material
    }
}

@MainActor
enum VolcanoBuilder {
    static func build(view: ARView, progress: (Double, String) async -> Void) async throws -> ArenaBuilder.Result {
        let root = AnchorEntity(world: SIMD3<Float>.zero)
        let camera = PerspectiveCamera(); camera.camera.fieldOfViewInDegrees = 78
        camera.position = [0, 1.65, 12]; root.addChild(camera); view.scene.addAnchor(root)
        view.environment.background = .color(UIColor(red: 0.24, green: 0.009, blue: 0.003, alpha: 1))
        view.environment.lighting.intensityExponent = 0.5
        view.renderOptions.formUnion([.disableMotionBlur, .disableDepthOfField, .disableCameraGrain])
        let basalt = UIColor(red: 0.25, green: 0.19, blue: 0.20, alpha: 1)
        let rock = UIColor(red: 0.40, green: 0.29, blue: 0.27, alpha: 1)
        var solids: [Solid] = []
        func stone(_ size: SIMD3<Float>, _ p: SIMD3<Float>, tint: UIColor? = nil) -> ModelEntity {
            let color = tint ?? basalt
            let model = ArenaBuilder.box(size, p, color, in: root)
            model.model?.materials = [RetroMaterials.stone(color)]
            return model
        }
        await progress(0.16, "Carving the Cinder Caldera")
        _ = stone([50, 0.7, 64], [0, -0.45, 0])
        for x in -5...5 { for z in -5...5 {
            _ = stone([3.92, 0.08, 3.92], [Float(x) * 4, -0.01, Float(z) * 4], tint: rock)
        } }
        for x: Float in [-24, 24] {
            _ = stone([1, 3, 49], [x, 1.4, 0])
            solids.append(Solid(center: [x, 1.4, 0], half: [0.5, 1.5, 24.5]))
        }
        for z: Float in [-24, 24] {
            // Leave a broad opening so the old perimeter does not cut through
            // the imported castle. Its coarse blocker closes the central gap.
            for x: Float in [-17, 17] {
                _ = stone([14, 3, 1], [x, 1.4, z])
                solids.append(Solid(center: [x, 1.4, z], half: [7, 1.5, 0.5]))
            }
        }
        await progress(0.36, "Opening rivers of molten stone")
        for zone in VolcanoLayout.lava {
            for z in stride(from: -21, through: 19, by: 2) {
                let tile = ModelEntity(mesh: .generatePlane(width: zone.maxX - zone.minX, depth: 2),
                                       materials: [RetroMaterials.lava()])
                tile.position = [(zone.minX + zone.maxX) / 2, 0.065, Float(z)]
                root.addChild(tile)
            }
        }
        for z in VolcanoLayout.bridges {
            _ = stone([25, 0.24, 4.8], [0, 0.06, z], tint: basalt)
            for edge: Float in [-2.4, 2.4] {
                _ = stone([25, 0.18, 0.18], [0, 0.23, z + edge], tint: rock)
            }
        }
        // A distant lava lake surrounds the playable paths.
        for x: Float in [-37, 37] {
            let lake = ModelEntity(mesh: .generatePlane(width: 24, depth: 95), materials: [RetroMaterials.lava()])
            lake.position = [x, -0.1, -12]; root.addChild(lake)
        }
        await progress(0.54, "Raising basalt spires and the volcano")
        for side: Float in [-1, 1] {
            for i in 0..<11 {
                let h = Float(7 + (i * 7 % 13)), x = side * Float(26 + i % 4 * 3)
                let spire = ArenaBuilder.taper(radius: 2.6, height: h, top: 0.05,
                    position: [x, h / 2, Float(i) * 7 - 40], color: basalt, in: root)
                spire.model?.materials = [RetroMaterials.stone(basalt)]
                spire.orientation = simd_quatf(angle: side * 0.12, axis: [0, 0, 1])
            }
        }
        for x: Float in [-17, 17] { for z: Float in [-17, 16] {
            let spire = ArenaBuilder.taper(radius: 1.3, height: 6, top: 0.35,
                position: [x, 3, z], color: basalt, in: root)
            spire.model?.materials = [RetroMaterials.stone(basalt)]
            solids.append(Solid(center: [x, 3, z], half: [1.3, 3, 1.3]))
        } }
        for x: Float in [-12, 12] {
            _ = stone([5, 19, 5], [x, 9, -31])
            _ = ArenaBuilder.taper(radius: 3.6, height: 8, top: 0,
                position: [x, 22, -31], color: basalt, in: root)
            for y in 4...8 {
                _ = ArenaBuilder.box([0.5, 1.4, 0.06], [x, Float(y) * 2, -28.46], .red, in: root, glowing: true)
            }
        }
        _ = stone([28, 4, 4], [0, 4, -32])
        let volcano = ArenaBuilder.taper(radius: 27, height: 26, top: 0.19,
            position: [0, 10, -72], color: basalt, in: root)
        volcano.model?.materials = [RetroMaterials.stone(basalt)]
        let crater = ModelEntity(mesh: .generatePlane(width: 10, depth: 10), materials: [RetroMaterials.lava()])
        crater.position = [0, 23.05, -72]; root.addChild(crater)
        _ = ArenaBuilder.orb(4.8, [0, 26, -72], UIColor(red: 1, green: 0.22, blue: 0.025, alpha: 1), in: root)
        _ = ArenaBuilder.orb(5, [36, 42, -88], UIColor(red: 0.9, green: 0.38, blue: 0.2, alpha: 1), in: root)
        let light = DirectionalLight(); light.light.color = UIColor(red: 1, green: 0.40, blue: 0.25, alpha: 1)
        light.light.intensity = 1700; light.look(at: .zero, from: [6, 22, -16], relativeTo: nil); root.addChild(light)
        for x: Float in [-8, 8] {
            let glow = PointLight(); glow.light.color = .orange; glow.light.intensity = 1500
            glow.light.attenuationRadius = 22; glow.position = [x, 2, -4]; root.addChild(glow)
        }
        await progress(0.73, "Binding the ashwardens")
        var targets: [Entity] = []
        for (i, p) in [SIMD3<Float>(-17, 0, -8), [0, 0, -5], [17, 0, -8], [-17, 0, 6], [17, 0, 6]].enumerated() {
            let target = Entity(); target.position = p; target.name = "ashwarden-\(i)"; root.addChild(target)
            let body = ArenaBuilder.taper(radius: 0.63, height: 1.3, top: 0.55,
                position: [0, 0.85, 0], color: basalt, in: target)
            body.scale.z *= 0.7; body.model?.materials = [RetroMaterials.stone(rock)]
            _ = ArenaBuilder.orb(0.34, [0, 1.82, 0], rock, in: target, glowing: false)
            _ = ArenaBuilder.taper(radius: 0.55, height: 0.1, top: 1, position: [0, 2.1, 0], color: basalt, in: target)
            _ = ArenaBuilder.taper(radius: 0.34, height: 0.8, top: 0, position: [0, 2.5, 0], color: rock, in: target)
            for x: Float in [-0.12, 0.12] { _ = ArenaBuilder.orb(0.045, [x, 1.85, 0.3], .orange, in: target) }
            _ = ArenaBuilder.box([1.6, 0.17, 0.3], [0, 1.3, 0], basalt, in: target)
            targets.append(target)
        }
        var wisps: [Entity] = []
        for i in 0..<48 {
            let x = sin(Float(i) * 2.4) * 19, z = cos(Float(i) * 1.7) * 21
            wisps.append(ArenaBuilder.orb(0.035, [x, 0.8 + Float(i % 7), z], .orange, in: root))
        }
        await progress(0.80, "Opening the opposing castle keeps")
        solids.append(contentsOf: try await CastleBases.install(in: root))
        return .init(root: root, camera: camera, solids: solids, targets: targets, wisps: wisps)
    }
}
