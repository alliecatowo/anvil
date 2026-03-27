import Foundation

/// A structured plan that an agent generates before executing work.
/// Steps can be reordered, annotated, and skipped by the user.
public struct AgentPlan: Sendable, Identifiable, Codable {
    public let id: String
    public var title: String
    public var steps: [PlanStep]
    public var status: PlanStatus
    public let createdAt: Date

    /// Overall progress (0.0 to 1.0).
    public var progress: Double {
        guard !steps.isEmpty else { return 0 }
        let completed = steps.filter { $0.status == .completed || $0.status == .skipped }.count
        return Double(completed) / Double(steps.count)
    }

    /// The currently active step, if any.
    public var activeStep: PlanStep? {
        steps.first { $0.status == .active }
    }

    public init(
        id: String = UUID().uuidString,
        title: String = "Plan",
        steps: [PlanStep] = [],
        status: PlanStatus = .draft,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.steps = steps
        self.status = status
        self.createdAt = createdAt
    }
}

public enum PlanStatus: String, Sendable, Codable {
    case draft       // Agent proposed, user hasn't approved
    case approved    // User approved, execution can begin
    case executing   // Actively being worked on
    case completed   // All steps done
    case cancelled   // User cancelled
}

public struct PlanStep: Sendable, Identifiable, Codable {
    public let id: String
    public var title: String
    public var description: String
    public var status: PlanStepStatus
    public var annotation: String?    // User's note on this step
    public var order: Int

    public init(
        id: String = UUID().uuidString,
        title: String,
        description: String = "",
        status: PlanStepStatus = .planned,
        annotation: String? = nil,
        order: Int = 0
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.status = status
        self.annotation = annotation
        self.order = order
    }
}

public enum PlanStepStatus: String, Sendable, Codable {
    case planned     // Not yet started
    case active      // Currently being executed
    case completed   // Done
    case skipped     // User chose to skip
    case failed      // Step failed during execution
}
