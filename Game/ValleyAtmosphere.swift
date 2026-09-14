import RealityKit
import UIKit
import simd

@MainActor
enum ValleyAtmosphere {
    static func install(in root: Entity) throws {
        var stars = SceneSurface()
        for i in 0..<380 {
            let a = Float(i)*2.399963, y = 0.1+Float((i*73)%379)/379*0.87
            let p = SIMD3<Float>(cos(a)*sqrt(1-y*y),y,sin(a)*sqrt(1-y*y))*350
            let tangent = simd_normalize(simd_cross(p,[0,1,0]))*(0.12+Float(i%4)*0.08)
            let up = simd_normalize(simd_cross(tangent,p))*simd_length(tangent)
            stars.triangle(p-tangent-up,p+tangent-up,p+up)
            stars.triangle(p+up,p+tangent-up,p-tangent-up)
        }
        root.addChild(ModelEntity(mesh: try stars.resource("Constellations"), materials: [UnlitMaterial(color: UIColor(red: 0.72,green: 0.80,blue: 1,alpha: 1))]))
        let moonlight = DirectionalLight()
        moonlight.light.color = UIColor(red: 0.71,green: 0.79,blue: 1,alpha: 1); moonlight.light.intensity = 3600
        moonlight.look(at: .zero,from: [65,90,30],relativeTo: nil)
        moonlight.shadow = DirectionalLightComponent.Shadow()
        moonlight.shadow?.maximumDistance = 120
        moonlight.shadow?.depthBias = 1
        root.addChild(moonlight)
        let fill = PointLight(); fill.light.color = UIColor(red: 0.54,green: 0.61,blue: 0.80,alpha: 1)
        fill.light.intensity = 1800; fill.light.attenuationRadius = 65; fill.position = [0,18,0]; root.addChild(fill)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 512,height: 512),format: format).image { context in
            UIColor(red: 0.81,green: 0.86,blue: 0.94,alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 8,y: 8,width: 496,height: 496))
            for i in 0..<90 {
                let a = CGFloat(i)*2.39996, radius = sqrt(CGFloat(i)/90)*222, r = CGFloat(4+i%17)
                UIColor(red: 0.44,green: 0.50,blue: 0.64,alpha: 0.12).setFill()
                context.cgContext.fillEllipse(in: CGRect(x: 256+cos(a)*radius-r,y: 256+sin(a)*radius-r,width: r*2,height: r*2))
            }
        }
        if let cg = image.cgImage {
            var material = UnlitMaterial(color: .white)
            material.color = .init(tint: .white,texture: .init(try TextureResource.generate(from: cg,options: .init(semantic: .color))))
            material.blending = .transparent(opacity: .init(floatLiteral: 1))
            let moon = ModelEntity(mesh: .generatePlane(width: 29,height: 29),materials: [material])
            root.addChild(moon); moon.look(at: .zero,from: [130,150,125],relativeTo: nil)
            moon.orientation *= simd_quatf(angle: .pi,axis: [0,1,0])
        }
        let mistImage = UIGraphicsImageRenderer(size: CGSize(width: 128,height: 128),format: format).image { context in
            let colors = [UIColor.white.cgColor,UIColor.clear.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),colors: colors,locations: [0,1]) {
                context.cgContext.drawRadialGradient(gradient,startCenter: CGPoint(x: 64,y: 64),startRadius: 0,
                    endCenter: CGPoint(x: 64,y: 64),endRadius: 63,options: [])
            }
        }
        guard let cg = mistImage.cgImage else { return }
        let texture = try TextureResource.generate(from: cg,options: .init(semantic: .color))
        var mistMaterial = UnlitMaterial(color: .white)
        mistMaterial.color = .init(tint: UIColor(red: 0.34,green: 0.19,blue: 0.22,alpha: 1),texture: .init(texture))
        mistMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.18))
        for side: Float in [-1,1] { for i in 0..<5 {
            let mist = ModelEntity(mesh: .generatePlane(width: 24,height: 7),materials: [mistMaterial])
            mist.position = [side*43,2.2,Float(i)*17-34]
            mist.orientation = simd_quatf(angle: side * .pi/2,axis: [0,1,0]); root.addChild(mist)
            let reverse = mist.clone(recursive: false)
            reverse.orientation *= simd_quatf(angle: .pi,axis: [0,1,0]); root.addChild(reverse)
        } }
    }
}
