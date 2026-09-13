import Foundation

// Internal to the game module. Split into the domain files shown in the blueprint.
typealias Tick = UInt64
typealias PlayerID = UInt16       // Host-assigned slot; never trusted from a client payload.
typealias EntityID = UInt32

enum SpellID: UInt16, Codable, Sendable { case fireball = 1, iceShards, mudBlast }
enum WizardClassID: UInt8, Codable, Sendable { case pyromancer = 1, cryomancer, necromancer }
enum MapID: UInt8, Codable, Sendable { case volcano = 1, ice, swamp }

struct Vector3: Codable, Sendable, Equatable {
    var x: Float
    var y: Float
    var z: Float
    var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }
}

struct Aim: Codable, Sendable {
    let yaw: Float               // Radians; authority clamps angular velocity.
    let pitch: Float             // Radians; authority clamps pitch range.
    var isFinite: Bool { yaw.isFinite && pitch.isFinite }
}

struct WizardStats: Codable, Sendable {
    let maximumHealth: Float
    let moveSpeedMetersPerSecond: Float
    let cooldownMultiplier: Float // < 1 is faster. Applied to duration, not rate.
}

struct WizardClassDefinition: Codable, Sendable {
    let id: WizardClassID
    let stats: WizardStats
    let allowedSpells: Set<SpellID>
}

struct ProjectileDefinition: Codable, Sendable {
    let speedMetersPerSecond: Float
    let radiusMeters: Float
    let lifetimeTicks: Tick
    let gravityMetersPerSecondSquared: Float
    let damage: Float
    let impactStatus: StatusEffectDefinition?
}

enum StatusEffectDefinition: Codable, Sendable {
    case slow(speedMultiplier: Float, durationTicks: Tick)
    case damageOverTime(damagePerTick: Float, durationTicks: Tick)
}

struct SpellPresentation: Codable, Sendable {
    let bookPage: String
    let highlightedTextKey: String
    let chargeEffect: String
    let releaseAnimation: String
    let projectileEffect: String
}

struct SpellDefinition: Codable, Sendable {
    let id: SpellID
    let incantationsByLocale: [String: [String]]
    let baseCooldownTicks: Tick
    let windupTicks: Tick
    let projectile: ProjectileDefinition
    let presentation: SpellPresentation
}

struct SurfaceDefinition: Codable, Sendable {
    let accelerationMultiplier: Float
    let brakingMultiplier: Float
    let maximumSpeedMultiplier: Float
}

struct ZoneDefinition: Codable, Sendable {
    let id: UInt16
    let collisionVolumeAsset: String
    let surface: SurfaceDefinition?
    let damagePerSecond: Float
    let visibilityRadiusMeters: Float? // Gameplay visibility, not just fog shading.
}

struct MapDefinition: Codable, Sendable {
    let id: MapID
    let sceneAsset: String
    let collisionAsset: String
    let environmentPreset: String
    let spawnPoints: [Vector3]
    let zones: [ZoneDefinition]
    let contentDigest: String
}

struct PlayerComponent: Sendable {
    let owner: PlayerID
    var wizardClass: WizardClassID
    var lifeID: UInt32
    var health: Float
    var selectedSpell: SpellID
}

struct MovementComponent: Sendable {
    var position: Vector3
    var velocity: Vector3
    var grounded: Bool
    var surfaceID: UInt16
}

struct SpellRuntimeComponent: Sendable {
    var readyAtTick: [SpellID: Tick]
    var activeCast: UUID?
    var releaseAtTick: Tick?
}

struct ProgressionProfile: Codable, Sendable {
    let schemaVersion: UInt16
    var experience: UInt64
    var unlockedClasses: Set<WizardClassID>
    var cosmeticUnlocks: Set<String>
}

struct InputFrame: Codable, Sendable {
    let sequence: UInt32
    let clientTick: Tick
    let moveX: Float
    let moveY: Float
    let aim: Aim
    let jumpPressed: Bool
    let selectedSpell: SpellID
    // Deliberately no firePressed or castRequested field.
}

struct CastContext: Sendable {
    let matchEpoch: UUID
    let lifeID: UInt32
    let clientTick: Tick
    let selectedSpell: SpellID
    let aim: Aim
    let canAttemptCast: Bool
}

struct CastIntent: Codable, Sendable {
    let id: UUID
    let matchEpoch: UUID
    let lifeID: UInt32
    let inputTick: Tick
    let spell: SpellID
    let aim: Aim
    // No client damage, position, cooldown, player identity, or voice transcript.
}

struct ProjectileSpawn: Codable, Sendable {
    let entityID: EntityID
    let owner: PlayerID
    let spell: SpellID
    let origin: Vector3
    let velocity: Vector3
}

struct CastAccepted: Codable, Sendable {
    let castID: UUID
    let matchEpoch: UUID
    let lifeID: UInt32
    let acceptedAtTick: Tick
    let releaseAtTick: Tick
    let cooldownEndsAtTick: Tick
    // Sent at acceptance; the authority emits the actual spawn at releaseAtTick.
}

enum CastRejection: UInt8, Codable, Sendable {
    case unavailable, dead, cooldown, invalidAim, invalidTick, invalidSpell, overloaded
}

enum CastResolution: Sendable {
    case accepted(CastAccepted)
    case rejected(id: UUID, epoch: UUID, lifeID: UInt32, reason: CastRejection)
}

struct PacketHeader: Sendable {
    let protocolVersion: UInt16
    let matchEpoch: UUID
    let authorityTerm: UInt32
    let channel: UInt8
    let sequence: UInt32
    let simulationTick: Tick
    let payloadLength: UInt16
}

// Codable aids tooling/replays. The production wire codec is explicit binary,
// fixed-endian, bounded, and versioned; never memcpy Swift struct layouts.
