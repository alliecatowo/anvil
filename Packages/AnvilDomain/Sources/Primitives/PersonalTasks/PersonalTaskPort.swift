import Foundation

public protocol PersonalTaskPort: AnvilProviderDefinition {
    func tasks() async throws -> [PersonalTask]
    func task(taskId: String) async throws -> PersonalTask
    func createTask(title: String, dueDate: Date?, priority: PersonalTaskPriority) async throws -> PersonalTask
    func updateTask(taskId: String, title: String?, dueDate: Date?, priority: PersonalTaskPriority?) async throws -> PersonalTask
    func completeTask(taskId: String) async throws
    func deleteTask(taskId: String) async throws
    func dailyLog(date: Date) async throws -> DailyLog
    func saveDailyLog(date: Date, content: String) async throws -> DailyLog
}
