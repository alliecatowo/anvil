import Foundation

public struct Transcription: Sendable, Identifiable, Codable {
    public let id: String
    public let sessionId: String
    public let text: String
    public let language: String?
    public let confidence: Double
    public let durationSeconds: Double
    public let segments: [TranscriptionSegment]
    public let createdAt: Date

    public init(id: String = UUID().uuidString, sessionId: String, text: String, language: String? = nil, confidence: Double = 0, durationSeconds: Double = 0, segments: [TranscriptionSegment] = [], createdAt: Date = .now) {
        self.id = id
        self.sessionId = sessionId
        self.text = text
        self.language = language
        self.confidence = confidence
        self.durationSeconds = durationSeconds
        self.segments = segments
        self.createdAt = createdAt
    }
}

public struct TranscriptionSegment: Sendable, Codable {
    public let text: String
    public let startTime: Double
    public let endTime: Double
    public let confidence: Double

    public init(text: String, startTime: Double, endTime: Double, confidence: Double = 0) {
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
    }
}
