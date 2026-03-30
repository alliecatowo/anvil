import SwiftUI
import Combine

@MainActor
public class ChordTracker: ObservableObject {
    public struct Chord: Sendable {
        public let keys: [Character]
        public let action: String
        public let label: String

        public init(keys: [Character], action: String, label: String) {
            self.keys = keys
            self.action = action
            self.label = label
        }
    }

    @Published public var pendingKey: Character?
    @Published public var isChordActive: Bool = false

    private var chords: [Chord] = []
    private var resetTimer: Task<Void, Never>?

    public static let defaultChords: [Chord] = [
        Chord(keys: ["g", "t"], action: "goto.ticket", label: "Go to Ticket"),
        Chord(keys: ["g", "b"], action: "goto.branch", label: "Go to Branch"),
        Chord(keys: ["g", "p"], action: "goto.pr", label: "Go to PR"),
        Chord(keys: ["g", "d"], action: "goto.deployment", label: "Go to Deployment"),
        Chord(keys: ["g", "a"], action: "goto.agentSession", label: "Go to Build Session"),
        Chord(keys: ["g", "n"], action: "goto.projectNotes", label: "Go to Project Notes"),
        Chord(keys: ["g", "c"], action: "goto.ciRun", label: "Go to CI Run"),
        Chord(keys: ["g", "e"], action: "goto.error", label: "Go to Error"),
        Chord(keys: ["g", "s"], action: "goto.schedule", label: "Go to Schedule"),
    ]

    public init(chords: [Chord] = ChordTracker.defaultChords) {
        self.chords = chords
    }

    public func handleKeyPress(_ key: Character) -> String? {
        resetTimer?.cancel()

        if let pending = pendingKey {
            let matchedChord = chords.first { $0.keys == [pending, key] }
            pendingKey = nil
            isChordActive = false
            return matchedChord?.action
        }

        let startsChord = chords.contains { $0.keys.first == key }
        if startsChord {
            pendingKey = key
            isChordActive = true

            resetTimer = Task {
                try? await Task.sleep(for: .milliseconds(500))
                if !Task.isCancelled {
                    pendingKey = nil
                    isChordActive = false
                }
            }
            return nil
        }

        return nil
    }

    public func cancel() {
        resetTimer?.cancel()
        pendingKey = nil
        isChordActive = false
    }
}
