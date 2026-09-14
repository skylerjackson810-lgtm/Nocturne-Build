import AVFoundation
import Speech
import Foundation

enum SpeechRoutePolicy {
    static func needsRestart(activeSession: UUID?, observerSession: UUID,
                             previousInput: String, currentInput: String) -> Bool {
        activeSession == observerSession && previousInput != currentInput
    }
}

enum SpeechRetryPolicy {
    static func delay(domain: String, code: Int, consecutiveFailures: Int) -> Double? {
        // Apple's on-device recognizer reports an empty/no-speech task as 1110.
        if domain == "kAFAssistantErrorDomain" && code == 1110 { return 0.4 }
        guard consecutiveFailures < 3 else { return nil }
        return 0.35 * Double(consecutiveFailures + 1)
    }
}

// The game owns playback; stopping speech must never deactivate spell sounds.
@MainActor
enum GameAudioSession {
    static func activate(recording: Bool) throws {
        let session = AVAudioSession.sharedInstance()
        let category: AVAudioSession.Category = recording ? .playAndRecord : .playback
        let options: AVAudioSession.CategoryOptions = recording ? [.defaultToSpeaker, .allowBluetooth] : []
        if session.category != category || session.mode != .default || session.categoryOptions != options {
            try session.setCategory(category, mode: .default, options: options)
        }
        try session.setActive(true)
    }

    static func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// Audio callback bridge. All mutable state is protected by the lock.
private final class SpeechAudioBridge: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var lastVoice: TimeInterval = 0
    private var firstVoice: TimeInterval = 0
    private var lastBuffer: TimeInterval = 0
    private var level: Float = 0

    func replace(_ request: SFSpeechAudioBufferRecognitionRequest?) {
        lock.lock(); defer { lock.unlock() }
        self.request = request; lastVoice = 0; firstVoice = 0; lastBuffer = 0; level = 0
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        var rms: Float = 0
        if let channel = buffer.floatChannelData?[0], buffer.frameLength > 0 {
            for i in 0..<Int(buffer.frameLength) { rms += channel[i] * channel[i] }
            rms = sqrt(rms / Float(buffer.frameLength))
        }
        let now = ProcessInfo.processInfo.systemUptime
        lock.lock(); defer { lock.unlock() }
        guard let request else { return }
        level = rms
        lastBuffer = now
        if rms > 0.004 {
            lastVoice = now
            if firstVoice == 0 { firstVoice = now }
        }
        request.append(buffer)
    }

    func sample() -> (first: TimeInterval, last: TimeInterval, buffer: TimeInterval, level: Float) {
        lock.lock(); defer { lock.unlock() }
        return (firstVoice, lastVoice, lastBuffer, level)
    }
}

@MainActor
final class SpeechRecognitionService: VoiceRecognizing {
    enum Failure: LocalizedError {
        case noMicrophone, onDeviceUnavailable, authorizationDenied
        var errorDescription: String? {
            switch self {
            case .noMicrophone: return "No microphone input is available. Connect a microphone and try again."
            case .onDeviceUnavailable: return "English on-device speech recognition is unavailable on this device."
            case .authorizationDenied: return "Allow Microphone and Speech Recognition in Settings to cast spells."
            }
        }
    }

    var onStatus: ((String, Float) -> Void)?
    var onDiagnostic: ((String) -> Void)?
    private var audioEngine = AVAudioEngine()
    private let bridge = SpeechAudioBridge()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var continuation: AsyncStream<VoiceEvent>.Continuation?
    private var session: UUID?
    private var taskToken = UUID()
    private var utterance: UInt64 = 0
    private var taskStarted: TimeInterval = 0
    private var endTimestamp: TimeInterval = 0
    private var finalizing = false
    private var tapInstalled = false
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var locale = "en-US"
    private var phrases: [String] = []
    private var inputSignature = ""
    private var restartTask: Task<Void, Never>?
    private var consecutiveFailures = 0
    private var firstTranscriptAt: TimeInterval = 0
    private var transcriptAudioAt: TimeInterval = 0
    private var captureRestarts = 0

    static var permissionHelp: String {
        if AVAudioApplication.shared.recordPermission != .granted {
            return "Microphone access is off. Open Settings → Nocturne → Microphone."
        }
        return "Speech Recognition access is off or restricted. Check Settings → Privacy & Security → Speech Recognition."
    }

    static func requestAccess() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        let microphone = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        return speech && microphone
    }

    func start(session: UUID, locale: String, phrases: [String]) throws -> AsyncStream<VoiceEvent> {
        stop()
        var started = false
        defer { if !started { stop() } }
        self.session = session; self.locale = locale; self.phrases = phrases; utterance = 0
        consecutiveFailures = 0
        captureRestarts = 0
        let (recognizer, _) = try OnDeviceSpeechRequest.make(locale: locale, phrases: phrases)
        self.recognizer = recognizer
        try GameAudioSession.activate(recording: true)
        let stream = AsyncStream<VoiceEvent>(bufferingPolicy: .bufferingNewest(32)) { self.continuation = $0 }
        try startCapture()
        beginUtterance()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.inspectAudio() }
        }
        observeAudio(session: session)
        started = true
        return stream
    }

    private func startCapture() throws {
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0 && format.sampleRate > 0 else { throw Failure.noMicrophone }
        let bridge = self.bridge
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in bridge.append(buffer) }
        tapInstalled = true
        audioEngine.prepare()
        try audioEngine.start()
        inputSignature = currentInputSignature()
    }

    private func currentInputSignature() -> String {
        let audio = AVAudioSession.sharedInstance()
        return audio.currentRoute.inputs.map(\.uid).joined(separator: "|")
            + ":\(audio.sampleRate):\(audio.inputNumberOfChannels)"
    }

    private func observeAudio(session expected: UUID) {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification,
            object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    // Category/output-only notifications are normal, not microphone failures.
                    guard SpeechRoutePolicy.needsRestart(activeSession: self.session,
                        observerSession: expected, previousInput: self.inputSignature,
                        currentInput: self.currentInputSignature()) else { return }
                    self.restartCapture()
                }
            })
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
            object: nil, queue: .main) { [weak self] notification in
                let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                Task { @MainActor in
                    guard let self, self.session == expected,
                          type == AVAudioSession.InterruptionType.began.rawValue else { return }
                    self.fail("Audio was interrupted by another app or call. Tap the microphone when it ends.")
                }
            })
        observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.session == expected else { return }
                    self.fail("iOS restarted audio services. Leave and re-enter the court to reconnect audio.")
                }
            })
    }

    private func restartCapture() {
        restartTask?.cancel(); restartTask = nil
        taskToken = UUID()
        bridge.replace(nil)
        recognitionTask?.cancel(); recognitionTask = nil
        request?.endAudio(); request = nil
        stopCapture()
        do {
            try startCapture()
            beginUtterance() // Discard the interrupted phrase; never replay a cast.
        } catch {
            fail("Microphone reconnect failed: \(error.localizedDescription). Tap to retry.")
        }
    }

    private func stopCapture() {
        audioEngine.stop()
        if tapInstalled { audioEngine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        audioEngine = AVAudioEngine()
    }

    private func beginUtterance() {
        guard session != nil, let recognizer else { return }
        taskToken = UUID(); let token = taskToken
        finalizing = false; endTimestamp = 0
        firstTranscriptAt = 0; transcriptAudioAt = 0
        taskStarted = ProcessInfo.processInfo.systemUptime
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.contextualStrings = phrases
        request.taskHint = .confirmation
        self.request = request
        bridge.replace(request)
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            // Framework objects remain on this callback; only value data crosses.
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let message = error?.localizedDescription
            let code = (error as NSError?)?.code ?? 0
            let domain = (error as NSError?)?.domain ?? ""
            Task { @MainActor in
                self?.recognition(token: token, text: text, isFinal: isFinal,
                                  error: message, domain: domain, code: code)
            }
        }
        onStatus?("Listening · speak a spell", 0)
    }

    private func recognition(token: UUID, text: String?, isFinal: Bool, error: String?, domain: String, code: Int) {
        guard token == taskToken, let session else { return }
        if isFinal {
            let audio = bridge.sample()
            // Quiet but recognized speech is valid; an amplitude threshold is not authorization.
            let capturedAt = endTimestamp > 0 ? endTimestamp : (audio.last > 0 ? audio.last : audio.buffer)
            if let text, !text.isEmpty, capturedAt > 0 {
                consecutiveFailures = 0
                captureRestarts = 0
                utterance += 1
                emit(.final(session: session, utterance: utterance, text: text, capturedAt: capturedAt))
            }
            rotate(delay: 0.18, cancelCurrent: false)
        } else if let error {
            recover(message: error, domain: domain, code: code)
        } else if let text, !text.isEmpty {
            if firstTranscriptAt == 0 { firstTranscriptAt = ProcessInfo.processInfo.systemUptime }
            transcriptAudioAt = bridge.sample().buffer
            emit(.partial(session: session, text: String(text.prefix(128))))
        }
    }

    private func recover(message: String, domain: String, code: Int) {
        let details = "\(domain) (\(code)): \(message)"
        onDiagnostic?(details)
        guard SFSpeechRecognizer.authorizationStatus() == .authorized,
              AVAudioApplication.shared.recordPermission == .granted else {
            fail(Self.permissionHelp); return
        }
        guard let delay = SpeechRetryPolicy.delay(domain: domain, code: code,
                                                   consecutiveFailures: consecutiveFailures) else {
            fail("Speech could not reconnect. Tap the microphone to retry. \(details)")
            return
        }
        if !(domain == "kAFAssistantErrorDomain" && code == 1110) { consecutiveFailures += 1 }
        rotate(delay: delay)
        onStatus?("Reconnecting speech…", 0)
    }

    private func inspectAudio() {
        guard session != nil, restartTask == nil else { return }
        if !audioEngine.isRunning {
            guard captureRestarts < 3 else {
                fail("Microphone capture stopped repeatedly. Tap to retry and check the selected audio input.")
                return
            }
            captureRestarts += 1
            onDiagnostic?("Capture engine stopped; rebuilding input (attempt \(captureRestarts)).")
            restartCapture()
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        let audio = bridge.sample()
        onStatus?(finalizing ? "Reading incantation…" : "Listening · speak a spell", min(1, sqrt(audio.level) * 3))
        if finalizing {
            if now - endTimestamp > 4 { recover(message: "Final result timed out", domain: "NocturneSpeech", code: 1) }
        } else if firstTranscriptAt > 0 &&
                    ((now - max(audio.last, transcriptAudioAt) > 0.5) || now - firstTranscriptAt > 3) {
            // A cast sound alone must not close an empty recognition request.
            finalizing = true
            endTimestamp = max(audio.last, transcriptAudioAt)
            bridge.replace(nil) // No appends after endAudio.
            request?.endAudio()
        } else if now - taskStarted > 40 {
            rotate() // Silence/task lifetime bound; never replay audio across tasks.
        }
    }

    private func rotate(delay: Double = 0.18, cancelCurrent: Bool = true) {
        guard let expected = session else { return }
        restartTask?.cancel()
        taskToken = UUID()
        bridge.replace(nil)
        request?.endAudio()
        // Don't cancel a task that already delivered its final result.
        if cancelCurrent && recognitionTask?.state != .completed { recognitionTask?.cancel() }
        recognitionTask = nil
        request = nil
        restartTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            catch { return }
            guard let self, self.session == expected, !Task.isCancelled else { return }
            self.restartTask = nil
            self.beginUtterance()
        }
    }

    private func emit(_ event: VoiceEvent) {
        guard let continuation else { return }
        if case .dropped = continuation.yield(event) { fail("Voice processing is overloaded. Tap the microphone to retry.") }
    }

    private func fail(_ message: String) {
        guard let token = session else { return }
        let current = continuation
        // Send failure before finish. SpellEngine fails closed even on overflow/finish.
        current?.yield(.unavailable(session: token, reason: message))
        stop()
        onStatus?(message, 0)
    }

    func stop() {
        session = nil; taskToken = UUID()
        restartTask?.cancel(); restartTask = nil
        timer?.invalidate(); timer = nil
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
        bridge.replace(nil)
        recognitionTask?.cancel(); recognitionTask = nil
        request?.endAudio(); request = nil
        stopCapture()
        continuation?.finish(); continuation = nil
        // GameSession releases shared playback only when leaving the game.
    }
}
