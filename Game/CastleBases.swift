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
        // Safe forecourts just outside the castle footprint, facing the arena.
        return .init(position: [0, 1.65, team.side * 13.4], yaw: team == .ember ? 0 : .pi)
    }
    static func castlePosition(_ team: TeamID) -> SIMD3<Float> { [0, 0, team.side * 22] }
    static func blocker(_ team: TeamID) -> Solid {
        Solid(center: [0, 5.3, team.side * 22], half: [9.05, 5.3, 6.9])
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
            keep.orientation = simd_quatf(angle: team == .ember ? .pi : 0, axis: [0, 1, 0])
            keep.addChild(asset.clone(recursive: true)); root.addChild(keep)
            solids.append(TeamBases.blocker(team))
            let color: UIColor = team == .ember ? .orange : .cyan
            let plaza = ArenaBuilder.box([8, 0.1, 4], [0, -0.04, team.side * 13.4],
                                        UIColor(white: 0.22, alpha: 1), in: root)
            plaza.name = "\(team.title) spawn forecourt"
            for x: Float in [-3.2, 3.2] {
                _ = ArenaBuilder.box([0.15, 3.3, 0.15], [x, 1.65, team.side * 14.4], .darkGray, in: root)
                _ = ArenaBuilder.box([0.85, 1.2, 0.05], [x, 2.4, team.side * 14.4], color, in: root, glowing: true)
            }
        }
        return solids
    }
}
