import RealityKit
import Combine
import UIKit
import simd

enum TeamID: UInt8, CaseIterable, Codable, Sendable {
    case ember = 1, moon
    var title: String { self == .ember ? "Ember Keep" : "Moon Keep" }
    var side: Float { self == .ember ? 1 : -1 }
}

struct PlayerSpawn: Equatable {
    let position: SIMD3<Float>
    let yaw: Float
}

enum TeamBases {
    static func spawn(map: MapID, team: TeamID) -> PlayerSpawn {
        guard map == .volcano else { return .init(position: [0, 1.65, 12], yaw: 0) }
        let local = SIMD3<Float>(CastleLayout.gateX, CastleLayout.courtyardHeight + 1.65,
                                 CastleLayout.spawnZ)
        return .init(position: world(local, team: team), yaw: team == .ember ? 0 : .pi)
    }
    // The original gate points down local -Z, and is offset from the asset centre.
    // Align it to world X=0; bury only the island footing below the courtyard.
    static func castlePosition(_ team: TeamID) -> SIMD3<Float> {
        [-CastleLayout.gateX * team.side, -CastleLayout.courtyardHeight, team.side * 58]
    }
    static func world(_ local: SIMD3<Float>, team: TeamID) -> SIMD3<Float> {
        castlePosition(team) + SIMD3(local.x * team.side, local.y, local.z * team.side)
    }
    static func collision(_ team: TeamID) -> [Solid] {
        CastleLayout.boxes.map { box in
            let center = SIMD3<Float>((box[0] + box[2]) / 2,
                                      CastleLayout.courtyardHeight + box[4] / 2,
                                      (box[1] + box[3]) / 2)
            return Solid(center: world(center, team: team),
                         half: [(box[2] - box[0]) / 2, box[4] / 2, (box[3] - box[1]) / 2])
        }
    }
}

@MainActor
enum CastleBases {
    private static var prototype: Entity?
    private static func load() async throws -> Entity {
        if let prototype { return prototype }
        guard let url = Bundle.main.url(forResource: "Castle", withExtension: "usdz") else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSLocalizedDescriptionKey: "Castle.usdz is missing from the application resources."])
        }
        // Load once asynchronously; both keeps share mesh/material resources.
        for try await entity in Entity.loadAsync(contentsOf: url).values {
            prototype = entity
            return entity
        }
        throw CocoaError(.fileReadCorruptFile)
    }

    static func install(in root: Entity) async throws -> [Solid] {
        let asset = try await load()
        try Task.checkCancellation()
        var solids: [Solid] = []
        for team in TeamID.allCases {
            let keep = Entity(); keep.name = team.title
            keep.position = TeamBases.castlePosition(team)
            keep.orientation = simd_quatf(angle: team == .ember ? 0 : .pi, axis: [0, 1, 0])
            keep.addChild(asset.clone(recursive: true)); root.addChild(keep)
            solids.append(contentsOf: TeamBases.collision(team))
            let color: UIColor = team == .ember ? .orange : .cyan
            // Flat grass links the actual gate (Z≈46.5) to the valley road.
            // No ramp or raised platform: the player's ground plane stays Y=0.
            let grass = SimpleMaterial(color: UIColor(red: 0.22, green: 0.28, blue: 0.10, alpha: 1),
                                       roughness: 1, isMetallic: false)
            let approach = ModelEntity(mesh: .generateBox(size: [5.8, 0.06, 14]), materials: [grass])
            approach.position = [0, -0.03, team.side * 40]
            approach.name = "\(team.title) level grass approach"; root.addChild(approach)
            for x: Float in [-3, 3] {
                _ = ArenaBuilder.box([0.12, 3.3, 0.12], [x, 1.65, team.side * 44], .darkGray, in: root)
                _ = ArenaBuilder.box([0.65, 1.1, 0.035], [x, 2.4, team.side * 44], color, in: root)
            }
            let light = PointLight(); light.light.color = color; light.light.intensity = 1200
            light.light.attenuationRadius = 32; light.position = [0, 7, team.side * 48]; root.addChild(light)
        }
        return solids
    }
}
