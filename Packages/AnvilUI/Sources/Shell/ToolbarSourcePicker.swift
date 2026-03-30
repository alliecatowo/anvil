import SwiftUI

/// Toolbar center zone -- the Space Compositor.
///
/// Shows `Space . Navigator` where the navigator part is a dropdown Menu
/// that lets users switch the active sidebar navigator without leaving the toolbar.
struct ToolbarSourcePicker: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: AnvilSpacing.xs) {
            Text(appState.currentSpace.displayName)
                .font(.headline)

            navigatorDropdown
        }
        .padding(.horizontal, AnvilSpacing.md)
    }

    @ViewBuilder
    private var navigatorDropdown: some View {
        switch appState.currentSpace {
        case .plan:
            // Plan has no navigator -- show sprint context instead
            Text(appState.intentViewModel.currentCycle.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)

        case .build:
            navigatorMenu(
                sources: AppState.BuildSource.allCases,
                active: $appState.buildActiveSource
            )

        case .review:
            navigatorMenu(
                sources: AppState.ReviewSource.allCases,
                active: $appState.reviewActiveSource
            )

        case .operate:
            navigatorMenu(
                sources: AppState.OperateSource.allCases,
                active: $appState.operateActiveSource
            )

        case .library:
            navigatorMenu(
                sources: AppState.LibrarySource.allCases,
                active: $appState.libraryActiveSource
            )
        }
    }

    private func navigatorMenu<S: Hashable & CaseIterable & RawRepresentable>(
        sources: S.AllCases,
        active: Binding<S>
    ) -> some View where S: NavigatorSource, S.RawValue == String {
        Menu {
            ForEach(Array(sources.enumerated()), id: \.offset) { _, source in
                Button {
                    active.wrappedValue = source
                } label: {
                    Label(source.rawValue, systemImage: source.icon)
                }
            }
        } label: {
            HStack(spacing: AnvilSpacing.xxs) {
                Image(systemName: active.wrappedValue.icon)
                    .font(.system(size: 12, weight: .medium))
                Text(active.wrappedValue.rawValue)
                    .font(.system(size: 13, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
    }
}
