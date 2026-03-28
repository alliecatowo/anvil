import AnvilDomain
import Foundation

/// Opens a file in the editor surface of the Build space.
public struct OpenFileUseCase: Sendable {
    public init() {}

    /// Sets the pending file path and optional symbol line on AppState-equivalent state.
    /// The actual AppState mutation happens in the UI layer via published properties.
    public func execute(path: String, line: Int? = nil) -> (path: String, line: Int?) {
        return (path: path, line: line)
    }
}
