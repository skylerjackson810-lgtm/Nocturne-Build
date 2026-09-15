import XCTest
import simd
@testable import Nocturne

final class TeamBasesTests: XCTestCase {
    func testBothTeamsStartInsideCourtyardAndCanWalkThroughGateToValley() {
        let solids = TeamID.allCases.flatMap { TeamBases.collision($0) }
        for team in TeamID.allCases {
            let spawn = TeamBases.spawn(map: .volcano, team: team)
            let gate = TeamBases.world([CastleLayout.gateX, CastleLayout.courtyardHeight, -11.5], team: team)
            XCTAssertEqual(gate.x, 0, accuracy: 0.001)
            XCTAssertEqual(gate.y, 0, accuracy: 0.001)
            XCTAssertGreaterThan(abs(spawn.position.z), abs(gate.z), "Spawn must be inside the gate.")
            XCTAssertEqual(spawn.position.y, 1.65, accuracy: 0.001)
            XCTAssertFalse(VolcanoLayout.isLava(spawn.position))
            let forward = ArenaMath.forward(yaw: spawn.yaw, pitch: 0)
            XCTAssertGreaterThan(simd_dot(forward, gate - spawn.position), 0)
            var p = spawn.position
            // Traverse the entire gateway/grass approach using the runtime movement code.
            for _ in 0..<440 {
                let next = ArenaMath.move(from: p, delta: forward * 0.04, solids: solids,
                                         boundary: VolcanoLayout.boundary,
                                         depthBoundary: VolcanoLayout.depthBoundary)
                XCTAssertEqual(simd_distance(next, p), 0.04, accuracy: 0.0001)
                p = next
            }
            XCTAssertLessThan(abs(p.z), 35)
        }
    }

    func testRearCourtyardDoesNotUseOldArenaDepthClamp() {
        for team in TeamID.allCases {
            let p = TeamBases.world([5, CastleLayout.courtyardHeight + 1.65, 6], team: team)
            XCTAssertGreaterThan(abs(p.z), VolcanoLayout.boundary)
            let moved = ArenaMath.move(from: p, delta: [0.02, 0, 0], solids: [],
                                       boundary: VolcanoLayout.boundary,
                                       depthBoundary: VolcanoLayout.depthBoundary)
            XCTAssertEqual(moved.z, p.z)
            XCTAssertEqual(moved.x, p.x + 0.02, accuracy: 0.0001)
        }
    }

    func testCastleWallBlocksMovementButGateDoesNot() {
        for team in TeamID.allCases {
            let wall = TeamBases.world([0, CastleLayout.courtyardHeight + 1.65, -9.4], team: team)
            let moved = ArenaMath.move(from: wall, delta: [0, 0, -0.1 * team.side],
                                       solids: TeamBases.collision(team), boundary: VolcanoLayout.boundary,
                                       depthBoundary: VolcanoLayout.depthBoundary)
            XCTAssertEqual(moved, wall)
        }
    }

    func testGroundFloorBuildingsAllowEntryAndExitForBothTeams() {
        let angle = Float.pi * 25 / 180
        func west(_ v: Float) -> SIMD3<Float> {
            [-7.2 * cos(angle) + v * sin(angle), 6.37,
             7.2 * sin(angle) + v * cos(angle)]
        }
        let routes: [(SIMD3<Float>, SIMD3<Float>)] = [
            ([6, 6.37, 2.3], [12, 6.37, 2.3]),
            ([2.5, 6.37, 8], [2.5, 6.37, 12]),
            (west(0.4), west(4.4))
        ]
        for team in TeamID.allCases {
            let solids = TeamBases.collision(team)
            for (a, b) in routes {
                let start = TeamBases.world(a, team: team), end = TeamBases.world(b, team: team)
                var p = start
                for destination in [end, start] {
                    let delta = (destination - p) / 200
                    for _ in 0..<200 {
                        p = ArenaMath.move(from: p, delta: delta, solids: solids,
                                           boundary: VolcanoLayout.boundary,
                                           depthBoundary: VolcanoLayout.depthBoundary)
                    }
                    XCTAssertEqual(simd_distance(p, destination), 0, accuracy: 0.005)
                }
            }
        }
    }

    func testOriginalCourtSpawnRemainsIndependentOfTeamSelection() {
        let expected = PlayerSpawn(position: [0, 1.65, 12], yaw: 0)
        XCTAssertEqual(TeamBases.spawn(map: .hollowCourt, team: .ember), expected)
        XCTAssertEqual(TeamBases.spawn(map: .hollowCourt, team: .moon), expected)
    }
}
