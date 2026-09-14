import RealityKit
import UIKit
import simd

enum VolcanoLayout {
    static let boundary: Float = 52
    static let bridges: [Float] = [-22, 0, 22]
    static func riverX(_ z: Float, side: Float) -> Float { side * (15 + sin(z * 0.09) * 2.6) }
    static func isLava(_ p: SIMD3<Float>) -> Bool {
        guard abs(p.z) < 30, !bridges.contains(where: { abs(p.z - $0) <= 2.8 }) else { return false }
        return [-1 as Float, 1].contains { abs(p.x - riverX(p.z, side: $0)) < 3.4 }
    }
}

@MainActor
enum VolcanoBuilder {
    private static var lavaTexture: TextureResource?
    private static func molten() -> UnlitMaterial {
        if lavaTexture == nil {
            let format = UIGraphicsImageRendererFormat(); format.scale = 1
            let image = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256), format: format).image { context in
                for y in 0..<256 { for x in 0..<256 {
                    let u = Float(x) / 256 * 2 * Float.pi, v = Float(y) / 256 * 2 * Float.pi
                    let field = sin(u * 3 + 1.6 * sin(v * 2)) + 0.45 * sin(v * 5 + cos(u * 4))
                    let heat = 0.15 + 0.8 * exp(-abs(field) * 9)
                    UIColor(red: CGFloat(0.17 + heat * 0.80), green: CGFloat(0.028 + pow(heat, 2) * 0.43),
                            blue: CGFloat(0.012 + pow(heat, 4) * 0.09), alpha: 1).setFill()
                    context.fill(CGRect(x: CGFloat(x), y: CGFloat(y), width: 1, height: 1))
                } }
            }
            if let cg = image.cgImage { lavaTexture = try? TextureResource.generate(from: cg, options: .init(semantic: .color)) }
        }
        var material = UnlitMaterial(color: .orange)
        if let lavaTexture { material.color = .init(tint: .white, texture: .init(lavaTexture)) }
        return material
    }

    static func build(view: ARView, progress: (Double, String) async -> Void) async throws -> ArenaBuilder.Result {
        let root = AnchorEntity(world: SIMD3<Float>.zero), camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 74
        camera.position = [0, 1.65, 34.5]; root.addChild(camera); view.scene.addAnchor(root)
        view.environment.background = .color(UIColor(red: 0.009, green: 0.014, blue: 0.034, alpha: 1))
        view.environment.lighting.intensityExponent = 1.2
        view.renderOptions.formUnion([.disableMotionBlur, .disableDepthOfField, .disableCameraGrain])
        let basalt = UIColor(red: 0.42, green: 0.43, blue: 0.49, alpha: 1)
        let rockMaterial = SceneDetail.stone(basalt), weathered = SceneDetail.stone(UIColor(white: 0.68, alpha: 1))
        let lava = molten()
        var solids: [Solid] = []
        await progress(0.12, "Shaping the volcanic valley")
        var ground = SceneSurface()
        func point(_ x: Int, _ z: Int) -> SIMD3<Float> {
            let x = Float(x), z = Float(z)
            let rise = max(0, abs(x) - 53) * 0.2 + max(0, abs(z) - 82) * 0.15
            return [x, -0.08 + rise * (0.7 + 0.3 * sin(x * 0.19) * cos(z * 0.21)), z]
        }
        for x in stride(from: -100, to: 100, by: 2) { for z in stride(from: -110, to: 110, by: 2) {
            ground.triangle(point(x,z), point(x,z+2), point(x+2,z))
            ground.triangle(point(x+2,z), point(x,z+2), point(x+2,z+2))
        } }
        root.addChild(ModelEntity(mesh: try ground.resource("Volcanic valley"), materials: [rockMaterial]))
        await progress(0.27, "Opening winding lava channels")
        for side: Float in [-1, 1] {
            var river = SceneSurface()
            for z in -30..<30 {
                let a = Float(z), b = Float(z + 1)
                let x0 = VolcanoLayout.riverX(a, side: side), x1 = VolcanoLayout.riverX(b, side: side)
                river.triangle([x0-3.4,0.014,a], [x1-3.4,0.014,b], [x0+3.4,0.014,a], uvScale: 0.22)
                river.triangle([x0+3.4,0.014,a], [x1-3.4,0.014,b], [x1+3.4,0.014,b], uvScale: 0.22)
            }
            root.addChild(ModelEntity(mesh: try river.resource("Lava channel"), materials: [lava]))
            let glow = PointLight(); glow.light.color = UIColor(red: 1, green: 0.22, blue: 0.04, alpha: 1)
            glow.light.intensity = 1900; glow.light.attenuationRadius = 26
            glow.position = [side * 15, 2, 1]; root.addChild(glow)
        }
        for z in VolcanoLayout.bridges { for x in -11...11 { for lane in -1...1 {
            _ = SceneDetail.rounded([1.97,0.18,1.83], at: [Float(x)*2,0.06,z+Float(lane)*1.86],
                material: weathered, parent: root, radius: 0.05)
        } } }
        for z in stride(from: -38, through: 38, by: 2) { for lane in -1...1 {
            _ = SceneDetail.rounded([1.38,0.10,1.91], at: [Float(lane)*1.42+sin(Float(z)*0.12)*0.5,0.008,Float(z)],
                material: weathered, parent: root, radius: 0.04)
        } }
        await progress(0.43, "Layering cliffs and weathered ruins")
        let rocks = try (0..<5).map { try SceneDetail.rockGeometry(seed: $0*17).resource("Basalt \($0)") }
        for side: Float in [-1, 1] {
            for i in 0..<24 {
                let model = ModelEntity(mesh: rocks[i%5], materials: [rockMaterial])
                model.position = [side*(59+Float(i%3)*5),0,Float(i)*7-80]
                model.scale = [6+Float(i%4),7+Float((i*7)%12),5+Float(i%3)]
                model.orientation = simd_quatf(angle: Float(i)*1.3, axis: [0,1,0]); root.addChild(model)
            }
            for i in 0..<32 {
                let z = Float(i)*1.85-29
                if VolcanoLayout.bridges.contains(where: { abs(z-$0)<3.4 }) { continue }
                let model = ModelEntity(mesh: rocks[i%5], materials: [rockMaterial])
                let x = VolcanoLayout.riverX(z, side: side)+side*4.4
                model.position = [x,-0.2,z]; model.scale = [0.7+Float(i%3)*0.2,0.5,0.8]
                model.orientation = simd_quatf(angle: Float(i), axis: [0,1,0]); root.addChild(model)
                solids.append(Solid(center: [x,0.5,z], half: [0.9,0.8,0.8]))
            }
            for z: Float in [-12,13] {
                let x = side*32
                for row in 0..<8 { for column in 0..<4 {
                    if row>4 && column==3 { continue }
                    _ = SceneDetail.rounded([1.05,0.61,1.15], at: [x+Float(column)*1.08,Float(row)*0.63+0.3,z],
                        material: weathered, parent: root, radius: 0.035)
                } }
                solids.append(Solid(center: [x+1.5,2.4,z], half: [2.2,2.5,0.65]))
            }
        }
        var mountain = SceneSurface()
        func mountainPoint(_ ring: Int, _ i: Int) -> SIMD3<Float> {
            let a = Float(i%48)*2*Float.pi/48
            let radii: [Float] = [49,37,23,10,7], heights: [Float] = [-2,9,24,42,39]
            let r = radii[ring]*(1+0.10*sin(a*5+Float(ring)))
            return [cos(a)*r-65,heights[ring]+sin(a*7)*1.1,sin(a)*r-113]
        }
        for ring in 0..<4 { for i in 0..<48 {
            mountain.triangle(mountainPoint(ring,i),mountainPoint(ring+1,i),mountainPoint(ring,i+1))
            mountain.triangle(mountainPoint(ring,i+1),mountainPoint(ring+1,i),mountainPoint(ring+1,i+1))
        } }
        root.addChild(ModelEntity(mesh: try mountain.resource("Cinder mountain"), materials: [rockMaterial]))
        var crater = SceneSurface()
        for i in 0..<48 { crater.triangle([-65,38,-113],mountainPoint(4,i+1),mountainPoint(4,i)) }
        root.addChild(ModelEntity(mesh: try crater.resource("Molten crater"), materials: [lava]))
        await progress(0.61, "Lighting the moonlit valley")
        try ValleyAtmosphere.install(in: root)
        await progress(0.75, "Restoring the castle keeps")
        solids.append(contentsOf: try await CastleBases.install(in: root))
        var targets: [Entity] = []
        let robe = SimpleMaterial(color: UIColor(red: 0.14, green: 0.12, blue: 0.20, alpha: 1), roughness: 0.8, isMetallic: false)
        for (i,p) in [SIMD3<Float>(-28,0,-8),[0,0,-8],[28,0,-8],[-28,0,9],[28,0,9]].enumerated() {
            let target = Entity(); target.name = "ashwarden-\(i)"; target.position = p; root.addChild(target)
            _ = SceneDetail.ellipsoid([0.42,0.7,0.31], at: [0,0.92,0], material: robe, parent: target)
            _ = SceneDetail.ellipsoid([0.29,0.35,0.27], at: [0,1.83,0], material: robe, parent: target)
            for x: Float in [-0.1,0.1] { _ = ArenaBuilder.orb(0.037,[x,1.85,0.26],.orange,in: target) }
            _ = ArenaBuilder.taper(radius: 0.48,height: 0.1,top: 1,position: [0,2.12,0],color: basalt,in: target)
            _ = ArenaBuilder.taper(radius: 0.29,height: 0.7,top: 0,position: [0,2.46,0],color: basalt,in: target)
            targets.append(target)
        }
        var wisps: [Entity] = []
        for i in 0..<32 {
            wisps.append(ArenaBuilder.orb(0.022,[sin(Float(i)*2.4)*23,0.8+Float(i%5),cos(Float(i)*1.7)*27],
                UIColor(red: 1,green: 0.43,blue: 0.08,alpha: 1),in: root))
        }
        return .init(root: root,camera: camera,solids: solids,targets: targets,wisps: wisps)
    }
}
