import SwiftUI

public struct InspectorPanel: View {
    @EnvironmentObject var appState: AppState

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Inspector")
                    .font(AnvilFont.sidebarHeader)
                    .foregroundStyle(AnvilColor.textPrimary)

                Spacer()

                Button {
                    appState.toggleInspector()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(AnvilSpacing.md)

            Divider()
                .overlay(AnvilColor.borderSubtle)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: AnvilSpacing.md) {
                    InspectorSection(title: "Details") {
                        Text("Select an item to inspect")
                            .font(AnvilFont.body)
                            .foregroundStyle(AnvilColor.textTertiary)
                    }
                }
                .padding(AnvilSpacing.md)
            }
        }
        .background(AnvilColor.backgroundSecondary)
    }
}

struct InspectorSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            Text(title.uppercased())
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textSecondary)
                .tracking(0.3)

            content
        }
    }
}
