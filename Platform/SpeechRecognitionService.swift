import AVFoundation
import Speech
import Foundation

// Audio callback bridge. All mutable state is protected by the lock.
private final class SpeechAudioBridge: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var lastVoice: TimeInterval = 0
    private var firstVoice: TimeInterval = 0
    private var level: Float = 0

    func replace(_ request: SFSpeechAudioBufferRecognitionRequest?) {
        lock.lock(); defer { lock.unlock() }
        self.request = request; lastVoice = 0; firstVoice = 0; level = 0
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
        if rms > 0.012 {
            lastVoice = now
            if firstVoice == 0 { firstVoice = now }
        }
        request.append(buffer)
    }

    func sample() -> (first: TimeInterval, last: TimeInterval, level: Float) {
        lock.lock(); defer { lock.unlock() }
        return (firstVoice, lastVoice, level)
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
    private let audioEngine = AVAudioEngine()
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
        self.session = session; self.locale = locale; self.phrases = phrases; utterance = 0
        let (recognizer, _) = try OnDeviceSpeechRequest.make(locale: locale, phrases: phrases)
        self.recognizer = recognizer
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement,
                                     options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setPreferredIOBufferDuration(0.01)
        try audioSession.setActive(true)
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0 && format.sampleRate > 0 else { throw Failure.noMicrophone }
        let stream = AsyncStream<VoiceEvent>(bufferingPolicy: .bufferingNewest(32)) { self.continuation = $0 }
        let bridge = self.bridge
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in bridge.append(buffer) }
        tapInstalled = true
        audioEngine.prepare()
        try audioEngine.start()
        beginUtterance()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.inspectAudio() }
        }
        for name in [AVAudioSession.interruptionNotification, AVAudioSession.routeChangeNotification,
                     AVAudioSession.mediaServicesWereResetNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in Task { @MainActor in self?.fail("Audio changed. Tap the microphone to reconnect.") }
            })
        }
        return stream
    }

    private func beginUtterance() {
        guard session != nil, let recognizer else { return }
        taskToken = UUID(); let token = taskToken
        finalizing = false; endTimestamp = 0
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
            Task { @MainActor in self?.recognition(token: token, text: text, isFinal: isFinal, error: message) }
        }
        onStatus?("Listening · say Fireball", 0)
    }

    private func recognition(token: UUID, text: String?, isFinal: Bool, error: String?) {
        guard token == taskToken, let session else { return }
        if isFinal {
            let audio = bridge.sample()
            let capturedAt = endTimestamp > 0 ? endTimestamp : audio.last
            if let text, !text.isEmpty, capturedAt > 0 {
                utterance += 1
                emit(.final(session: session, utterance: utterance, text: text, capturedAt: capturedAt))
            }
            rotate()
        } else if let error {
            fail("Speech interrupted: \(error). Tap the microphone to retry.")
        } else if let text {
            emit(.partial(session: session, text: String(text.prefix(128))))
        }
    }

    private func inspectAudio() {
        guard session != nil else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let audio = bridge.sample()
        onStatus?(finalizing ? "Reading incantation…" : "Listening · say Fireball", min(1, audio.level * 15))
        if finalizing {
            if now - endTimestamp > 4 { fail("Recognition timed out. Tap the microphone to retry.") }
        } else if audio.first > 0 && ((now - audio.last > 0.42 && audio.last - audio.first > 0.08) || now - audio.first > 3) {
            finalizing = true
            endTimestamp = audio.last
            bridge.replace(nil) // No appends after endAudio.
            request?.endAudio()
        } else if now - taskStarted > 40 {
            rotate() // Silence/task lifetime bound; never replay audio across tasks.
        }
    }

    private func rotate() {
        guard session != nil else { return }
        taskToken = UUID()
        bridge.replace(nil)
        recognitionTask?.cancel(); recognitionTask = nil
        request = nil
        beginUtterance()
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
        timer?.invalidate(); timer = nil
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
        bridge.replace(nil)
        recognitionTask?.cancel(); recognitionTask = nil
        request?.endAudio(); request = nil
        if tapInstalled { audioEngine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        audioEngine.stop()
        continuation?.finish(); continuation = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
