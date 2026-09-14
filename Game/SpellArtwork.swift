import UIKit
import SwiftUI

// Original vector-drawn emblems, shared by the HUD, grimoire, and 3D book textures.
@MainActor
enum SpellArtwork {
    private static var cache: [SpellID: UIImage] = [:]
    static func icon(_ spell: SpellID) -> UIImage {
        if let cached = cache[spell] { return cached }
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128), format: format).image { renderer in
            let c = renderer.cgContext
            c.setStrokeColor(spell.color.cgColor); c.setFillColor(spell.color.cgColor)
            c.setLineWidth(3); c.setLineCap(.round); c.setLineJoin(.round)
            c.strokeEllipse(in: CGRect(x: 9, y: 9, width: 110, height: 110))
            for i in 0..<8 {
                let a = CGFloat(i) * .pi / 4
                c.move(to: CGPoint(x: 64 + cos(a) * 51, y: 64 + sin(a) * 51))
                c.addLine(to: CGPoint(x: 64 + cos(a) * 44, y: 64 + sin(a) * 44))
            }
            c.strokePath()
            switch spell {
            case .fireball:
                c.move(to: CGPoint(x: 68, y: 27))
                c.addCurve(to: CGPoint(x: 86, y: 80), control1: CGPoint(x: 65, y: 52), control2: CGPoint(x: 98, y: 55))
                c.addCurve(to: CGPoint(x: 43, y: 81), control1: CGPoint(x: 79, y: 105), control2: CGPoint(x: 42, y: 104))
                c.addCurve(to: CGPoint(x: 68, y: 27), control1: CGPoint(x: 28, y: 63), control2: CGPoint(x: 54, y: 59))
                c.closePath(); c.strokePath()
                c.move(to: CGPoint(x: 64, y: 62)); c.addLine(to: CGPoint(x: 53, y: 82))
                c.addLine(to: CGPoint(x: 73, y: 82)); c.closePath(); c.strokePath()
            case .iceShards:
                for i in 0..<6 {
                    let a = CGFloat(i) * .pi / 3
                    let tip = CGPoint(x: 64 + cos(a) * 32, y: 64 + sin(a) * 32)
                    c.move(to: CGPoint(x: 64, y: 64)); c.addLine(to: tip)
                    let branch = CGPoint(x: 64 + cos(a) * 21, y: 64 + sin(a) * 21)
                    for sign: CGFloat in [-1, 1] {
                        c.move(to: branch)
                        c.addLine(to: CGPoint(x: branch.x + cos(a + sign * .pi / 3) * 11,
                                             y: branch.y + sin(a + sign * .pi / 3) * 11))
                    }
                }
                c.strokePath()
            case .mudBlast:
                c.move(to: CGPoint(x: 31, y: 83)); c.addLine(to: CGPoint(x: 49, y: 47))
                c.addLine(to: CGPoint(x: 63, y: 60)); c.addLine(to: CGPoint(x: 78, y: 37))
                c.addLine(to: CGPoint(x: 98, y: 83)); c.closePath(); c.strokePath()
                for x: CGFloat in [48, 64, 80] { c.fillEllipse(in: CGRect(x: x - 3, y: 91, width: 6, height: 6)) }
            case .voidBolt:
                c.move(to: CGPoint(x: 80, y: 29)); c.addLine(to: CGPoint(x: 41, y: 70))
                c.addLine(to: CGPoint(x: 62, y: 68)); c.addLine(to: CGPoint(x: 49, y: 99))
                c.addLine(to: CGPoint(x: 90, y: 52)); c.addLine(to: CGPoint(x: 68, y: 55))
                c.closePath(); c.strokePath()
                c.strokeEllipse(in: CGRect(x: 29, y: 32, width: 10, height: 10))
            }
        }
        cache[spell] = image; return image
    }
}

struct SpellEmblem: View {
    let spell: SpellID
    var body: some View {
        Image(uiImage: SpellArtwork.icon(spell)).resizable().interpolation(.none)
            .scaledToFit().accessibilityLabel(spell.title)
    }
}
