import Foundation
import AnvilDomain

public enum ACPTaskType: String, Sendable {
    case codeGeneration
    case codeReview
    case commitMessage
    case ticketGeneration
    case summarization
    case docGeneration
    case errorAnalysis
    case general
}

public actor ACPRouter {
    public struct RouteConfig: Sendable {
        public let taskType: ACPTaskType
        public let primaryProvider: String
        public let primaryModel: String
        public let fallbackProvider: String?
        public let fallbackModel: String?

        public init(taskType: ACPTaskType, primaryProvider: String, primaryModel: String, fallbackProvider: String? = nil, fallbackModel: String? = nil) {
            self.taskType = taskType
            self.primaryProvider = primaryProvider
            self.primaryModel = primaryModel
            self.fallbackProvider = fallbackProvider
            self.fallbackModel = fallbackModel
        }
    }

    private var routes: [ACPTaskType: RouteConfig] = [:]
    private var providers: [String: any ACPPort] = [:]

    public init() {}

    public func registerProvider(_ provider: any ACPPort) {
        providers[provider.providerId] = provider
    }

    public func setRoute(_ config: RouteConfig) {
        routes[config.taskType] = config
    }

    public func provider(for taskType: ACPTaskType) -> (any ACPPort)? {
        guard let route = routes[taskType] else { return providers.values.first }
        return providers[route.primaryProvider] ?? providers.values.first
    }

    public func route(for taskType: ACPTaskType) -> RouteConfig? {
        routes[taskType]
    }
}
