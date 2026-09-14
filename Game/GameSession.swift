import SwiftUI
import RealityKit
import Combine
import AVFoundation
import simd

@MainActor
final class GameSession: ObservableObject, LocalCastContextProviding, CastIntentSubmitting {
    enum Phase { case menu, loading, playing, paused }
    @Published var phase: Phase = .menu
    @Published var selectedClass: WizardClassID = .pyromancer
    @Published var selectedMap: MapID = .volcano
    @Published var selectedTeam: TeamID = .ember
    @Published var graphicsStatus = "Detailed moonlit rendering. Legacy pixel effects are optional."
    @Published var retroEffectsEnabled = false {
        didSet { UserDefaults.standard.set(retroEffectsEnabled, forKey: "detailedBuildRetroEffects") }
    }
    @Published private(set) var selectedSpell: SpellID = .fireball
    @Published var speechDiagnostic = "No speech errors recorded in this session."
    @Published var musicEnabled = true { didSet { syncMenuMusic() } }
    @Published var progress = 0.0
    @Published var loadingMessage = "Opening the grimoire"
    @Published var voiceStatus = "Microphone is asleep"
    @Published var voiceActive = false
    @Published var microphoneLevel: Float = 0
    @Published var transcript = ""
    @Published var defeated = 0
    @Published var health: Float = 100
    @Published var cooldown: Float = 0
    @Published var hitFlash: Float = 0
    @Published var banner = ""
    @Published var errorMessage: String?
    @Published var requestingVoice = false
    @Published var sensitivity: Float = 1
    @Published var invertY = false
    @Published var reducedMotion = false
    @Published var soundEnabled = true
    @Published var audioStatus = "Use Test sound to check the current iPhone output."
    let input = InputRouter()
    private(set) var view: ARView?
    private let voice = SpeechRecognitionService()
    private var engine: SpellEngine?
    private var arena: ArenaBuilder.Result?
    private var rig: RigFactory.Result?
    private var retroRenderer: RetroRenderer?
    private var link: CADisplayLink?
    private var frameDriver: FrameDriver?
    private var lastFrame: TimeInterval = 0
    private var accumulator: TimeInterval = 0
    private var tick: Tick = 0
    private var epoch = UUID()
    private var life: UInt32 = 1
    private var readyAt: Tick = 0
    private var busyUntil: Tick = 0
    private var position = SIMD3<Float>(0, 1.65, 12)
    private var yaw: Float = 0
    private var pitch: Float = 0
    private var movement = SIMD2<Float>.zero
    private var pending: [CastIntent] = []
    private var casts: [(intent: CastIntent, release: Tick)] = []
    private var targets: [Target] = []
    private var projectiles: [Projectile] = []
    private var sparks: [Spark] = []
    private var bannerUntil: Tick = 0
    private var loadTask: Task<Void, Never>?
    private var loadToken = UUID()
    private var sound: [String: AVAudioPlayer] = [:]
    private var menuMusic: AVAudioPlayer?
    private var applicationActive = true
    private var activeMap: MapID = .volcano
    private var activeTeam: TeamID = .ember
    private static let volcanoSessionKey = "unfinishedVolcanoSession"

    private struct Target {
        let entity: Entity
        let position: SIMD3<Float>
        var health: Float = 100
        var respawn: Tick = 0
        var nextAttack: Tick = 180
    }
    private struct Projectile {
        let entity: Entity
        var velocity = SIMD3<Float>.zero
        var expires: Tick = 0
        var hostile = false
        var spell: SpellID = .fireball
    }
    private struct Spark {
        let entity: Entity
        var expires: Tick = 0
    }

    init() {
        retroEffectsEnabled = (UserDefaults.standard.object(forKey: "detailedBuildRetroEffects") as? Bool) ?? false
        if UserDefaults.standard.bool(forKey: Self.volcanoSessionKey) {
            retroEffectsEnabled = false
            UserDefaults.standard.set(false, forKey: "detailedBuildRetroEffects")
            let stage = UserDefaults.standard.string(forKey: "lastVolcanoStage") ?? "unknown stage"
            graphicsStatus = "The last volcano session ended unexpectedly at: \(stage). Retro effects are off for the next attempt."
        }
        input.onPause = { [weak self] in self?.pause() }
        input.onPageTurn = { [weak self] direction in self?.cycleSpell(direction) }
        voice.onDiagnostic = { [weak self] message in self?.speechDiagnostic = message }
        voice.onStatus = { [weak self] text, level in
            self?.voiceStatus = text; self?.microphoneLevel = level
        }
    }

    func enterCourt() {
        guard phase == .menu, loadTask == nil else { return }
        phase = .loading; progress = 0; errorMessage = nil
        activeMap = selectedMap; menuMusic?.stop()
        activeTeam = selectedTeam
        UserDefaults.standard.set(activeMap == .volcano && retroEffectsEnabled, forKey: Self.volcanoSessionKey)
        let token = UUID(); loadToken = token
        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { if self.loadToken == token { self.loadTask = nil } }
            do {
                let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
                self.view = view
                let report: (Double, String) async -> Void = { [weak self] amount, text in
                    if self?.loadToken == token {
                        self?.progress = amount; self?.loadingMessage = text
                        if self?.activeMap == .volcano { UserDefaults.standard.set(text, forKey: "lastVolcanoStage") }
                    }
                    await Task.yield()
                }
                let builtArena: ArenaBuilder.Result
                if self.activeMap == .volcano {
                    builtArena = try await VolcanoBuilder.build(view: view, progress: report)
                    guard !Task.isCancelled, self.loadToken == token else { return }
                    if self.retroEffectsEnabled {
                        let renderer = RetroRenderer(map: .volcano) { [weak self] message in
                            Task { @MainActor in
                                guard let self, self.loadToken == token, self.retroRenderer != nil else { return }
                                self.graphicsStatus = message
                                self.retroEffectsEnabled = false
                                self.view?.renderCallbacks.postProcess = nil
                                self.retroRenderer = nil
                                UserDefaults.standard.set(message, forKey: "lastVolcanoStage")
                                UserDefaults.standard.set(false, forKey: Self.volcanoSessionKey)
                            }
                        }
                        self.retroRenderer = renderer
                        renderer.update(camera: builtArena.camera.transform.matrix)
                        // Pass a nonisolated method directly; never inherit MainActor
                        // isolation in a closure executed by RealityKit's render thread.
                        view.renderCallbacks.postProcess = renderer.render
                        UserDefaults.standard.set("Preparing the first retro frame", forKey: "lastVolcanoStage")
                    }
                } else { builtArena = await ArenaBuilder.build(view: view, progress: report) }
                guard !Task.isCancelled, self.loadToken == token else { return }
                self.arena = builtArena
                let arena = builtArena
                self.progress = 0.86; self.loadingMessage = "Illuminating your grimoire"
                self.rig = try RigFactory.make(camera: arena.camera)
                self.rig?.book.onTranscript = { [weak self] text in self?.transcript = text }
                guard let rig = self.rig else { return }
                rig.controller.select(PrototypeContent.definition(self.selectedSpell))
                self.engine = SpellEngine(voice: self.voice, context: self, submitter: self,
                    rig: rig.controller, spells: PrototypeContent.spells) { [weak self] message in
                        self?.voiceStatus = message; self?.voiceActive = false
                        self?.speechDiagnostic = message
                    }
                self.prewarmEffects(root: arena.root)
                self.activatePlayback()
                self.targets = arena.targets.enumerated().map {
                    Target(entity: $0.element, position: $0.element.position, nextAttack: Tick(240 + $0.offset * 90))
                }
                self.resetRound()
                self.progress = 1; self.loadingMessage = "The court is ready"
                await Task.yield()
                guard !Task.isCancelled else { return }
                self.phase = .playing
                self.startFrames()
                await self.enableVoice()
            } catch {
                guard self.loadToken == token, !Task.isCancelled else { return }
                self.errorMessage = "The court could not open: \(error.localizedDescription)"
                self.leave()
            }
        }
    }

    func syncMenuMusic() {
        guard phase == .menu, musicEnabled, applicationActive else { menuMusic?.pause(); return }
        do {
            try GameAudioSession.activate(recording: false)
            if menuMusic == nil {
                guard let url = Bundle.main.url(forResource: "menu", withExtension: "wav") else {
                    audioStatus = "Menu music is missing from this build."; return
                }
                let player = try AVAudioPlayer(contentsOf: url)
                player.numberOfLoops = -1; player.volume = 0.28; player.prepareToPlay()
                menuMusic = player
            }
            if menuMusic?.isPlaying == false, menuMusic?.play() == false {
                audioStatus = "Menu music could not start. Try Test sound in Settings."
            }
        } catch { audioStatus = "Menu audio: \(error.localizedDescription)" }
    }

    func applicationBecameActive() {
        applicationActive = true
        if activeMap == .volcano, retroRenderer != nil {
            UserDefaults.standard.set(true, forKey: Self.volcanoSessionKey)
        }
        syncMenuMusic()
    }

    func selectSpell(_ spell: SpellID) {
        guard phase == .playing, tick >= busyUntil else { return }
        selectedSpell = spell; rig?.controller.select(PrototypeContent.definition(spell))
    }

    func cycleSpell(_ direction: Int) {
        let all = SpellID.allCases
        guard let index = all.firstIndex(of: selectedSpell) else { return }
        selectSpell(all[(index + direction + all.count) % all.count])
    }

    func selectSpellFromVoice(_ spell: SpellID) -> Bool {
        guard phase == .playing, health > 0, tick >= busyUntil else { return false }
        selectSpell(spell)
        return selectedSpell == spell
    }

    private func prewarmEffects(root: Entity) {
        projectiles = (0..<32).map { _ in
            let entity = ArenaBuilder.orb(0.19, .zero, .orange, in: root)
            entity.isEnabled = false
            return Projectile(entity: entity)
        }
        sparks = (0..<24).map { _ in
            let entity = ArenaBuilder.orb(0.28, .zero, .orange, in: root)
            entity.isEnabled = false
            return Spark(entity: entity)
        }
        prepareSounds()
    }

    private func prepareSounds() {
        for key in ["cast", "impact", "hurt"] where sound[key] == nil {
            guard let url = Bundle.main.url(forResource: key, withExtension: "wav") else {
                audioStatus = "Missing bundled sound: \(key).wav. Rebuild the app with Resources included."
                return
            }
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.volume = 0.55
                guard player.prepareToPlay() else {
                    audioStatus = "Could not prepare \(key).wav for playback."; return
                }
                sound[key] = player
            } catch { audioStatus = "Sound loading failed: \(error.localizedDescription)"; return }
        }
    }

    private func activatePlayback() {
        do { try GameAudioSession.activate(recording: voiceActive) }
        catch { audioStatus = "Audio setup failed: \(error.localizedDescription)" }
    }

    func testSound() {
        activatePlayback()
        prepareSounds()
        // Diagnostic preview only. Never submits a cast or bypasses voice activation.
        guard let player = sound["cast"] else { return }
        player.currentTime = 0
        if player.play() {
            let audio = AVAudioSession.sharedInstance()
            let output = audio.currentRoute.outputs.map(\.portName).joined(separator: ", ")
            audioStatus = "Test playing on \(output). iPhone volume: \(Int(audio.outputVolume * 100))%."
        } else { audioStatus = "iOS could not start playback. Check the output device and retry." }
    }

    private func resetRound() {
        tick = 0; epoch = UUID(); life = 1; readyAt = 0; busyUntil = 0
        applySpawn(); defeated = 0
        health = PrototypeContent.stats(selectedClass).maximumHealth
        pending.removeAll(); casts.removeAll(); input.reset()
        banner = activeMap == .volcano ? "Cross the bridges. Avoid the lava. Speak a spell." : "Speak a spell. Banish the sentinels."
        bannerUntil = 300
    }

    func enableVoice() async {
        guard phase == .playing, !requestingVoice else { return }
        requestingVoice = true
        defer { requestingVoice = false }
        let permitted = await SpeechRecognitionService.requestAccess()
        guard phase == .playing else { return }
        guard permitted else {
            voiceStatus = SpeechRecognitionService.permissionHelp; voiceActive = false
            return
        }
        do { try engine?.start(locale: "en-US"); voiceActive = true }
        catch { voiceStatus = error.localizedDescription; voiceActive = false }
    }

    func toggleVoice() {
        if voiceActive {
            engine?.stop(); voiceActive = false; voiceStatus = "Microphone is asleep · tap to listen"
        } else { Task { await enableVoice() } }
    }

    func pause() {
        guard phase == .playing else { return }
        phase = .paused; engine?.stop(); voiceActive = false
        for player in sound.values { player.stop() }
        pending.removeAll(); casts.removeAll(); input.reset()
        link?.isPaused = true; lastFrame = 0; accumulator = 0
    }

    func suspend() {
        UserDefaults.standard.set(false, forKey: Self.volcanoSessionKey)
        applicationActive = false; menuMusic?.pause()
        if phase == .loading { leave() } else { pause() }
    }

    func resume() {
        guard phase == .paused else { return }
        phase = .playing; lastFrame = 0; accumulator = 0; link?.isPaused = false
        activatePlayback()
        Task { await enableVoice() }
    }

    func leave() {
        UserDefaults.standard.set(false, forKey: Self.volcanoSessionKey)
        loadToken = UUID()
        loadTask?.cancel(); loadTask = nil
        engine?.stop(); engine = nil; voice.stop(); voiceActive = false
        link?.invalidate(); link = nil; frameDriver = nil
        view?.renderCallbacks.postProcess = nil
        view?.scene.anchors.removeAll(); view = nil; arena = nil; rig = nil
        retroRenderer = nil
        projectiles.removeAll(); sparks.removeAll(); targets.removeAll()
        pending.removeAll(); casts.removeAll(); input.reset()
        for player in sound.values { player.stop() }
        sound.removeAll(); GameAudioSession.deactivate()
        phase = .menu
        syncMenuMusic()
    }

    func currentCastContext() -> CastContext? {
        guard phase == .playing else { return nil }
        return CastContext(matchEpoch: epoch, lifeID: life, clientTick: tick, selectedSpell: selectedSpell,
            aim: Aim(yaw: yaw, pitch: pitch),
            canAttemptCast: health > 0 && tick >= readyAt && tick >= busyUntil)
    }

    enum CastError: Error { case unavailable }
    func enqueue(_ intent: CastIntent) throws {
        guard phase == .playing, intent.matchEpoch == epoch, intent.lifeID == life,
              pending.count < 4 else { throw CastError.unavailable }
        pending.append(intent)
    }

    private func startFrames() {
        lastFrame = 0; accumulator = 0
        let driver = FrameDriver { [weak self] time in self?.frame(time) }
        frameDriver = driver
        let link = CADisplayLink(target: driver, selector: #selector(FrameDriver.step(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common); self.link = link
    }

    private func frame(_ time: TimeInterval) {
        guard phase == .playing, let arena else { return }
        if lastFrame == 0 { lastFrame = time; return }
        let dt = min(0.066, time - lastFrame); lastFrame = time
        let inputFrame = input.sample(deltaTime: Float(dt), sensitivity: sensitivity, invertedY: invertY)
        guard phase == .playing else { return }
        movement = inputFrame.move
        yaw -= inputFrame.look.x
        pitch = min(1.15, max(-1.15, pitch - inputFrame.look.y))
        accumulator += dt
        while accumulator >= 1.0 / 60.0 { simulate(); accumulator -= 1.0 / 60.0 }
        let bob: Float = reducedMotion ? 0 : sin(Float(tick) * 0.13) * min(1, simd_length(movement)) * 0.018
        arena.camera.position = position + [0, bob, 0]
        arena.camera.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0]) * simd_quatf(angle: pitch, axis: [1, 0, 0])
        retroRenderer?.update(camera: arena.camera.transform.matrix)
        rig?.controller.update(authorityTick: tick)
        rig?.hand.update(delta: Float(dt), motion: !reducedMotion)
        rig?.book.update(delta: Float(dt), motion: !reducedMotion)
        engine?.update()
        for (i, wisp) in arena.wisps.enumerated() where !reducedMotion {
            wisp.position.y += sin(Float(tick) * 0.012 + Float(i)) * Float(dt) * 0.13
        }
        if tick % 6 == 0 {
            let duration = Float(PrototypeContent.definition(selectedSpell).baseCooldownTicks) * PrototypeContent.stats(selectedClass).cooldownMultiplier
            cooldown = tick >= readyAt ? 0 : min(1, Float(readyAt - tick) / duration)
        }
        if hitFlash > 0 { hitFlash = max(0, hitFlash - Float(dt) * 2.5) }
    }

    private func simulate() {
        guard let arena else { return }
        tick += 1
        let stats = PrototypeContent.stats(selectedClass)
        let planar = SIMD3<Float>(movement.x * cos(yaw) - movement.y * sin(yaw), 0,
                                  -movement.x * sin(yaw) - movement.y * cos(yaw))
        position = ArenaMath.move(from: position, delta: planar * (stats.moveSpeedMetersPerSecond / 60), solids: arena.solids,
                                  boundary: activeMap == .volcano ? VolcanoLayout.boundary : 22.5,
                                  depthBoundary: activeMap == .volcano ? VolcanoLayout.depthBoundary : nil)
        if activeMap == .volcano, VolcanoLayout.isLava(position) {
            health = max(0, health - 24.0 / 60)
            if tick % 30 == 0 { hitFlash = 0.6; play("hurt"); banner = "LAVA BURNS · Find a stone bridge"; bannerUntil = tick + 45 }
        }
        let intents = pending; pending.removeAll(keepingCapacity: true)
        for intent in intents {
            guard intent.matchEpoch == epoch, intent.lifeID == life else { continue }
            guard let spell = PrototypeContent.spells[intent.spell] else {
                engine?.resolve(.rejected(id: intent.id, epoch: epoch, lifeID: life, reason: .invalidSpell)); continue
            }
            if !intent.aim.isFinite || tick < readyAt || tick < busyUntil || health <= 0 {
                engine?.resolve(.rejected(id: intent.id, epoch: epoch, lifeID: life, reason: .cooldown)); continue
            }
            readyAt = tick + Tick(ceil(Float(spell.baseCooldownTicks) * stats.cooldownMultiplier))
            busyUntil = tick + spell.windupTicks
            casts.append((intent, busyUntil))
            engine?.resolve(.accepted(CastAccepted(castID: intent.id, matchEpoch: epoch, lifeID: life,
                acceptedAtTick: tick, releaseAtTick: busyUntil, cooldownEndsAtTick: readyAt)))
        }
        for cast in casts where cast.release <= tick {
            let spell = PrototypeContent.definition(cast.intent.spell)
            let direction = ArenaMath.forward(yaw: cast.intent.aim.yaw, pitch: cast.intent.aim.pitch)
            let muzzle = position + direction * 0.55 + [0.14 * cos(yaw), -0.10, -0.14 * sin(yaw)]
            if arena.solids.contains(where: { ArenaMath.segmentHit(from: position, to: muzzle, solid: $0, radius: 0.2) != nil }) {
                impact(at: position + direction * 0.3, hostile: false)
            } else {
                let spread: [Float] = spell.id == .iceShards ? [-0.065, 0, 0.065] : [0]
                for offset in spread {
                    let aim = ArenaMath.forward(yaw: cast.intent.aim.yaw + offset, pitch: cast.intent.aim.pitch)
                    spawn(at: muzzle, velocity: aim * spell.projectile.speedMetersPerSecond, hostile: false, spell: spell.id)
                }
            }
            play("cast"); UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        casts.removeAll { $0.release <= tick }
        for i in targets.indices {
            if targets[i].health <= 0 {
                if tick >= targets[i].respawn {
                    targets[i].health = 100; targets[i].entity.isEnabled = true; targets[i].nextAttack = tick + 240
                }
            } else if tick >= targets[i].nextAttack {
                let origin = targets[i].position + SIMD3<Float>(0, 1.25, 0.5)
                let delta = position - [0, 0.4, 0] - origin
                if simd_length(delta) > 0.1 { spawn(at: origin, velocity: simd_normalize(delta) * 7, hostile: true) }
                targets[i].nextAttack = tick + 300
            }
        }
        updateProjectiles()
        for i in sparks.indices where sparks[i].entity.isEnabled {
            if tick >= sparks[i].expires { sparks[i].entity.isEnabled = false }
            else { sparks[i].entity.scale *= SIMD3(repeating: 1.055) }
        }
        if tick > bannerUntil && !banner.isEmpty { banner = "" }
    }

    private func spawn(at position: SIMD3<Float>, velocity: SIMD3<Float>, hostile: Bool, spell: SpellID = .fireball) {
        guard let i = projectiles.firstIndex(where: { !$0.entity.isEnabled }) else { return }
        projectiles[i].entity.position = position; projectiles[i].entity.isEnabled = true
        if let model = projectiles[i].entity as? ModelEntity {
            model.model?.materials = [UnlitMaterial(color: hostile ? .purple : spell.color)]
        }
        let definition = PrototypeContent.definition(spell).projectile
        let radius: Float = hostile ? 0.19 : definition.radiusMeters
        projectiles[i].entity.scale = SIMD3(repeating: radius / 0.19)
        if !hostile && spell == .iceShards { projectiles[i].entity.scale.z *= 2.3 }
        projectiles[i].entity.orientation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: simd_normalize(velocity))
        projectiles[i].spell = spell
        projectiles[i].velocity = velocity; projectiles[i].hostile = hostile
        projectiles[i].expires = tick + (hostile ? 220 : definition.lifetimeTicks)
    }

    private func updateProjectiles() {
        guard let arena else { return }
        for i in projectiles.indices where projectiles[i].entity.isEnabled {
            let spell = PrototypeContent.definition(projectiles[i].spell).projectile
            let radius: Float = projectiles[i].hostile ? 0.19 : spell.radiusMeters
            if !projectiles[i].hostile { projectiles[i].velocity.y -= spell.gravityMetersPerSecondSquared / 60 }
            let a = projectiles[i].entity.position, b = a + projectiles[i].velocity / 60
            if tick >= projectiles[i].expires || b.y < 0 || abs(b.x) > 25 || abs(b.z) > 25 {
                projectiles[i].entity.isEnabled = false; continue
            }
            var firstHit: Float = 2
            var targetIndex: Int?
            for solid in arena.solids {
                if let t = ArenaMath.segmentHit(from: a, to: b, solid: solid, radius: radius) { firstHit = min(firstHit, t) }
            }
            if projectiles[i].hostile {
                if let t = ArenaMath.segmentSphere(from: a, to: b, center: position - [0, 0.4, 0], radius: 0.65), t < firstHit {
                    firstHit = t; health = max(0, health - 10); hitFlash = 1; play("hurt")
                }
            } else {
                for j in targets.indices where targets[j].health > 0 {
                    if let t = ArenaMath.segmentSphere(from: a, to: b, center: targets[j].position + [0, 1.15, 0], radius: 0.65 + radius), t < firstHit {
                        firstHit = t; targetIndex = j
                    }
                }
            }
            if firstHit <= 1 {
                let hit = a + (b - a) * firstHit
                impact(at: hit, hostile: projectiles[i].hostile, spell: projectiles[i].spell)
                projectiles[i].entity.isEnabled = false
                if let j = targetIndex {
                    targets[j].health -= spell.damage; play("impact")
                    if targets[j].health <= 0 {
                        targets[j].entity.isEnabled = false; targets[j].respawn = tick + 360; defeated += 1
                        if defeated == 10 { banner = "TRIAL MASTERED · The court knows your name."; bannerUntil = tick + 300 }
                    } else { banner = "Sentinel struck · \(Int(spell.damage)) damage"; bannerUntil = tick + 50 }
                }
            } else { projectiles[i].entity.position = b }
        }
        if health <= 0 { respawn() }
    }

    private func impact(at p: SIMD3<Float>, hostile: Bool, spell: SpellID = .fireball) {
        guard let i = sparks.firstIndex(where: { !$0.entity.isEnabled }) else { return }
        sparks[i].entity.position = p; sparks[i].entity.scale = SIMD3(repeating: 0.35)
        sparks[i].entity.isEnabled = true; sparks[i].expires = tick + 14
        if let model = sparks[i].entity as? ModelEntity { model.model?.materials = [UnlitMaterial(color: hostile ? .purple : spell.color)] }
    }

    private func respawn() {
        engine?.stop(); voiceActive = false; pending.removeAll(); casts.removeAll(); life += 1
        applySpawn(); health = PrototypeContent.stats(selectedClass).maximumHealth
        readyAt = tick + 60; busyUntil = readyAt
        for i in projectiles.indices { projectiles[i].entity.isEnabled = false }
        banner = activeMap == .volcano ? "Returned to \(activeTeam.title) · tap the microphone" : "Your spirit returns · tap the microphone to listen"
        bannerUntil = tick + 300
        voiceStatus = "Microphone is asleep · tap to listen"; input.reset()
    }

    private func applySpawn() {
        let spawn = TeamBases.spawn(map: activeMap, team: activeTeam)
        position = spawn.position; yaw = spawn.yaw; pitch = 0; movement = .zero
        arena?.camera.position = position
        arena?.camera.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
        if let camera = arena?.camera { retroRenderer?.update(camera: camera.transform.matrix) }
    }

    private func play(_ key: String) {
        guard soundEnabled, let player = sound[key] else { return }
        player.currentTime = 0
        if !player.play() { audioStatus = "Sound playback failed. Open Settings → Test sound to reconnect." }
    }
}

@MainActor
private final class FrameDriver: NSObject {
    let callback: (TimeInterval) -> Void
    init(_ callback: @escaping (TimeInterval) -> Void) { self.callback = callback }
    @objc func step(_ link: CADisplayLink) { callback(link.timestamp) }
}
