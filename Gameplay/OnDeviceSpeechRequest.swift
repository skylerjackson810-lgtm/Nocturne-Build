import Foundation
import Speech

@MainActor
enum OnDeviceSpeechRequest {
    enum Failure: LocalizedError {
        case unauthorized, unsupportedLocale, unavailable, onDeviceUnavailable
        var errorDescription: String? {
            switch self {
            case .unauthorized: return "Allow Speech Recognition in iPhone Settings to cast spells."
            case .unsupportedLocale: return "English (US) speech recognition is not supported on this device."
            case .unavailable: return "Apple's speech recognizer is unavailable. Try again shortly."
            case .onDeviceUnavailable: return "English (US) on-device recognition is unavailable. This build cannot use cloud recognition."
            }
        }
    }

    // Audio lifecycle belongs to SpeechRecognitionService, not SpellEngine.
    static func make(locale: String, phrases: [String]) throws
        -> (SFSpeechRecognizer, SFSpeechAudioBufferRecognitionRequest) {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw Failure.unauthorized
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)) else {
            throw Failure.unsupportedLocale
        }
        guard recognizer.supportsOnDeviceRecognition else {
            throw Failure.onDeviceUnavailable
        }
        guard recognizer.isAvailable else { throw Failure.unavailable }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.taskHint = .confirmation
        request.contextualStrings = phrases
        return (recognizer, request)
    }
}
