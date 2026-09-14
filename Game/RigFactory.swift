import RealityKit
import UIKit
import simd

@MainActor
final class BookDriver: BookVisualDriving {
    let page: ModelEntity
    private let leftPage: ModelEntity
    private var materials: [String: SimpleMaterial] = [:]
    private var referenceMaterials: [String: SimpleMaterial] = [:]
    private var selectedPage = ""
    private var flipTime: Float = 0
    private var pendingMaterial: SimpleMaterial?
    var onTranscript: ((String) -> Void)?

    init(page: ModelEntity, leftPage: ModelEntity) throws {
        self.page = page; self.leftPage = leftPage
        for spell in PrototypeContent.spellbook {
            materials[spell.presentation.bookPage] = try Self.pageMaterial(spell: spell)
            referenceMaterials[spell.presentation.bookPage] = try Self.pageMaterial(spell: spell, reference: true)
        }
        show(page: "ignis", highlight: "FIREBALL")
        flipTime = 0
        if let initial = materials["ignis"] {
            page.model?.materials = [initial]
            if let reference = referenceMaterials["ignis"] { leftPage.model?.materials = [reference] }
        }
    }

    func show(page: String, highlight: String) {
        guard page != selectedPage, let material = materials[page] else { return }
        selectedPage = page; pendingMaterial = material; flipTime = 0.3
    }
    func update(delta: Float, motion: Bool) {
        guard flipTime > 0 else { return }
        flipTime = max(0, flipTime - delta)
        let progress = 1 - flipTime / 0.3
        if progress >= 0.5, let material = pendingMaterial {
            page.model?.materials = [material]
            if let reference = referenceMaterials[selectedPage] { leftPage.model?.materials = [reference] }
            pendingMaterial = nil
        }
        let angle = motion ? sin(progress * .pi) * 1.3 : 0
        page.orientation = simd_quatf(angle: angle, axis: [0, 0, 1])
        page.position = [0.124 * cos(angle), 0.043 + 0.124 * sin(angle), 0]
    }
    func showTranscript(_ text: String) { onTranscript?(text) }

    private static func pageMaterial(spell: SpellDefinition, reference: Bool = false) throws -> SimpleMaterial {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 640), format: format)
        let image = renderer.image { context in
            UIColor(red: 0.74, green: 0.67, blue: 0.50, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 512, height: 640))
            for i in 0..<1100 {
                UIColor(white: i % 2 == 0 ? 0.35 : 1, alpha: 0.035).setFill()
                context.fill(CGRect(x: CGFloat((i * 79) % 512), y: CGFloat((i * 137) % 640), width: 1, height: 3))
            }
            let ink = UIColor(red: 0.20, green: 0.13, blue: 0.16, alpha: 1)
            let gold = spell.id.color
            func text(_ value: String, _ y: CGFloat, _ size: CGFloat, _ color: UIColor) {
                let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
                (value as NSString).draw(in: CGRect(x: 28, y: y, width: 456, height: size * 2),
                    withAttributes: [.font: UIFont(name: "Georgia", size: size) ?? UIFont.systemFont(ofSize: size),
                                     .foregroundColor: color, .paragraphStyle: paragraph])
            }
            ink.setStroke(); context.cgContext.setLineWidth(2)
            context.cgContext.stroke(CGRect(x: 22, y: 22, width: 468, height: 596))
            context.cgContext.setLineWidth(0.7)
            context.cgContext.stroke(CGRect(x: 30, y: 30, width: 452, height: 580))
            text("INCANTATION  \(spell.id.rawValue)  /  IV", 52, 20, ink)
            text(reference ? "ARCANE STUDIES" : spell.presentation.bookPage.uppercased(), 95, reference ? 31 : 52, ink)
            SpellArtwork.icon(spell.id).draw(in: CGRect(x: reference ? 176 : 142, y: 192, width: reference ? 160 : 228, height: reference ? 160 : 228))
            if reference {
                text("FORM · FOCUS · RELEASE", 382, 21, ink)
                text(spell.id.description, 437, 22, ink)
                text("Let breath give shape to will.", 509, 20, ink)
                text("NOCTURNE  /  GRIMOIRE", 565, 17, ink)
            } else {
                text("SPEAK", 442, 19, ink)
                text(spell.presentation.highlightedTextKey, 478, 38, gold)
                text(spell.id.description, 560, 17, ink)
            }
        }
        guard let cg = image.cgImage else { throw CocoaError(.fileReadCorruptFile) }
        let texture = try TextureResource.generate(from: cg, options: .init(semantic: .color))
        var material = SimpleMaterial(color: .white, roughness: 1, isMetallic: false)
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
    private var fingers: [Entity] = []

    init(hand: Entity) {
        self.hand = hand; rest = hand.position
        fingers = (0..<4).compactMap { hand.findEntity(named: "Finger\($0)") }
        _ = ArenaBuilder.orb(0.078, .zero, .orange, in: charge)
        _ = ArenaBuilder.orb(0.042, [0, 0, 0.054], UIColor(red: 1, green: 0.88, blue: 0.42, alpha: 1), in: charge)
        for i in 0..<8 {
            let a = Float(i) * .pi / 4
            _ = ArenaBuilder.orb(0.013, [cos(a) * 0.11, sin(a) * 0.11, 0], .orange, in: charge)
        }
    }
    func beginCharge(effect: String, attachedTo socket: Entity) {
        active = true; phase = 0; releasing = 0
        let spell = PrototypeContent.spellbook.first { $0.presentation.chargeEffect == effect }?.id ?? .fireball
        for child in charge.children {
            (child as? ModelEntity)?.model?.materials = [UnlitMaterial(color: spell.color)]
        }
        charge.removeFromParent(); socket.addChild(charge); charge.isEnabled = true
    }
    func release(animation: String) { active = false; charge.isEnabled = false; releasing = 0.24 }
    func cancel() { active = false; charge.isEnabled = false; releasing = 0; hand.position = rest }
    func idle() { hand.position = rest }

    func update(delta: Float, motion: Bool) {
        phase += delta
        for (index, finger) in fingers.enumerated() {
            let curl: Float = active && motion ? 0.45 + sin(phase * 5 + Float(index)) * 0.06 : 0.10
            finger.orientation = simd_quatf(angle: curl, axis: [1, 0, 0])
        }
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
        bookRoot.position = [-0.25, -0.20, -0.72]
        bookRoot.scale = SIMD3(repeating: 0.72)
        bookRoot.orientation = simd_quatf(angle: 0.62, axis: [1,0,0]) * simd_quatf(angle: -0.10, axis: [0,0,1])
        root.addChild(bookRoot)
        let leather = SimpleMaterial(color: UIColor(red: 0.13,green: 0.065,blue: 0.09,alpha: 1),roughness: 0.83,isMetallic: false)
        let gold = SimpleMaterial(color: UIColor(red: 0.64,green: 0.43,blue: 0.19,alpha: 1),roughness: 0.4,isMetallic: true)
        let paper = SimpleMaterial(color: UIColor(red: 0.71,green: 0.64,blue: 0.49,alpha: 1),roughness: 1,isMetallic: false)
        for x: Float in [-0.125,0.125] {
            _ = SceneDetail.rounded([0.249,0.025,0.325],at: [x,0,0],material: leather,parent: bookRoot,radius: 0.008)
            for layer in 0..<9 {
                _ = SceneDetail.rounded([0.232-Float(layer%3)*0.001,0.0024,0.300],
                    at: [x,0.015+Float(layer)*0.0027,0],material: paper,parent: bookRoot,radius: 0.001)
            }
            for z: Float in [-0.145,0.145] {
                for edge: Float in [-1,1] {
                    _ = SceneDetail.rounded([0.034,0.005,0.027],at: [x+edge*0.10,0.015,z],material: gold,parent: bookRoot,radius: 0.003)
                }
            }
            // Fine binding stitches along the outer leather edge.
            for i in 0..<18 {
                _ = SceneDetail.rounded([0.004,0.002,0.003],at: [x+(x>0 ? 0.115 : -0.115),0.014,Float(i)*0.016-0.136],
                    material: gold,parent: bookRoot,radius: 0.0005)
            }
        }
        _ = SceneDetail.rounded([0.027,0.035,0.329],at: [0,-0.006,0],material: leather,parent: bookRoot,radius: 0.010)
        for z: Float in [-0.12,-0.06,0,0.06,0.12] {
            _ = SceneDetail.rounded([0.039,0.041,0.012],at: [0,-0.006,z],material: gold,parent: bookRoot,radius: 0.005)
        }
        _ = SceneDetail.rounded([0.012,0.002,0.11],at: [0.08,0.013,0.185],
            material: SimpleMaterial(color: .systemRed,roughness: 1,isMetallic: false),parent: bookRoot,radius: 0.001)
        let page = ModelEntity(mesh: .generatePlane(width: 0.23,depth: 0.29),materials: [])
        page.position = [0.124,0.041,0]; bookRoot.addChild(page)
        let leftPage = page.clone(recursive: false); leftPage.position.x = -0.124; bookRoot.addChild(leftPage)
        let book = try BookDriver(page: page,leftPage: leftPage)
        let left = Entity(); left.position = [-0.28,-0.285,-0.63]
        left.scale = [-0.86,0.86,0.86]; left.orientation = simd_quatf(angle: 0.20,axis: [1,0,0]); root.addChild(left)
        try WizardHand.build(in: left,holdingBook: true)
        let hand = Entity(); hand.name = "RightHand"; hand.position = [0.26,-0.18,-0.58]
        hand.orientation = simd_quatf(angle: -0.10,axis: [0,0,1]); root.addChild(hand)
        try WizardHand.build(in: hand)
        let socket = Entity(); socket.name = "CastSocket"; socket.position = [0,0.12,-0.09]; hand.addChild(socket)
        let light = PointLight(); light.light.color = UIColor(red: 1,green: 0.86,blue: 0.68,alpha: 1)
        light.light.intensity = 24; light.light.attenuationRadius = 1.2; light.position = [0,0.06,-0.35]; root.addChild(light)
        let driver = HandDriver(hand: hand)
        let controller = try PlayerRigController(camera: camera,rigAsset: root,book: book,hand: driver)
        return Result(controller: controller,hand: driver,book: book,root: root)
    }
}
