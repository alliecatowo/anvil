import Foundation
import AnvilDomain

public enum ProjectSource: Sendable {
    case blank(name: String)
    case fromTemplate(name: String, templateUrl: String)
    case fromRepo(url: String)
    case fromDirectory(path: String)
}

public struct CreateProjectUseCase: Sendable {
    public init() {}

    public func execute(source: ProjectSource) async throws -> String {
        switch source {
        case .blank(let name):
            return name
        case .fromTemplate(let name, _):
            return name
        case .fromRepo(let url):
            return URL(string: url)?.lastPathComponent ?? "project"
        case .fromDirectory(let path):
            return URL(fileURLWithPath: path).lastPathComponent
        }
    }
}
