import Foundation
import SwiftUI

enum PrototypeContent {
    static let fireball = SpellDefinition(
        id: .fireball, incantationsByLocale: ["en-US": ["fireball", "fire ball"]],
        baseCooldownTicks: 120, windupTicks: 16,
        projectile: ProjectileDefinition(speedMetersPerSecond: 24, radiusMeters: 0.2,
            lifetimeTicks: 150, gravityMetersPerSecondSquared: 0, damage: 50, impactStatus: nil),
        presentation: SpellPresentation(bookPage: "ignis", highlightedTextKey: "FIREBALL",
            chargeEffect: "ember", releaseAnimation: "cast", projectileEffect: "fireball"))

    static func stats(_ wizard: WizardClassID) -> WizardStats {
        switch wizard {
        case .pyromancer: return .init(maximumHealth: 100, moveSpeedMetersPerSecond: 5.5, cooldownMultiplier: 0.9)
        case .cryomancer: return .init(maximumHealth: 120, moveSpeedMetersPerSecond: 4.8, cooldownMultiplier: 1)
        case .necromancer: return .init(maximumHealth: 90, moveSpeedMetersPerSecond: 5.8, cooldownMultiplier: 0.95)
        }
    }
}

extension WizardClassID: CaseIterable {
    static var allCases: [WizardClassID] { [.pyromancer, .cryomancer, .necromancer] }
    var title: String {
        switch self { case .pyromancer: return "Pyromancer"; case .cryomancer: return "Cryomancer"; case .necromancer: return "Necromancer" }
    }
    var sigil: String {
        switch self { case .pyromancer: return "flame"; case .cryomancer: return "snowflake"; case .necromancer: return "moon.stars" }
    }
    var subtitle: String {
        switch self { case .pyromancer: return "THE EMBER ORDER"; case .cryomancer: return "THE FROST ORDER"; case .necromancer: return "THE VEIL ORDER" }
    }
}

struct Solid: Sendable {
    let center: SIMD3<Float>
    let half: SIMD3<Float>
}

enum ArenaMath {
    static func forward(yaw: Float, pitch: Float) -> SIMD3<Float> {
        SIMD3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))
    }

    // Ray/segment against an expanded AABB; returns earliest t in [0,1].
    static func segmentHit(from a: SIMD3<Float>, to b: SIMD3<Float>, solid: Solid,
                           radius: Float = 0) -> Float? {
        let minCorner = solid.center - solid.half - SIMD3(repeating: radius)
        let maxCorner = solid.center + solid.half + SIMD3(repeating: radius)
        let delta = b - a
        var lo: Float = 0
        var hi: Float = 1
        for i in 0..<3 {
            if abs(delta[i]) < 0.00001 {
                if a[i] < minCorner[i] || a[i] > maxCorner[i] { return nil }
            } else {
                let t0 = (minCorner[i] - a[i]) / delta[i]
                let t1 = (maxCorner[i] - a[i]) / delta[i]
                lo = max(lo, min(t0, t1)); hi = min(hi, max(t0, t1))
                if lo > hi { return nil }
            }
        }
        return lo
    }

    static func segmentSphere(from a: SIMD3<Float>, to b: SIMD3<Float>,
                              center: SIMD3<Float>, radius: Float) -> Float? {
        let d = b - a, m = a - center
        let aa = dot(d, d), bb = dot(m, d), cc = dot(m, m) - radius * radius
        if cc <= 0 { return 0 }
        guard aa > 0.000001, bb <= 0 else { return nil }
        let disc = bb * bb - aa * cc
        guard disc >= 0 else { return nil }
        let t = (-bb - sqrt(disc)) / aa
        return t >= 0 && t <= 1 ? t : nil
    }

    private static func dot(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        a.x * b.x + a.y * b.y + a.z * b.z
    }

    // Axis-separated horizontal capsule footprint against courtyard solids.
    static func move(from p: SIMD3<Float>, delta: SIMD3<Float>, solids: [Solid]) -> SIMD3<Float> {
        var result = p
        for axis in [0, 2] {
            var candidate = result
            candidate[axis] += delta[axis]
            candidate[axis] = min(22.5, max(-22.5, candidate[axis]))
            let blocked = solids.contains { box in
                let x = max(box.center.x - box.half.x, min(candidate.x, box.center.x + box.half.x))
                let z = max(box.center.z - box.half.z, min(candidate.z, box.center.z + box.half.z))
                return pow(candidate.x - x, 2) + pow(candidate.z - z, 2) < 0.38 * 0.38
            }
            if !blocked { result = candidate }
        }
        return result
    }
}
