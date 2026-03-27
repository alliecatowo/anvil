import Foundation

extension PluginMetadata: CustomStringConvertible {
    public var description: String {
        "\(name) v\(version) (\(id))"
    }
}
