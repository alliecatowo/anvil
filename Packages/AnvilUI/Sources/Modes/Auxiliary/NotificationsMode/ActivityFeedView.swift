import SwiftUI

struct ActivityFeedView: View {
    @ObservedObject var viewModel: NotificationsViewModel

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Activity")
                    .font(AnvilFont.subheading)
                    .foregroundStyle(AnvilColor.textPrimary)

                Spacer()

                Text("Today")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .padding(.horizontal, AnvilSpacing.lg)
            .padding(.vertical, AnvilSpacing.sm)

            Divider()

            // Event stream
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.activityEvents) { event in
                        activityRow(event)
                    }
                }
            }
        }
    }

    // MARK: - Activity Row

    private func activityRow(_ event: ActivityEvent) -> some View {
        HStack(alignment: .top, spacing: AnvilSpacing.md) {
            // Timeline
            VStack(spacing: 0) {
                Image(systemName: event.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(event.iconColor)
                    .frame(width: 28, height: 28)
                    .background(event.iconColor.opacity(0.15))
                    .clipShape(Circle())
                    .accessibilityHidden(true)

                Rectangle()
                    .fill(AnvilColor.borderSubtle)
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
                    .accessibilityHidden(true)
            }
            .frame(width: 28)

            // Content
            VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                Text(event.description)
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(timeFormatter.string(from: event.timestamp))
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .padding(.bottom, AnvilSpacing.lg)

            Spacer()
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.top, AnvilSpacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.description), \(timeFormatter.string(from: event.timestamp))")
    }
}
