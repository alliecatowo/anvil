import Foundation

public protocol AgentMarketplacePort: AnvilProviderDefinition {
    func availableSkills() async throws -> [Skill]
    func skill(skillId: String) async throws -> Skill
    func installSkill(skillId: String) async throws
    func uninstallSkill(skillId: String) async throws
    func installedSkills() async throws -> [Skill]
    func checkCompatibility(skillId: String) async throws -> SkillCompatibility
    func searchSkills(query: String) async throws -> [Skill]
}
