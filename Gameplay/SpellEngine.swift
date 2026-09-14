import Foundation

enum VoiceEvent: Sendable {
    case partial(session: UUID, text: String)
    case final(session: UUID, utterance: UInt64, text: String, capturedAt: TimeInterval)
    case unavailable(session: UUID, reason: String)
}

@MainActor
protocol VoiceRecognizing: AnyObject {
    // Must install observation before starting capture. Events are ordered.
    // Start failures throw; final-stream overflow terminates capture with an error.
    func start(session: UUID, locale: String, phrases: [String]) throws -> AsyncStream<VoiceEvent>
    func stop()
}

@MainActor
protocol LocalCastContextProviding: AnyObject {
    func currentCastContext() -> CastContext?
    func selectSpellFromVoice(_ spell: SpellID) -> Bool
}

extension LocalCastContextProviding {
    func selectSpellFromVoice(_ spell: SpellID) -> Bool { currentCastContext()?.selectedSpell == spell }
}

@MainActor
protocol CastIntentSubmitting: AnyObject {
    // Synchronous bounded enqueue, not remote acceptance. Must not synchronously
    // reenter SpellEngine. Host-local intents enter the same validator as remote ones.
    func enqueue(_ intent: CastIntent) throws
}

@MainActor
protocol RigPresenting: AnyObject {
    func select(_ spell: SpellDefinition)
    func showTranscript(_ text: String)
    func beginVoiceCast(id: UUID, spell: SpellDefinition)
    func accept(_ cast: CastAccepted)
    func reject(id: UUID)
    func reset()
}

@MainActor
final class SpellEngine {
    private struct Pending {
        let intent: CastIntent
        let deadline: TimeInterval
    }

    private let voice: any VoiceRecognizing
    private let context: any LocalCastContextProviding
    private let submitter: any CastIntentSubmitting
    private let rig: any RigPresenting
    private let spells: [SpellID: SpellDefinition]
    private let onVoiceFailure: (String) -> Void
    private var voiceTask: Task<Void, Never>?
    private var session: UUID?
    private var lastUtterance: UInt64?
    private var pending: Pending?
    private var aliases: [String: SpellID] = [:]
    private var locale = Locale(identifier: "en-US")
    private var lastTranscriptUpdate: TimeInterval = 0

    init(voice: any VoiceRecognizing,
         context: any LocalCastContextProviding,
         submitter: any CastIntentSubmitting,
         rig: any RigPresenting,
         spells: [SpellID: SpellDefinition],
         onVoiceFailure: @escaping (String) -> Void) {
        self.voice = voice
        self.context = context
        self.submitter = submitter
        self.rig = rig
        self.spells = spells
        self.onVoiceFailure = onVoiceFailure
    }

    enum StartError: Error { case ambiguousIncantation, emptyLexicon }

    func start(locale identifier: String) throws {
        stop()
        locale = Locale(identifier: identifier)
        aliases.removeAll(keepingCapacity: true)
        var phrases: [String] = []
        for definition in spells.values {
            for phrase in definition.incantationsByLocale[identifier] ?? [] {
                let key = normalize(phrase)
                guard !key.isEmpty else { continue }
                if let old = aliases[key], old != definition.id {
                    throw StartError.ambiguousIncantation
                }
                aliases[key] = definition.id
                phrases.append(phrase)
            }
        }
        guard !aliases.isEmpty else { throw StartError.emptyLexicon }
        let token = UUID()
        let stream: AsyncStream<VoiceEvent>
        do {
            stream = try voice.start(session: token, locale: identifier, phrases: phrases)
        } catch {
            voice.stop()
            throw error
        }
        session = token
        voiceTask = Task { @MainActor [weak self] in
            for await event in stream {
                guard !Task.isCancelled else { break }
                self?.consume(event)
            }
            guard let self, self.session == token else { return }
            self.failVoice("Voice recognition stopped")
        }
    }

    func stop() {
        session = nil                 // Invalidates queued callbacks before cancellation.
        voiceTask?.cancel()
        voiceTask = nil
        voice.stop()
        lastUtterance = nil
        pending = nil
        rig.reset()
    }

    // Called from the frame coordinator, and during an explicit life transition.
    func update(now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard let pending else { return }
        let current = context.currentCastContext()
        if now >= pending.deadline || current?.lifeID != pending.intent.lifeID ||
            current?.matchEpoch != pending.intent.matchEpoch {
            rig.reject(id: pending.intent.id)
            self.pending = nil
        }
    }

    // Only authenticated authority messages reach this method through MatchSession.
    func resolve(_ result: CastResolution) {
        guard let pending else { return }
        switch result {
        case .accepted(let accepted):
            guard accepted.castID == pending.intent.id,
                  accepted.matchEpoch == pending.intent.matchEpoch,
                  accepted.lifeID == pending.intent.lifeID else { return }
            rig.accept(accepted)
        case .rejected(let id, let epoch, let life, _):
            guard id == pending.intent.id, epoch == pending.intent.matchEpoch,
                  life == pending.intent.lifeID else { return }
            rig.reject(id: id)
        }
        self.pending = nil
    }

    private func consume(_ event: VoiceEvent) {
        let now = ProcessInfo.processInfo.systemUptime
        switch event {
        case .partial(let token, let text):
            guard token == session, now - lastTranscriptUpdate >= 0.1 else { return }
            lastTranscriptUpdate = now
            rig.showTranscript(String(text.prefix(128)))
        case .unavailable(let token, let reason):
            guard token == session else { return }
            failVoice(reason)
        case .final(let token, let utterance, let text, let capturedAt):
            guard token == session,
                  lastUtterance.map({ utterance > $0 }) ?? true else { return }
            lastUtterance = utterance // Consume even if dead, busy, or on cooldown.
            guard capturedAt.isFinite, capturedAt <= now, now - capturedAt <= 2.5,
                  pending == nil, text.utf8.count <= 256,
                  let spellID = aliases[normalize(text)],
                  context.selectSpellFromVoice(spellID),
                  let state = context.currentCastContext(), state.canAttemptCast,
                  state.selectedSpell == spellID, state.aim.isFinite,
                  let definition = spells[spellID] else { return }

            let intent = CastIntent(id: UUID(), matchEpoch: state.matchEpoch,
                                    lifeID: state.lifeID, inputTick: state.clientTick,
                                    spell: spellID, aim: state.aim)
            do {
                try submitter.enqueue(intent)
                pending = Pending(intent: intent, deadline: now + 2.0)
                rig.beginVoiceCast(id: intent.id, spell: definition)
            } catch {
                // Admission failure creates no charge/projectile. Surface in HUD.
                onVoiceFailure("Cast could not be queued: \(error.localizedDescription)")
            }
        }
    }

    private func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func failVoice(_ reason: String) {
        stop()
        onVoiceFailure(reason)
    }
}
