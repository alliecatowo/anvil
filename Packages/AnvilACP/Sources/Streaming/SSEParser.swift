import Foundation

public struct SSEEvent: Sendable {
    public let event: String?
    public let data: String
    public let id: String?

    public init(event: String? = nil, data: String, id: String? = nil) {
        self.event = event
        self.data = data
        self.id = id
    }
}

public struct SSEParser: Sendable {
    public init() {}

    public func parse(lines: AsyncLineSequence<URLSession.AsyncBytes>) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                var currentEvent: String?
                var currentData = ""
                var currentId: String?

                for try await line in lines {
                    if line.isEmpty {
                        if !currentData.isEmpty {
                            continuation.yield(SSEEvent(event: currentEvent, data: currentData, id: currentId))
                            currentEvent = nil
                            currentData = ""
                            currentId = nil
                        }
                        continue
                    }

                    if line.hasPrefix("event: ") {
                        currentEvent = String(line.dropFirst(7))
                    } else if line.hasPrefix("data: ") {
                        if !currentData.isEmpty { currentData += "\n" }
                        currentData += String(line.dropFirst(6))
                    } else if line.hasPrefix("id: ") {
                        currentId = String(line.dropFirst(4))
                    }
                }

                continuation.finish()
            }
        }
    }
}
