import SwiftUI
import AnvilDomain

// MARK: - Conflict Hunk

/// A single conflict region parsed from a file with conflict markers.
struct ConflictHunk: Identifiable {
    let id = UUID().uuidString
    let oursLines: [String]
    let baseLines: [String]
    let theirsLines: [String]
    var resolution: ConflictResolution = .pending
}

enum ConflictResolution: String {
    case pending, ours, theirs, both
}

// MARK: - MergeConflictView

struct MergeConflictView: View {
    let conflict: MergeConflict
    var onResolve: ((String) -> Void)?
    @State private var hunks: [ConflictHunk] = []
    @State private var resolvedContent: String = ""
    @State private var allResolved = false

    var body: some View {
        VStack(spacing: 0) {
            conflictHeader
            Divider()

            if hunks.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: AnvilSpacing.md) {
                        ForEach(Array(hunks.enumerated()), id: \.element.id) { index, hunk in
                            conflictHunkView(hunk, index: index)
                        }
                    }
                    .padding(AnvilSpacing.lg)
                }
            }

            if !hunks.isEmpty {
                Divider()
                conflictFooter
            }
        }
        .background(AnvilColor.backgroundPrimary)
        .onAppear { parseConflictHunks() }
    }

    // MARK: - Header

    private var conflictHeader: some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(AnvilColor.accentAmber)
                .accessibilityHidden(true)

            Text(conflict.filePath)
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            let resolved = hunks.filter { $0.resolution != .pending }.count
            Text("\(resolved)/\(hunks.count) resolved")
                .font(AnvilFont.label)
                .foregroundStyle(resolved == hunks.count ? AnvilColor.accentGreen : AnvilColor.textTertiary)

            AnvilBadge(text: "Conflict", color: AnvilColor.accentAmber)
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.sm)
        .background(AnvilColor.backgroundToolbar)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Merge conflict in \(conflict.filePath), \(hunks.filter { $0.resolution != .pending }.count) of \(hunks.count) hunks resolved")
    }

    // MARK: - Footer

    private var conflictFooter: some View {
        HStack(spacing: AnvilSpacing.md) {
            Button("Accept All Ours") {
                resolveAll(.ours)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Accept all ours")

            Button("Accept All Theirs") {
                resolveAll(.theirs)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Accept all theirs")

            Spacer()

            Text(allResolved ? "All hunks resolved" : "Resolve all hunks to continue")
                .font(AnvilFont.label)
                .foregroundStyle(allResolved ? AnvilColor.accentGreen : AnvilColor.textTertiary)

            if allResolved, onResolve != nil {
                Button("Mark as Resolved") {
                    let content = buildResolvedContent()
                    onResolve?(content)
                }
                .buttonStyle(.borderedProminent)
                .tint(AnvilColor.accentGreen)
                .accessibilityLabel("Mark file as resolved")
            }
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.sm)
        .background(.bar)
    }

    // MARK: - Hunk View

    private func conflictHunkView(_ hunk: ConflictHunk, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hunk label
            HStack {
                Text("Conflict \(index + 1)")
                    .font(AnvilFont.subheading)
                    .foregroundStyle(AnvilColor.textPrimary)

                Spacer()

                if hunk.resolution != .pending {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AnvilColor.accentGreen)
                        Text(hunk.resolution.rawValue.capitalized)
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.accentGreen)
                    }
                }
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.sm)
            .background(AnvilColor.backgroundToolbar)

            Divider()

            // Three-panel layout
            HStack(alignment: .top, spacing: 0) {
                // Ours panel
                conflictPanel(
                    title: "Ours (Current)",
                    lines: hunk.oursLines,
                    color: AnvilColor.accentBlue,
                    isSelected: hunk.resolution == .ours
                )

                Rectangle()
                    .fill(AnvilColor.borderSubtle)
                    .frame(width: 1)

                // Base panel
                if !hunk.baseLines.isEmpty {
                    conflictPanel(
                        title: "Base",
                        lines: hunk.baseLines,
                        color: AnvilColor.textTertiary,
                        isSelected: false
                    )

                    Rectangle()
                        .fill(AnvilColor.borderSubtle)
                        .frame(width: 1)
                }

                // Theirs panel
                conflictPanel(
                    title: "Theirs (Incoming)",
                    lines: hunk.theirsLines,
                    color: AnvilColor.accentPurple,
                    isSelected: hunk.resolution == .theirs
                )
            }

            Divider()

            // Action buttons
            HStack(spacing: AnvilSpacing.sm) {
                Button {
                    resolveHunk(index, resolution: .ours)
                } label: {
                    Label("Accept Ours", systemImage: "arrow.left.circle")
                }
                .buttonStyle(.bordered)
                .tint(AnvilColor.accentBlue)
                .accessibilityLabel("Accept ours for conflict \(index + 1)")

                Button {
                    resolveHunk(index, resolution: .theirs)
                } label: {
                    Label("Accept Theirs", systemImage: "arrow.right.circle")
                }
                .buttonStyle(.bordered)
                .tint(AnvilColor.accentPurple)
                .accessibilityLabel("Accept theirs for conflict \(index + 1)")

                Button {
                    resolveHunk(index, resolution: .both)
                } label: {
                    Label("Accept Both", systemImage: "arrow.left.arrow.right.circle")
                }
                .buttonStyle(.bordered)
                .tint(AnvilColor.accentGreen)
                .accessibilityLabel("Accept both for conflict \(index + 1)")

                Spacer()

                if hunk.resolution != .pending {
                    Button {
                        resolveHunk(index, resolution: .pending)
                    } label: {
                        Text("Reset")
                            .font(AnvilFont.label)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .accessibilityLabel("Reset conflict \(index + 1)")
                }
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.sm)
        }
        .background(AnvilColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius)
                .stroke(
                    hunk.resolution != .pending ? AnvilColor.accentGreen.opacity(0.4) : AnvilColor.borderSubtle,
                    lineWidth: 1
                )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Conflict \(index + 1), \(hunk.resolution == .pending ? "unresolved" : "resolved as \(hunk.resolution.rawValue)")")
    }

    // MARK: - Panel

    private func conflictPanel(title: String, lines: [String], color: Color, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Panel header
            HStack(spacing: AnvilSpacing.xxs) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(title)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textSecondary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AnvilColor.accentGreen)
                }
            }
            .padding(.horizontal, AnvilSpacing.sm)
            .padding(.vertical, AnvilSpacing.xs)
            .background(isSelected ? color.opacity(0.08) : Color.clear)

            Divider()

            // Lines
            VStack(alignment: .leading, spacing: 0) {
                if lines.isEmpty {
                    Text("(empty)")
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.textTertiary)
                        .italic()
                        .padding(AnvilSpacing.sm)
                } else {
                    ForEach(Array(lines.enumerated()), id: \.offset) { lineNum, line in
                        HStack(spacing: 0) {
                            Text("\(lineNum + 1)")
                                .font(AnvilFont.code)
                                .foregroundStyle(AnvilColor.textTertiary)
                                .frame(width: 32, alignment: .trailing)
                                .padding(.trailing, AnvilSpacing.xs)

                            Text(line)
                                .font(AnvilFont.code)
                                .foregroundStyle(AnvilColor.textPrimary)
                                .lineLimit(1)

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, AnvilSpacing.xxs)
                        .padding(.vertical, 1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(lines.count) lines")
    }

    // MARK: - Actions

    private func resolveHunk(_ index: Int, resolution: ConflictResolution) {
        withAnimation(AnvilAnimation.standard) {
            hunks[index].resolution = resolution
            allResolved = hunks.allSatisfy { $0.resolution != .pending }
        }
    }

    private func resolveAll(_ resolution: ConflictResolution) {
        withAnimation(AnvilAnimation.standard) {
            for i in hunks.indices {
                hunks[i].resolution = resolution
            }
            allResolved = true
        }
    }

    /// Builds the final file content from resolved hunks.
    private func buildResolvedContent() -> String {
        // Re-read the original file content and replace conflict regions with resolved content
        let originalLines = (conflict.oursContent.isEmpty && conflict.theirsContent.isEmpty)
            ? [] : conflict.oursContent.components(separatedBy: "\n") // Fallback

        // For the simple case (single hunk from pre-split content), just return the chosen side
        if hunks.count == 1 {
            let hunk = hunks[0]
            switch hunk.resolution {
            case .ours:
                return hunk.oursLines.joined(separator: "\n")
            case .theirs:
                return hunk.theirsLines.joined(separator: "\n")
            case .both:
                return (hunk.oursLines + hunk.theirsLines).joined(separator: "\n")
            case .pending:
                return originalLines.joined(separator: "\n")
            }
        }

        // Multiple hunks: concatenate each resolved hunk
        var result: [String] = []
        for hunk in hunks {
            switch hunk.resolution {
            case .ours:
                result.append(contentsOf: hunk.oursLines)
            case .theirs:
                result.append(contentsOf: hunk.theirsLines)
            case .both:
                result.append(contentsOf: hunk.oursLines)
                result.append(contentsOf: hunk.theirsLines)
            case .pending:
                result.append(contentsOf: hunk.oursLines)
            }
        }
        return result.joined(separator: "\n")
    }

    // MARK: - Parsing

    private func parseConflictHunks() {
        // If oursContent and theirsContent are pre-split, create a single hunk
        if !conflict.oursContent.isEmpty || !conflict.theirsContent.isEmpty {
            let oursLines = conflict.oursContent.components(separatedBy: "\n")
            let theirsLines = conflict.theirsContent.components(separatedBy: "\n")
            let baseLines = conflict.baseContent?.components(separatedBy: "\n") ?? []
            hunks = [ConflictHunk(oursLines: oursLines, baseLines: baseLines, theirsLines: theirsLines)]
            return
        }
        hunks = []
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AnvilSpacing.md) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 36, weight: .thin))
                .foregroundStyle(AnvilColor.accentGreen)
                .accessibilityHidden(true)
            Text("No conflict hunks found")
                .font(AnvilFont.body)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#if DEBUG
struct MergeConflictView_Previews: PreviewProvider {
    static var previews: some View {
        MergeConflictView(conflict: MergeConflict(
            filePath: "src/auth/handler.swift",
            oursContent: "func validate() {\n    guard token.isValid else { return }\n    // Our implementation\n    process(token)\n}",
            theirsContent: "func validate() {\n    guard token.isActive else { return }\n    // Their implementation\n    handle(token)\n}",
            baseContent: "func validate() {\n    // Original\n    process(token)\n}"
        ))
        .frame(width: 900, height: 600)
    }
}
#endif
