import Foundation

public protocol VoicePort: AnvilProviderDefinition {
    func startSession(language: String?) async throws -> VoiceSession
    func endSession(sessionId: String) async throws -> Transcription
    func transcribe(audioData: Data, language: String?) async throws -> Transcription
    func sessions() async throws -> [VoiceSession]
    func transcription(sessionId: String) async throws -> Transcription
}
