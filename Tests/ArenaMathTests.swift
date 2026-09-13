import XCTest
@testable import Nocturne

final class ArenaMathTests: XCTestCase {
    func testFastProjectileSweepsThroughThinWall() {
        let wall = Solid(center: [0, 1, 0], half: [4, 2, 0.1])
        let hit = ArenaMath.segmentHit(from: [0, 1, 3], to: [0, 1, -3], solid: wall, radius: 0.2)
        XCTAssertNotNil(hit)
        XCTAssertEqual(hit ?? 0, 0.45, accuracy: 0.001)
    }
    func testParallelSegmentOutsideWallMisses() {
        let wall = Solid(center: [0, 1, 0], half: [1, 1, 1])
        XCTAssertNil(ArenaMath.segmentHit(from: [3, 1, 4], to: [3, 1, -4], solid: wall))
    }
    func testProjectileMovingAwayFromTargetMisses() {
        XCTAssertNil(ArenaMath.segmentSphere(from: [0, 0, 3], to: [0, 0, 5], center: .zero, radius: 1))
    }
    func testTouchForwardMatchesCameraForward() {
        let forward = ArenaMath.forward(yaw: 0, pitch: 0)
        XCTAssertEqual(forward.z, -1, accuracy: 0.001)
        let left = ArenaMath.forward(yaw: .pi / 2, pitch: 0)
        XCTAssertEqual(left.x, -1, accuracy: 0.001)
    }
    func testMovementCannotEnterPillar() {
        let pillar = Solid(center: [0, 1, 0], half: [1, 2, 1])
        let p = SIMD3<Float>(0, 1.65, 1.42)
        XCTAssertEqual(ArenaMath.move(from: p, delta: [0, 0, -0.1], solids: [pillar]), p)
    }
}
