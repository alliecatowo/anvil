import SwiftUI
import AnvilDomain

struct NotificationPreferencesView: View {
    @ObservedObject var preferences: NotificationPreferences

    @State private var newRuleName = ""
    @State private var newRulePattern = ""
    @State private var newRuleAction: NotificationAction = .mute
    @State private var showingAddRule = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnvilSpacing.xxl) {
                // Header
                HStack {
                    Text("Notification Preferences")
                        .font(AnvilFont.heading)
                        .foregroundStyle(AnvilColor.textPrimary)
                    Spacer()
                }

                desktopSection
                urgencySection
                sourcesSection
                rulesSection
            }
            .padding(AnvilSpacing.xxl)
        }
        .background(AnvilColor.backgroundPrimary)
    }

    // MARK: - Desktop Notifications

    private var desktopSection: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            Text("Desktop Notifications")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)

            Toggle(isOn: $preferences.desktopNotificationsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show native macOS notifications")
                        .font(AnvilFont.body)
                        .foregroundStyle(AnvilColor.textPrimary)
                    Text("Banner notifications for new items that match your filters")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                }
            }
            .toggleStyle(.switch)
        }
    }

    // MARK: - Urgency Threshold

    private var urgencySection: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            Text("Minimum Urgency")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)

            Text("Only show notifications at or above this urgency level")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textSecondary)

            HStack(spacing: AnvilSpacing.sm) {
                ForEach(urgencyLevels, id: \.self) { urgency in
                    urgencyButton(urgency)
                }
            }
        }
    }

    private var urgencyLevels: [NotificationUrgency] {
        [.low, .normal, .high, .critical]
    }

    private func urgencyButton(_ urgency: NotificationUrgency) -> some View {
        let isSelected = preferences.minimumUrgency == urgency
        return Button {
            preferences.minimumUrgency = urgency
        } label: {
            Text(urgency.rawValue.capitalized)
                .font(AnvilFont.label)
                .foregroundStyle(isSelected ? AnvilColor.textPrimary : AnvilColor.textTertiary)
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.vertical, AnvilSpacing.xs)
                .background(isSelected ? urgencyColor(urgency).opacity(0.2) : AnvilColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? urgencyColor(urgency) : AnvilColor.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func urgencyColor(_ urgency: NotificationUrgency) -> Color {
        switch urgency {
        case .low:      AnvilColor.textTertiary
        case .normal:   AnvilColor.accentBlue
        case .high:     AnvilColor.accentAmber
        case .critical: AnvilColor.accentRed
        }
    }

    // MARK: - Source Toggles

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            Text("Notification Sources")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)

            sourceToggle(
                "Pull Requests",
                icon: "arrow.triangle.pull",
                color: AnvilColor.accentPurple,
                isOn: $preferences.prEnabled
            )
            sourceToggle(
                "Deploys",
                icon: "shippingbox",
                color: AnvilColor.accentGreen,
                isOn: $preferences.deployEnabled
            )
            sourceToggle(
                "Errors",
                icon: "exclamationmark.triangle.fill",
                color: AnvilColor.accentRed,
                isOn: $preferences.errorEnabled
            )
            sourceToggle(
                "Messages",
                icon: "message",
                color: AnvilColor.accentBlue,
                isOn: $preferences.messageEnabled
            )
            sourceToggle(
                "Mentions",
                icon: "at",
                color: AnvilColor.accentAmber,
                isOn: $preferences.mentionEnabled
            )
        }
    }

    private func sourceToggle(_ label: String, icon: String, color: Color, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: AnvilSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                    .frame(width: 20, height: 20)
                    .background(color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Text(label)
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textPrimary)
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, AnvilSpacing.xxs)
    }

    // MARK: - Custom Rules

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            HStack {
                Text("Filter Rules")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)

                Spacer()

                AnvilButton("Add Rule", icon: "plus", style: .ghost) {
                    showingAddRule.toggle()
                }
            }

            Text("Rules filter notifications by matching text in the title or body")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textSecondary)

            if showingAddRule {
                addRuleForm
            }

            if preferences.rules.isEmpty && !showingAddRule {
                Text("No custom rules configured")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .italic()
                    .padding(.vertical, AnvilSpacing.sm)
            } else {
                ForEach(preferences.rules) { rule in
                    ruleRow(rule)
                }
            }
        }
    }

    private var addRuleForm: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            TextField("Rule name", text: $newRuleName)
                .textFieldStyle(.roundedBorder)
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textPrimary)

            TextField("Match pattern (text to filter)", text: $newRulePattern)
                .textFieldStyle(.roundedBorder)
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textPrimary)

            HStack(spacing: AnvilSpacing.sm) {
                Picker("Action", selection: $newRuleAction) {
                    Text("Mute").tag(NotificationAction.mute)
                    Text("Notify").tag(NotificationAction.notify)
                    Text("Escalate").tag(NotificationAction.escalate)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)

                Spacer()

                AnvilButton("Cancel", style: .ghost) {
                    showingAddRule = false
                    newRuleName = ""
                    newRulePattern = ""
                }

                AnvilButton("Save", icon: "checkmark", style: .primary) {
                    guard !newRuleName.isEmpty, !newRulePattern.isEmpty else { return }
                    preferences.addRule(name: newRuleName, pattern: newRulePattern, action: newRuleAction)
                    newRuleName = ""
                    newRulePattern = ""
                    showingAddRule = false
                }
            }
        }
        .padding(AnvilSpacing.md)
        .background(AnvilColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func ruleRow(_ rule: NotificationRule) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            // Enable/disable toggle
            Button {
                preferences.toggleRule(id: rule.id)
            } label: {
                Image(systemName: rule.isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(rule.isEnabled ? AnvilColor.accentGreen : AnvilColor.textTertiary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name)
                    .font(AnvilFont.sidebarItem)
                    .foregroundStyle(rule.isEnabled ? AnvilColor.textPrimary : AnvilColor.textTertiary)

                HStack(spacing: AnvilSpacing.xs) {
                    Text(rule.pattern)
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.textSecondary)

                    AnvilBadge(
                        text: rule.action.rawValue.capitalized,
                        color: actionColor(rule.action)
                    )
                }
            }

            Spacer()

            Button {
                preferences.removeRule(id: rule.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(AnvilSpacing.sm)
        .background(AnvilColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func actionColor(_ action: NotificationAction) -> Color {
        switch action {
        case .mute:     AnvilColor.textTertiary
        case .notify:   AnvilColor.accentBlue
        case .escalate: AnvilColor.accentRed
        case .snooze:   AnvilColor.accentAmber
        }
    }
}
