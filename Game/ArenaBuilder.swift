import RealityKit
import UIKit
import simd

@MainActor
enum ArenaBuilder {
    struct Result {
        let root: AnchorEntity
        let camera: PerspectiveCamera
        let solids: [Solid]
        let targets: [Entity]
        let wisps: [Entity]
    }

    static func stone(_ color: UIColor) -> SimpleMaterial {
        SimpleMaterial(color: color, roughness: 0.9, isMetallic: false)
    }

    static func box(_ size: SIMD3<Float>, _ position: SIMD3<Float>, _ color: UIColor,
                    in parent: Entity, glowing: Bool = false) -> ModelEntity {
        let materials: [any Material] = glowing ? [UnlitMaterial(color: color)] : [stone(color)]
        let entity = ModelEntity(mesh: .generateBox(size: size), materials: materials)
        entity.position = position; parent.addChild(entity)
        return entity
    }

    static func orb(_ radius: Float, _ position: SIMD3<Float>, _ color: UIColor,
                    in parent: Entity, glowing: Bool = true) -> ModelEntity {
        let materials: [any Material] = glowing ? [UnlitMaterial(color: color)] : [stone(color)]
        let entity = ModelEntity(mesh: .generateSphere(radius: radius), materials: materials)
        entity.position = position; parent.addChild(entity)
        return entity
    }

    static func build(view: ARView, progress: (Double, String) async -> Void) async -> Result {
        let root = AnchorEntity(world: SIMD3<Float>.zero)
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 78
        camera.position = [0, 1.65, 12]
        root.addChild(camera)
        view.scene.addAnchor(root)
        view.environment.background = .color(UIColor(red: 0.018, green: 0.022, blue: 0.06, alpha: 1))
        view.environment.lighting.intensityExponent = 1.1
        view.renderOptions.insert(.disableMotionBlur)
        view.renderOptions.insert(.disableDepthOfField)
        view.renderOptions.insert(.disableCameraGrain)
        var solids: [Solid] = []
        let base = UIColor(red: 0.13, green: 0.15, blue: 0.23, alpha: 1)
        let edge = UIColor(red: 0.20, green: 0.21, blue: 0.31, alpha: 1)
        let purple = UIColor(red: 0.45, green: 0.23, blue: 0.83, alpha: 1)

        await progress(0.18, "Laying the obsidian court")
        _ = box([50, 0.8, 50], [0, -0.45, 0], base, in: root)
        // Sparse stone slab pattern; the visible arena is actual geometry.
        for x in -5...5 {
            for z in -5...5 {
                let shade = Float((abs(x * 17 + z * 7) % 5)) * 0.007
                let c = UIColor(red: CGFloat(0.16 + shade), green: CGFloat(0.17 + shade), blue: CGFloat(0.24 + shade), alpha: 1)
                _ = box([3.94, 0.05, 3.94], [Float(x) * 4, -0.015, Float(z) * 4], c, in: root)
            }
        }
        for x: Float in [-24, 24] {
            _ = box([1, 2.5, 49], [x, 1.1, 0], base, in: root)
            solids.append(Solid(center: [x, 1.1, 0], half: [0.5, 1.25, 24.5]))
        }
        for z: Float in [-24, 24] {
            _ = box([49, 2.5, 1], [0, 1.1, z], base, in: root)
            solids.append(Solid(center: [0, 1.1, z], half: [24.5, 1.25, 0.5]))
        }

        await progress(0.38, "Raising the forgotten towers")
        for x: Float in [-17, -9, 9, 17] {
            for z: Float in [-17, 3, 17] {
                let height: Float = (z == -17) ? 7.6 : 4.7
                _ = box([1.8, height, 1.8], [x, height / 2, z], base, in: root)
                _ = box([2.3, 0.4, 2.3], [x, height, z], edge, in: root)
                _ = box([2.3, 0.45, 2.3], [x, 0.2, z], edge, in: root)
                _ = box([0.10, height * 0.65, 0.03], [x, height * 0.5, z + 0.92], purple, in: root, glowing: true)
                solids.append(Solid(center: [x, height / 2, z], half: [1.15, height / 2, 1.15]))
                _ = orb(0.15, [x, height + 0.5, z], purple, in: root)
            }
        }
        // Front gothic arch; individual wedges form the arch crown.
        for x: Float in [-4.5, 4.5] {
            _ = box([1.1, 6.2, 1.7], [x, 3.1, -20], edge, in: root)
            solids.append(Solid(center: [x, 3.1, -20], half: [0.55, 3.1, 0.85]))
        }
        for i in 0...16 {
            let a = Float(i) / 16 * Float.pi
            let arch = box([0.9, 0.65, 1.7], [cos(a) * 4.5, 6.1 + sin(a) * 4.8, -20], edge, in: root)
            arch.orientation = simd_quatf(angle: a + .pi / 2, axis: [0, 0, 1])
        }
        for i in 0..<20 { // Far skyline silhouettes, outside playable bounds.
            let x = Float(i - 10) * 6
            let h = Float(9 + abs(i * 13 % 15))
            _ = box([3.5, h, 4], [x, h / 2 - 3, -45 - Float(i % 3) * 5],
                    UIColor(red: 0.065, green: 0.07, blue: 0.12, alpha: 1), in: root)
            let cap = box([3, 3, 3], [x, h - 2, -45 - Float(i % 3) * 5], base, in: root)
            cap.orientation = simd_quatf(angle: .pi / 4, axis: [0, 0, 1])
        }

        await progress(0.58, "Calling the moon and constellations")
        let moonPosition = SIMD3<Float>(55, 58, -95)
        _ = orb(8, moonPosition, UIColor(red: 0.86, green: 0.9, blue: 1, alpha: 1), in: root)
        // Low-contrast crater marks are actual small spheres, tucked into the moon face.
        for i in 0..<13 {
            let x = sin(Float(i) * 2.4) * 4.5
            let y = cos(Float(i) * 1.9) * 4.3
            _ = orb(Float(0.4 + Double(i % 4) * 0.2), moonPosition + [x, y, 6.6],
                    UIColor(red: 0.70, green: 0.75, blue: 0.88, alpha: 1), in: root)
        }
        var random: UInt64 = 8417
        func next() -> Float {
            random = random &* 6364136223846793005 &+ 1
            return Float((random >> 32) % 10000) / 10000
        }
        let starMesh = MeshResource.generateSphere(radius: 0.11)
        let starMaterial = UnlitMaterial(color: UIColor(red: 0.7, green: 0.78, blue: 1, alpha: 1))
        for _ in 0..<240 {
            let theta = next() * .pi * 2, height = next() * 0.85 + 0.12
            let radius: Float = 145
            let radial = sqrt(1 - height * height)
            let star = ModelEntity(mesh: starMesh, materials: [starMaterial])
            star.position = [sin(theta) * radial * radius, height * radius, cos(theta) * radial * radius]
            star.scale = SIMD3(repeating: 0.7 + next() * 1.5)
            root.addChild(star)
        }
        let moonlight = DirectionalLight()
        moonlight.light.color = UIColor(red: 0.65, green: 0.72, blue: 1, alpha: 1)
        moonlight.light.intensity = 2600
        moonlight.look(at: .zero, from: [18, 28, -22], relativeTo: nil)
        root.addChild(moonlight)
        for x: Float in [-7, 7] {
            let light = PointLight()
            light.light.color = purple
            light.light.intensity = 900
            light.light.attenuationRadius = 13
            light.position = [x, 2.5, -5]
            root.addChild(light)
        }

        await progress(0.74, "Binding the practice sentinels")
        var targets: [Entity] = []
        for (i, p) in [SIMD3<Float>(-6, 0, -7), [0, 0, -12], [6, 0, -7], [-12, 0, -12], [12, 0, -12]].enumerated() {
            let target = Entity(); target.position = p; target.name = "sentinel-\(i)"
            root.addChild(target)
            _ = box([0.9, 1.25, 0.55], [0, 0.9, 0], UIColor(red: 0.19, green: 0.13, blue: 0.27, alpha: 1), in: target)
            _ = orb(0.36, [0, 1.85, 0], UIColor(red: 0.17, green: 0.14, blue: 0.23, alpha: 1), in: target, glowing: false)
            for eye: Float in [-0.12, 0.12] { _ = orb(0.045, [eye, 1.88, 0.32], .cyan, in: target) }
            _ = orb(0.12, [0, 1.0, 0.32], purple, in: target)
            let arms = box([1.7, 0.18, 0.3], [0, 1.35, 0], base, in: target)
            arms.orientation = simd_quatf(angle: 0.12, axis: [0, 0, 1])
            _ = box([1.5, 0.12, 1.5], [0, 0.02, 0], edge, in: target)
            targets.append(target)
        }
        var wisps: [Entity] = []
        for _ in 0..<28 {
            wisps.append(orb(0.026, [(next() - 0.5) * 40, 0.4 + next() * 4, (next() - 0.5) * 40], purple, in: root))
        }
        return Result(root: root, camera: camera, solids: solids, targets: targets, wisps: wisps)
    }
}
