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
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    appState.toggleInspector()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close Inspector")
            }
            .padding(AnvilSpacing.md)

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: AnvilSpacing.md) {
                    InspectorSection(title: "Details") {
                        Text("Select an item to inspect")
                            .font(AnvilFont.body)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(AnvilSpacing.md)
            }
        }
        .background(.background)
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
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            content
        }
    }
}
