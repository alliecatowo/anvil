import SwiftUI
import AnvilDomain

/// Displays a structured agent plan with editable steps, status tracking, and user annotations.
struct AgentPlanView: View {
    let plan: AgentPlan
    let onApprove: () -> Void
    let onCancel: () -> Void
    let onSkipStep: (String) -> Void
    let onAnnotateStep: (String, String) -> Void
    let onReorderStep: (String, Int) -> Void
    let onAddStep: (String, String?) -> Void  // title, afterStepId
    let onRemoveStep: (String) -> Void

    @State private var isAddingStep = false
    @State private var newStepTitle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Plan header
            PlanHeader(plan: plan, onApprove: onApprove, onCancel: onCancel)

            Divider().overlay(AnvilColor.borderSubtle)

            // Progress bar
            if !plan.steps.isEmpty {
                ProgressView(value: plan.progress)
                    .tint(progressColor)
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.sm)
            }

            // Steps list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AnvilSpacing.xs) {
                    ForEach(plan.steps.sorted(by: { $0.order < $1.order })) { step in
                        PlanStepRow(
                            step: step,
                            onSkip: { onSkipStep(step.id) },
                            onAnnotate: { text in onAnnotateStep(step.id, text) },
                            onRemove: { onRemoveStep(step.id) }
                        )
                    }

                    // Add step button
                    if plan.status == .draft || plan.status == .approved {
                        if isAddingStep {
                            HStack(spacing: AnvilSpacing.sm) {
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(AnvilColor.textTertiary)
                                    .font(.system(size: 14))

                                TextField("New step...", text: $newStepTitle)
                                    .textFieldStyle(.plain)
                                    .font(AnvilFont.body)
                                    .foregroundStyle(AnvilColor.textPrimary)
                                    .onSubmit {
                                        if !newStepTitle.isEmpty {
                                            onAddStep(newStepTitle, nil)
                                            newStepTitle = ""
                                            isAddingStep = false
                                        }
                                    }

                                Button("Add") {
                                    if !newStepTitle.isEmpty {
                                        onAddStep(newStepTitle, nil)
                                        newStepTitle = ""
                                        isAddingStep = false
                                    }
                                }
                                .font(AnvilFont.label)
                                .foregroundStyle(AnvilColor.accentBlue)

                                Button("Cancel") {
                                    newStepTitle = ""
                                    isAddingStep = false
                                }
                                .font(AnvilFont.label)
                                .foregroundStyle(AnvilColor.textTertiary)
                            }
                            .padding(.horizontal, AnvilSpacing.md)
                            .padding(.vertical, AnvilSpacing.sm)
                        } else {
                            Button {
                                isAddingStep = true
                            } label: {
                                HStack(spacing: AnvilSpacing.sm) {
                                    Image(systemName: "plus.circle.dashed")
                                        .font(.system(size: 14))
                                    Text("Add step")
                                        .font(AnvilFont.label)
                                }
                                .foregroundStyle(AnvilColor.textTertiary)
                                .padding(.horizontal, AnvilSpacing.md)
                                .padding(.vertical, AnvilSpacing.sm)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, AnvilSpacing.sm)
            }
        }
        .background(AnvilColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AnvilColor.borderSubtle, lineWidth: 1)
        )
    }

    private var progressColor: Color {
        switch plan.status {
        case .completed: return AnvilColor.accentGreen
        case .cancelled: return AnvilColor.accentRed
        case .executing: return AnvilColor.accentBlue
        default: return AnvilColor.textTertiary
        }
    }
}

// MARK: - Plan Header

private struct PlanHeader: View {
    let plan: AgentPlan
    let onApprove: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 14))
                .foregroundStyle(AnvilColor.accentPurple)

            Text("Plan")
                .font(AnvilFont.sidebarHeader)
                .foregroundStyle(AnvilColor.textPrimary)

            AnvilBadge(text: plan.status.rawValue, color: statusColor)

            Text("\(completedCount)/\(plan.steps.count) steps")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)

            Spacer()

            if plan.status == .draft {
                Button {
                    onApprove()
                } label: {
                    HStack(spacing: AnvilSpacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("Approve")
                            .font(AnvilFont.label)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, AnvilSpacing.sm)
                    .padding(.vertical, AnvilSpacing.xxs)
                    .background(AnvilColor.accentGreen)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    onCancel()
                } label: {
                    Text("Cancel")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .buttonStyle(.plain)
            } else if plan.status == .approved || plan.status == .executing {
                Button {
                    onCancel()
                } label: {
                    HStack(spacing: AnvilSpacing.xs) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 12))
                        Text("Cancel")
                            .font(AnvilFont.label)
                    }
                    .foregroundStyle(AnvilColor.accentRed)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.sm)
    }

    private var completedCount: Int {
        plan.steps.filter { $0.status == .completed || $0.status == .skipped }.count
    }

    private var statusColor: Color {
        switch plan.status {
        case .draft: return AnvilColor.textTertiary
        case .approved: return AnvilColor.accentBlue
        case .executing: return AnvilColor.accentPurple
        case .completed: return AnvilColor.accentGreen
        case .cancelled: return AnvilColor.accentRed
        }
    }
}

// MARK: - Plan Step Row

private struct PlanStepRow: View {
    let step: PlanStep
    let onSkip: () -> Void
    let onAnnotate: (String) -> Void
    let onRemove: () -> Void

    @State private var isAnnotating = false
    @State private var annotationText = ""
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
            HStack(alignment: .top, spacing: AnvilSpacing.sm) {
                // Status icon
                stepIcon
                    .frame(width: 20, height: 20)

                // Step content
                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title)
                        .font(AnvilFont.body)
                        .foregroundStyle(titleColor)
                        .strikethrough(step.status == .skipped)

                    if !step.description.isEmpty {
                        Text(step.description)
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                    }
                }

                Spacer()

                // Actions (shown on hover)
                if isHovering && step.status == .planned {
                    HStack(spacing: AnvilSpacing.xs) {
                        Button {
                            isAnnotating.toggle()
                            annotationText = step.annotation ?? ""
                        } label: {
                            Image(systemName: "note.text")
                                .font(.system(size: 11))
                                .foregroundStyle(AnvilColor.textTertiary)
                        }
                        .buttonStyle(.plain)

                        Button(action: onSkip) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(AnvilColor.accentAmber)
                        }
                        .buttonStyle(.plain)

                        Button(action: onRemove) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(AnvilColor.accentRed)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Annotation
            if let annotation = step.annotation, !annotation.isEmpty, !isAnnotating {
                HStack(spacing: AnvilSpacing.xs) {
                    Image(systemName: "note.text")
                        .font(.system(size: 10))
                        .foregroundStyle(AnvilColor.accentBlue)
                    Text(annotation)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.accentBlue)
                }
                .padding(.leading, 28)
            }

            // Annotation editor
            if isAnnotating {
                HStack(spacing: AnvilSpacing.sm) {
                    TextField("Add a note...", text: $annotationText)
                        .textFieldStyle(.plain)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textPrimary)
                        .onSubmit {
                            onAnnotate(annotationText)
                            isAnnotating = false
                        }

                    Button("Save") {
                        onAnnotate(annotationText)
                        isAnnotating = false
                    }
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.accentBlue)

                    Button("Cancel") {
                        isAnnotating = false
                    }
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
                }
                .padding(.leading, 28)
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .background(step.status == .active ? AnvilColor.accentPurple.opacity(0.06) : .clear)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    @ViewBuilder
    private var stepIcon: some View {
        switch step.status {
        case .planned:
            Circle()
                .stroke(AnvilColor.textTertiary, lineWidth: 1.5)
                .frame(width: 16, height: 16)
        case .active:
            ZStack {
                Circle()
                    .fill(AnvilColor.accentPurple.opacity(0.2))
                    .frame(width: 16, height: 16)
                AnvilLoadingIndicator(size: 12)
            }
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(AnvilColor.accentGreen)
        case .skipped:
            Image(systemName: "forward.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(AnvilColor.accentAmber)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(AnvilColor.accentRed)
        }
    }

    private var titleColor: Color {
        switch step.status {
        case .completed, .skipped: return AnvilColor.textTertiary
        case .active: return AnvilColor.accentPurple
        case .failed: return AnvilColor.accentRed
        case .planned: return AnvilColor.textPrimary
        }
    }
}
