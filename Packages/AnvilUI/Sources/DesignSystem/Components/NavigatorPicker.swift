import SwiftUI

/// Protocol for Source enums to provide an icon for the navigator picker.
protocol NavigatorSource {
    var icon: String { get }
}

/// Xcode-style navigator picker at the top of the sidebar.
/// Shows the current navigator name with an icon and chevron.
/// Selecting a different navigator changes the sidebar content.
struct NavigatorPicker<Source: Hashable & CaseIterable & RawRepresentable>: View where Source.RawValue == String, Source: NavigatorSource {
    let sources: [Source]
    @Binding var active: Source
    var accentColor: Color = .accentColor

    var body: some View {
        Menu {
            ForEach(sources, id: \.self) { source in
                Button {
                    active = source
                } label: {
                    Label(source.rawValue, systemImage: source.icon)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: active.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(accentColor)
                Text(active.rawValue)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("Navigator: \(active.rawValue)")
    }
}

// MARK: - NavigatorSource Conformances

extension AppState.BuildSource: NavigatorSource {}
extension AppState.LibrarySource: NavigatorSource {}
extension AppState.OperateSource: NavigatorSource {}
extension AppState.ReviewSource: NavigatorSource {}
