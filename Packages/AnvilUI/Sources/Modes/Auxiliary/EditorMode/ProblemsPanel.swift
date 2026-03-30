import SwiftUI
import AnvilEditor

/// Problems panel showing all LSP diagnostics project-wide.
/// Click a row to navigate to the diagnostic's location in the editor.
struct ProblemsPanel: View {
    @ObservedObject var viewModel: EditorViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Problems", systemImage: "exclamationmark.triangle")
                    .font(AnvilFont.sidebarHeader)
                    .foregroundStyle(.primary)

                Spacer()

                diagnosticSummary

                Button {
                    viewModel.isProblemsVisible = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close Problems panel")
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.sm)

            Divider()

            // Content
            if viewModel.lspViewModel.diagnostics.isEmpty {
                VStack(spacing: AnvilSpacing.sm) {
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 28, weight: .thin))
                        .foregroundStyle(AnvilColor.accentGreen)
                        .accessibilityHidden(true)
                    Text("No problems detected")
                        .font(AnvilFont.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.diagnosticsByFile, id: \.uri) { group in
                        Section {
                            ForEach(group.items) { diagnostic in
                                diagnosticRow(diagnostic)
                            }
                        } header: {
                            fileHeader(uri: group.uri, count: group.items.count)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .background(.bar)
    }

    // MARK: - Summary

    private var diagnosticSummary: some View {
        let all = viewModel.lspViewModel.diagnostics
        let errors = all.filter { $0.severity == .error }.count
        let warnings = all.filter { $0.severity == .warning }.count

        return HStack(spacing: AnvilSpacing.sm) {
            if errors > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(AnvilColor.accentRed)
                    Text("\(errors)")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.accentRed)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(errors) errors")
            }

            if warnings > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(AnvilColor.accentAmber)
                    Text("\(warnings)")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.accentAmber)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(warnings) warnings")
            }
        }
    }

    // MARK: - File Header

    private func fileHeader(uri: String, count: Int) -> some View {
        let filename = uri.components(separatedBy: "/").last ?? uri

        return HStack(spacing: AnvilSpacing.xs) {
            Image(systemName: "doc.text")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(filename)
                .font(AnvilFont.label)
                .foregroundStyle(.primary)

            Text("\(count)")
                .font(AnvilFont.label)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(.regularMaterial)
                .clipShape(Capsule())

            Spacer()
        }
        .textCase(nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(filename), \(count) diagnostics")
    }

    // MARK: - Diagnostic Row

    private func diagnosticRow(_ diagnostic: LSPDiagnostic) -> some View {
        Button {
            viewModel.navigateToDiagnostic(diagnostic)
        } label: {
            HStack(spacing: AnvilSpacing.sm) {
                // Severity icon
                Image(systemName: severityIcon(diagnostic.severity))
                    .font(.system(size: 12))
                    .foregroundStyle(severityColor(diagnostic.severity))
                    .frame(width: 16)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(diagnostic.message)
                        .font(AnvilFont.body)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    HStack(spacing: AnvilSpacing.xs) {
                        Text("Ln \(diagnostic.line + 1), Col \(diagnostic.character + 1)")
                            .font(AnvilFont.label)
                            .foregroundStyle(.tertiary)

                        if let source = diagnostic.source {
                            Text(source)
                                .font(AnvilFont.label)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(severityLabel(diagnostic.severity)): \(diagnostic.message), line \(diagnostic.line + 1)")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Severity Helpers

    private func severityIcon(_ severity: LSPDiagnostic.DiagnosticSeverity) -> String {
        switch severity {
        case .error:       "xmark.circle.fill"
        case .warning:     "exclamationmark.triangle.fill"
        case .information: "info.circle.fill"
        case .hint:        "lightbulb.fill"
        }
    }

    private func severityColor(_ severity: LSPDiagnostic.DiagnosticSeverity) -> Color {
        switch severity {
        case .error:       AnvilColor.accentRed
        case .warning:     AnvilColor.accentAmber
        case .information: AnvilColor.accentBlue
        case .hint:        AnvilColor.textTertiary
        }
    }

    private func severityLabel(_ severity: LSPDiagnostic.DiagnosticSeverity) -> String {
        switch severity {
        case .error:       "Error"
        case .warning:     "Warning"
        case .information: "Information"
        case .hint:        "Hint"
        }
    }
}
