import RealityKit
import UIKit
import simd

@MainActor
final class BookDriver: BookVisualDriving {
    let page: ModelEntity
    private let idleMaterial: UnlitMaterial
    private let activeMaterial: UnlitMaterial
    var onTranscript: ((String) -> Void)?

    init(page: ModelEntity) throws {
        self.page = page
        idleMaterial = try Self.pageMaterial(active: false)
        activeMaterial = try Self.pageMaterial(active: true)
        page.model?.materials = [activeMaterial]
    }

    func show(page: String, highlight: String) { self.page.model?.materials = [activeMaterial] }
    func showTranscript(_ text: String) { onTranscript?(text) }

    private static func pageMaterial(active: Bool) throws -> UnlitMaterial {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 640))
        let image = renderer.image { context in
            UIColor(red: 0.74, green: 0.67, blue: 0.50, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 512, height: 640))
            let ink = UIColor(red: 0.20, green: 0.13, blue: 0.16, alpha: 1)
            let gold = UIColor(red: 0.58, green: 0.28, blue: 0.12, alpha: 1)
            func text(_ value: String, _ y: CGFloat, _ size: CGFloat, _ color: UIColor) {
                let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
                (value as NSString).draw(in: CGRect(x: 28, y: y, width: 456, height: size * 2),
                    withAttributes: [.font: UIFont(name: "Georgia", size: size) ?? UIFont.systemFont(ofSize: size),
                                     .foregroundColor: color, .paragraphStyle: paragraph])
            }
            ink.setStroke(); context.cgContext.setLineWidth(2)
            context.cgContext.stroke(CGRect(x: 22, y: 22, width: 468, height: 596))
            text("THE FIRST INCANTATION", 52, 20, ink)
            text("IGNIS", 95, 52, ink)
            let circle = CGRect(x: 147, y: 196, width: 218, height: 218)
            gold.setStroke(); context.cgContext.setLineWidth(4); context.cgContext.strokeEllipse(in: circle)
            context.cgContext.move(to: CGPoint(x: 256, y: 210))
            context.cgContext.addLine(to: CGPoint(x: 174, y: 367))
            context.cgContext.addLine(to: CGPoint(x: 338, y: 367))
            context.cgContext.closePath(); context.cgContext.strokePath()
            text("SPEAK", 442, 19, ink)
            text("FIREBALL", 478, 42, active ? gold : ink)
            text("Let the silence become flame.", 560, 19, ink)
        }
        guard let cg = image.cgImage else { throw CocoaError(.fileReadCorruptFile) }
        let texture = try TextureResource.generate(from: cg, options: .init(semantic: .color))
        var material = UnlitMaterial(color: .white)
        material.color = .init(tint: .white, texture: .init(texture))
        return material
    }
}

@MainActor
final class HandDriver: HandVisualDriving {
    let hand: Entity
    private let charge = Entity()
    private var phase: Float = 0
    private var releasing: Float = 0
    private var active = false
    private let rest: SIMD3<Float>

    init(hand: Entity) {
        self.hand = hand; rest = hand.position
        _ = ArenaBuilder.orb(0.078, .zero, .orange, in: charge)
        _ = ArenaBuilder.orb(0.042, [0, 0, 0.054], UIColor(red: 1, green: 0.88, blue: 0.42, alpha: 1), in: charge)
        for i in 0..<8 {
            let a = Float(i) * .pi / 4
            _ = ArenaBuilder.orb(0.013, [cos(a) * 0.11, sin(a) * 0.11, 0], .orange, in: charge)
        }
    }
    func beginCharge(effect: String, attachedTo socket: Entity) {
        active = true; phase = 0; releasing = 0
        charge.removeFromParent(); socket.addChild(charge); charge.isEnabled = true
    }
    func release(animation: String) { active = false; charge.isEnabled = false; releasing = 0.24 }
    func cancel() { active = false; charge.isEnabled = false; releasing = 0; hand.position = rest }
    func idle() { hand.position = rest }

    func update(delta: Float, motion: Bool) {
        phase += delta
        if active {
            charge.scale = SIMD3(repeating: 0.8 + sin(phase * 24) * 0.12)
            charge.orientation = simd_quatf(angle: phase * 3, axis: [0, 0, 1])
        }
        if releasing > 0 {
            releasing = max(0, releasing - delta)
            if motion { hand.position = rest + [0, 0.025, -sin(releasing / 0.24 * .pi) * 0.14] }
        } else { hand.position = rest }
    }
}

@MainActor
enum RigFactory {
    struct Result {
        let controller: PlayerRigController
        let hand: HandDriver
        let book: BookDriver
        let root: Entity
    }

    static func make(camera: PerspectiveCamera) throws -> Result {
        let root = Entity(); root.name = "FirstPersonRig"
        let bookRoot = Entity(); bookRoot.name = "LeftBook"
        bookRoot.position = [-0.26, -0.26, -0.55]
        bookRoot.orientation = simd_quatf(angle: 0.7, axis: [1, 0, 0]) * simd_quatf(angle: -0.12, axis: [0, 0, 1])
        root.addChild(bookRoot)
        let leather = UIColor(red: 0.10, green: 0.065, blue: 0.16, alpha: 1)
        let gold = UIColor(red: 0.57, green: 0.40, blue: 0.19, alpha: 1)
        for x: Float in [-0.125, 0.125] {
            _ = ArenaBuilder.box([0.25, 0.032, 0.32], [x, 0, 0], leather, in: bookRoot)
            _ = ArenaBuilder.box([0.23, 0.026, 0.30], [x, 0.025, 0], UIColor(red: 0.70, green: 0.63, blue: 0.47, alpha: 1), in: bookRoot)
            for z: Float in [-0.14, 0.14] { _ = ArenaBuilder.box([0.24, 0.004, 0.012], [x, 0.04, z], gold, in: bookRoot) }
        }
        let page = ModelEntity(mesh: .generatePlane(width: 0.23, depth: 0.29), materials: [])
        page.position = [0.124, 0.043, 0]
        bookRoot.addChild(page)
        let book = try BookDriver(page: page)
        let leftPage = page.clone(recursive: false); leftPage.position.x = -0.124; bookRoot.addChild(leftPage)
        // Dark glove beneath the book, robe sleeve and articulated right-hand silhouette.
        let glove = UIColor(red: 0.21, green: 0.15, blue: 0.24, alpha: 1)
        let sleeve = UIColor(red: 0.055, green: 0.035, blue: 0.11, alpha: 1)
        _ = ArenaBuilder.box([0.12, 0.11, 0.30], [-0.29, -0.42, -0.34], sleeve, in: root)
        _ = ArenaBuilder.orb(0.073, [-0.30, -0.32, -0.43], glove, in: root, glowing: false)
        let hand = Entity(); hand.name = "RightHand"; hand.position = [0.30, -0.31, -0.50]
        root.addChild(hand)
        _ = ArenaBuilder.box([0.13, 0.13, 0.34], [0.02, -0.07, 0.17], sleeve, in: hand)
        _ = ArenaBuilder.box([0.137, 0.022, 0.045], [0.02, 0.006, 0.06], gold, in: hand)
        let palm = ArenaBuilder.orb(0.069, [0, 0.02, 0], glove, in: hand, glowing: false)
        palm.scale = [1, 0.6, 1.15]
        for i in 0..<4 {
            let finger = ArenaBuilder.box([0.022, 0.024, 0.095], [Float(i) * 0.029 - 0.043, 0.04, -0.083], glove, in: hand)
            finger.orientation = simd_quatf(angle: Float(i - 2) * 0.09, axis: [0, 1, 0])
            _ = ArenaBuilder.orb(0.013, [Float(i) * 0.029 - 0.043, 0.04, -0.13], glove, in: hand, glowing: false)
        }
        let thumb = ArenaBuilder.box([0.025, 0.025, 0.08], [-0.075, 0.025, -0.008], glove, in: hand)
        thumb.orientation = simd_quatf(angle: -0.7, axis: [0, 1, 0])
        let socket = Entity(); socket.name = "CastSocket"; socket.position = [0, 0.15, -0.05]; hand.addChild(socket)
        let driver = HandDriver(hand: hand)
        let controller = try PlayerRigController(camera: camera, rigAsset: root, book: book, hand: driver)
        return Result(controller: controller, hand: driver, book: book, root: root)
    }
}
