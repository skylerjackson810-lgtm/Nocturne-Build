import RealityKit
import UIKit
import simd

// Reusable indexed surfaces. Winding is explicit, never guessed from the world origin.
struct SceneSurface {
    var points: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var uv: [SIMD2<Float>] = []
    var indices: [UInt32] = []

    mutating func triangle(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>,
                           uvScale: Float = 0.18) {
        let cross = simd_cross(b - a, c - a)
        guard simd_length_squared(cross) > 0.00000001 else { return }
        let normal = simd_normalize(cross), start = UInt32(points.count)
        points.append(contentsOf: [a, b, c]); normals.append(contentsOf: [normal, normal, normal])
        uv.append(contentsOf: [a, b, c].map { SIMD2($0.x, $0.z) * uvScale })
        indices.append(contentsOf: [start, start + 1, start + 2])
    }

    @MainActor func resource(_ name: String) throws -> MeshResource {
        var descriptor = MeshDescriptor(name: name)
        descriptor.positions = MeshBuffers.Positions(points)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(uv)
        descriptor.primitives = .triangles(indices)
        return try MeshResource.generate(from: [descriptor])
    }
}

@MainActor
enum SceneDetail {
    private static var materials: [String: SimpleMaterial] = [:]
    private static var roundedMeshes: [String: MeshResource] = [:]
    static func stone(_ tint: UIColor = .white) -> SimpleMaterial {
        var material: SimpleMaterial
        if let cached = materials["rock"] { material = cached }
        else {
            material = SimpleMaterial(color: .white, roughness: 0.95, isMetallic: false)
            if let texture = try? TextureResource.load(named: "TerrainRock.jpg") {
                material.color = .init(tint: .white, texture: .init(texture))
            }
            materials["rock"] = material
        }
        material.color.tint = tint
        return material
    }

    @discardableResult
    static func rounded(_ size: SIMD3<Float>, at p: SIMD3<Float>, material: any Material,
                        parent: Entity, radius: Float = 0.01) -> ModelEntity {
        let key = "\(size)-\(radius)"
        let mesh: MeshResource
        if let cached = roundedMeshes[key] { mesh = cached }
        else { mesh = .generateBox(size: size, cornerRadius: radius); roundedMeshes[key] = mesh }
        let model = ModelEntity(mesh: mesh, materials: [material])
        model.position = p; parent.addChild(model); return model
    }

    @discardableResult
    static func ellipsoid(_ size: SIMD3<Float>, at p: SIMD3<Float>, material: any Material,
                          parent: Entity) -> ModelEntity {
        let model = ModelEntity(mesh: sphere, materials: [material])
        model.position = p; model.scale = size; parent.addChild(model); return model
    }
    private static let sphere = MeshResource.generateSphere(radius: 1)

    // Tailored sleeve, with radial cloth folds and a tapered wrist opening.
    static func sleeve(material: any Material, parent: Entity) throws {
        var surface = SceneSurface()
        let rings = 12, sides = 24
        for ring in 0..<rings {
            let t = Float(ring) / Float(rings - 1), z = 0.045 + t * 0.32
            for side in 0..<sides {
                let angle = Float(side) * 2 * Float.pi / Float(sides)
                let fold = 1 + 0.065 * cos(angle * 8 + t * 3)
                let radius = (0.061 + t * 0.048) * fold
                surface.points.append([cos(angle) * radius, -0.03 + sin(angle) * radius * 0.85, z])
                surface.normals.append(simd_normalize([cos(angle), sin(angle) / 0.85, -0.14]))
                surface.uv.append([Float(side) / Float(sides), t])
            }
        }
        for ring in 0..<(rings - 1) { for side in 0..<sides {
            let a = UInt32(ring * sides + side), b = UInt32(ring * sides + (side + 1) % sides)
            surface.indices.append(contentsOf: [a, b, a + UInt32(sides), b, b + UInt32(sides), a + UInt32(sides)])
        } }
        let model = ModelEntity(mesh: try surface.resource("Tailored robe sleeve"), materials: [material])
        parent.addChild(model)
    }

    // A faceted boulder with layered, uneven shoulders, rather than a stretched cone.
    static func rockGeometry(seed: Int) -> SceneSurface {
        var surface = SceneSurface()
        func p(_ ring: Int, _ side: Int) -> SIMD3<Float> {
            let a = Float(side % 10) * 2 * Float.pi / 10
            let shape: [Float] = [0.80, 1, 0.79, 0.27]
            let ripple = 1 + 0.18 * sin(Float(side * 13 + ring * 7 + seed))
            return [cos(a) * shape[ring] * ripple, Float(ring) * 0.6 - 0.25 + 0.12 * sin(Float(side + seed)), sin(a) * shape[ring] * ripple]
        }
        for ring in 0..<3 { for side in 0..<10 {
            surface.triangle(p(ring, side), p(ring + 1, side), p(ring, side + 1))
            surface.triangle(p(ring, side + 1), p(ring + 1, side), p(ring + 1, side + 1))
        } }
        for side in 0..<10 { surface.triangle(p(3, side), [0, 1.65, 0], p(3, side + 1)) }
        return surface
    }
}
