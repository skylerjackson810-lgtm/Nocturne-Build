import Foundation
import Speech

@MainActor
enum OnDeviceSpeechRequest {
    enum Failure: Error { case unauthorized, unsupportedLocale, unavailable, onDeviceUnavailable }

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
