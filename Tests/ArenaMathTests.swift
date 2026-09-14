import XCTest
import simd
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

    func testLowPolyMeshesHaveBoundedTriangleCountsAndOutwardFlatNormals() {
        let meshes: [(LowPolyGeometry, Int)] = [
            (.sphere(), 48), (.sphere(rings: 2, sectors: 4), 8),
            (.taper(topRadius: 0), 12), (.taper(topRadius: 0.55), 24)
        ]
        for (mesh, triangles) in meshes {
            XCTAssertEqual(mesh.indices.count, triangles * 3)
            XCTAssertEqual(mesh.positions.count, mesh.normals.count)
            XCTAssertEqual(mesh.positions.count, mesh.indices.count)
            for i in stride(from: 0, to: mesh.positions.count, by: 3) {
                let center = (mesh.positions[i] + mesh.positions[i + 1] + mesh.positions[i + 2]) / 3
                XCTAssertGreaterThan(simd_dot(mesh.normals[i], center), 0)
                XCTAssertEqual(simd_length(mesh.normals[i]), 1, accuracy: 0.0001)
                XCTAssertEqual(mesh.normals[i], mesh.normals[i + 1])
                XCTAssertEqual(mesh.normals[i], mesh.normals[i + 2])
            }
        }
    }

    func testAudioSetupAndOutputOnlyChangesDoNotRestartMicrophone() {
        let session = UUID()
        XCTAssertFalse(SpeechRoutePolicy.needsRestart(activeSession: session,
            observerSession: session, previousInput: "built-in:48000:1", currentInput: "built-in:48000:1"))
        XCTAssertTrue(SpeechRoutePolicy.needsRestart(activeSession: session,
            observerSession: session, previousInput: "built-in:48000:1", currentInput: "headset:24000:1"))
    }

    func testQueuedRouteChangeCannotRestartRetiredSession() {
        let oldSession = UUID()
        XCTAssertFalse(SpeechRoutePolicy.needsRestart(activeSession: UUID(),
            observerSession: oldSession, previousInput: "old", currentInput: "new"))
        XCTAssertFalse(SpeechRoutePolicy.needsRestart(activeSession: nil,
            observerSession: oldSession, previousInput: "old", currentInput: "new"))
    }

    func testEmptyRecognitionRestartsButPersistentErrorsAreBounded() {
        XCTAssertEqual(SpeechRetryPolicy.delay(domain: "kAFAssistantErrorDomain", code: 1110,
                                               consecutiveFailures: 10), 0.4)
        XCTAssertNotNil(SpeechRetryPolicy.delay(domain: "NocturneSpeech", code: 1, consecutiveFailures: 0))
        XCTAssertNil(SpeechRetryPolicy.delay(domain: "NocturneSpeech", code: 1, consecutiveFailures: 3))
    }

    func testVolcanoBridgesAndSpawnAreSafeButChannelsBurn() {
        XCTAssertFalse(VolcanoLayout.isLava([0, 1.65, 12]))
        for x: Float in [-8, 8] {
            XCTAssertTrue(VolcanoLayout.isLava([x, 1.65, 4]))
            for z in VolcanoLayout.bridges { XCTAssertFalse(VolcanoLayout.isLava([x, 1.65, z])) }
        }
        XCTAssertEqual(MapID.playable, [.volcano, .hollowCourt])
    }
}
