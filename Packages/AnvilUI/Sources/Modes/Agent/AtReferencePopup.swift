import SwiftUI
import AnvilDomain

struct AtReference: Identifiable {
    let id: String
    let label: String
    let prefix: String
    let icon: String
    let description: String

    static let categories: [AtReference] = [
        AtReference(id: "file", label: "file", prefix: "@file:", icon: "doc.text", description: "Reference a file by path"),
        AtReference(id: "ticket", label: "ticket", prefix: "@ticket:", icon: "ticket", description: "Reference a Jira ticket"),
        AtReference(id: "branch", label: "branch", prefix: "@branch:", icon: "arrow.triangle.branch", description: "Reference a Git branch"),
    ]
}

struct AtReferencePopup: View {
    let filter: String
    let onSelect: (AtReference) -> Void

    private var filtered: [AtReference] {
        let query = filter.lowercased().trimmingCharacters(in: .init(charactersIn: "@"))
        if query.isEmpty { return AtReference.categories }
        return AtReference.categories.filter {
            $0.label.lowercased().contains(query) || $0.description.lowercased().contains(query)
        }
    }

    @State private var hoveredId: String?

    var body: some View {
        if !filtered.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(filtered) { ref in
                    Button {
                        onSelect(ref)
                    } label: {
                        HStack(spacing: AnvilSpacing.sm) {
                            Image(systemName: ref.icon)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AnvilColor.accentBlue)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(ref.prefix)
                                    .font(AnvilFont.code)
                                    .foregroundStyle(AnvilColor.textPrimary)

                                Text(ref.description)
                                    .font(AnvilFont.label)
                                    .foregroundStyle(AnvilColor.textTertiary)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, AnvilSpacing.md)
                        .padding(.vertical, AnvilSpacing.sm)
                        .background(hoveredId == ref.id ? AnvilColor.backgroundTertiary : .clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovered in
                        hoveredId = isHovered ? ref.id : nil
                    }
                }
            }
            .padding(.vertical, AnvilSpacing.xs)
            .background(AnvilColor.backgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius)
                    .stroke(AnvilColor.borderMedium, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 12, y: -4)
            .frame(maxWidth: 280)
        }
    }
}
