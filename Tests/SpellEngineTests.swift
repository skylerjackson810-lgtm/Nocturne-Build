import XCTest
@testable import Nocturne

@MainActor
final class SpellEngineTests: XCTestCase {
    private final class Voice: VoiceRecognizing {
        var token: UUID?
        var continuation: AsyncStream<VoiceEvent>.Continuation?
        func start(session: UUID, locale: String, phrases: [String]) throws -> AsyncStream<VoiceEvent> {
            token = session
            return AsyncStream(bufferingPolicy: .bufferingNewest(16)) { continuation = $0 }
        }
        func stop() { continuation?.finish(); continuation = nil }
        func sendFinal(_ id: UInt64, text: String = "Fireball", session: UUID? = nil) {
            continuation?.yield(.final(session: session ?? token!, utterance: id, text: text,
                                       capturedAt: ProcessInfo.processInfo.systemUptime))
        }
    }
    private final class Context: LocalCastContextProviding {
        let epoch = UUID()
        var ready = true
        var selected: SpellID = .fireball
        func selectSpellFromVoice(_ spell: SpellID) -> Bool { selected = spell; return true }
        func currentCastContext() -> CastContext? {
            CastContext(matchEpoch: epoch, lifeID: 1, clientTick: 20, selectedSpell: selected,
                        aim: Aim(yaw: 0, pitch: 0), canAttemptCast: ready)
        }
    }
    private final class Sink: CastIntentSubmitting {
        var intents: [CastIntent] = []
        func enqueue(_ intent: CastIntent) throws { intents.append(intent) }
    }
    private final class Rig: RigPresenting {
        var charges = 0
        func select(_ spell: SpellDefinition) {}
        func showTranscript(_ text: String) {}
        func beginVoiceCast(id: UUID, spell: SpellDefinition) { charges += 1 }
        func accept(_ cast: CastAccepted) {}
        func reject(id: UUID) {}
        func reset() {}
    }

    func testPartialCannotCastAndFinalIsConsumedOnce() async throws {
        let voice = Voice(), context = Context(), sink = Sink(), rig = Rig()
        let engine = SpellEngine(voice: voice, context: context, submitter: sink, rig: rig,
            spells: [.fireball: PrototypeContent.fireball], onVoiceFailure: { _ in })
        try engine.start(locale: "en-US")
        defer { engine.stop() }
        voice.continuation?.yield(.partial(session: voice.token!, text: "Fireball"))
        await settle()
        XCTAssertTrue(sink.intents.isEmpty)
        voice.sendFinal(1)
        await settle()
        XCTAssertEqual(sink.intents.count, 1)
        let cast = try XCTUnwrap(sink.intents.first)
        engine.resolve(.rejected(id: cast.id, epoch: context.epoch, lifeID: 1, reason: .cooldown))
        voice.sendFinal(1)
        await settle()
        XCTAssertEqual(sink.intents.count, 1)
        XCTAssertEqual(rig.charges, 1)
    }

    func testCooldownUtteranceDoesNotBecomeDelayedShot() async throws {
        let voice = Voice(), context = Context(), sink = Sink(), rig = Rig()
        let engine = SpellEngine(voice: voice, context: context, submitter: sink, rig: rig,
            spells: [.fireball: PrototypeContent.fireball], onVoiceFailure: { _ in })
        try engine.start(locale: "en-US")
        defer { engine.stop() }
        context.ready = false; voice.sendFinal(1); await settle()
        context.ready = true; voice.sendFinal(1); await settle()
        XCTAssertTrue(sink.intents.isEmpty)
        voice.sendFinal(2); await settle()
        XCTAssertEqual(sink.intents.count, 1)
    }

    func testWrongPhraseAndRetiredSessionCannotCast() async throws {
        let voice = Voice(), context = Context(), sink = Sink(), rig = Rig()
        let engine = SpellEngine(voice: voice, context: context, submitter: sink, rig: rig,
            spells: [.fireball: PrototypeContent.fireball], onVoiceFailure: { _ in })
        try engine.start(locale: "en-US")
        defer { engine.stop() }
        voice.sendFinal(1, text: "please fireball now"); await settle()
        voice.sendFinal(2, session: UUID()); await settle()
        XCTAssertTrue(sink.intents.isEmpty)
    }

    private func settle() async {
        // Yield to the AsyncStream consumer without wall-clock sleeps.
        for _ in 0..<8 { await Task.yield() }
    }

    func testEveryNamedSpellSelectsAndCastsAcrossRepeatedUtterances() async throws {
        let voice = Voice(), context = Context(), sink = Sink(), rig = Rig()
        let engine = SpellEngine(voice: voice, context: context, submitter: sink, rig: rig,
            spells: PrototypeContent.spells, onVoiceFailure: { _ in XCTFail("Unexpected voice failure") })
        try engine.start(locale: "en-US")
        defer { engine.stop() }
        for (index, spell) in PrototypeContent.spellbook.enumerated() {
            voice.sendFinal(UInt64(index + 1), text: spell.id.title)
            await settle()
            XCTAssertEqual(context.selected, spell.id)
            let cast = try XCTUnwrap(sink.intents.last)
            XCTAssertEqual(cast.spell, spell.id)
            engine.resolve(.accepted(.init(castID: cast.id, matchEpoch: context.epoch, lifeID: 1,
                acceptedAtTick: 20, releaseAtTick: 30, cooldownEndsAtTick: 120)))
        }
        XCTAssertEqual(sink.intents.count, 4)
        XCTAssertEqual(rig.charges, 4)
    }

    func testVoiceCanTurnPageDuringCooldownWithoutQueuingADeferredShot() async throws {
        let voice = Voice(), context = Context(), sink = Sink(), rig = Rig()
        let engine = SpellEngine(voice: voice, context: context, submitter: sink, rig: rig,
            spells: PrototypeContent.spells, onVoiceFailure: { _ in })
        try engine.start(locale: "en-US"); defer { engine.stop() }
        context.ready = false
        voice.sendFinal(1, text: "Ice Shards"); await settle()
        XCTAssertEqual(context.selected, .iceShards)
        XCTAssertTrue(sink.intents.isEmpty)
        context.ready = true
        voice.sendFinal(1, text: "Ice Shards"); await settle()
        XCTAssertTrue(sink.intents.isEmpty)
        voice.sendFinal(2, text: "Ice Shards"); await settle()
        XCTAssertEqual(sink.intents.count, 1)
    }

    func testTouchSelectionCannotFireAndRestartRejectsPriorSession() async throws {
        let voice = Voice(), context = Context(), sink = Sink(), rig = Rig()
        let engine = SpellEngine(voice: voice, context: context, submitter: sink, rig: rig,
            spells: PrototypeContent.spells, onVoiceFailure: { _ in })
        try engine.start(locale: "en-US"); let old = try XCTUnwrap(voice.token)
        context.selected = .mudBlast; await settle()
        XCTAssertTrue(sink.intents.isEmpty)
        try engine.start(locale: "en-US"); defer { engine.stop() }
        voice.sendFinal(1, text: "Mud Blast", session: old); await settle()
        XCTAssertTrue(sink.intents.isEmpty)
        voice.sendFinal(1, text: "Mud Blast"); await settle()
        XCTAssertEqual(sink.intents.count, 1)
    }
}
