import XCTest
import simd
@testable import Nocturne

final class TeamBasesTests: XCTestCase {
    func testOppositeTeamSpawnsFaceTheArenaAndAvoidLavaAndCastles() {
        for team in TeamID.allCases {
            let spawn = TeamBases.spawn(map: .volcano, team: team)
            XCTAssertLessThan(abs(spawn.position.z), 22.5)
            XCTAssertFalse(VolcanoLayout.isLava(spawn.position))
            let forward = ArenaMath.forward(yaw: spawn.yaw, pitch: 0)
            XCTAssertGreaterThan(simd_dot(forward, -spawn.position), 0)
            let solids = TeamID.allCases.map { TeamBases.blocker($0) }
            XCTAssertNil(ArenaMath.segmentHit(from: spawn.position, to: spawn.position,
                                             solid: TeamBases.blocker(team), radius: 0.38))
            let moved = ArenaMath.move(from: spawn.position, delta: forward, solids: solids)
            XCTAssertLessThan(abs(moved.z), abs(spawn.position.z))
        }
        XCTAssertEqual(TeamBases.spawn(map: .volcano, team: .ember).position.z,
                       -TeamBases.spawn(map: .volcano, team: .moon).position.z)
    }

    func testOriginalCourtSpawnRemainsIndependentOfTeamSelection() {
        let expected = PlayerSpawn(position: [0, 1.65, 12], yaw: 0)
        XCTAssertEqual(TeamBases.spawn(map: .hollowCourt, team: .ember), expected)
        XCTAssertEqual(TeamBases.spawn(map: .hollowCourt, team: .moon), expected)
    }
}
