import SwiftUI
import AnvilDomain

// MARK: - CodebaseQAView

/// Global overlay (⌘/) for asking questions about the current project.
/// Reads the file tree, sends context to ACP, streams a grounded answer
/// with clickable file citations.
struct CodebaseQAView: View {
    @EnvironmentObject var container: DependencyContainer
    @EnvironmentObject var appState: AppState

    @State private var query: String = ""
    @State private var answer: String = ""
    @State private var citations: [CitedFile] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var history: [QAEntry] = []

    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack {
            // Backdrop — clear so sidebar remains clickable
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture { appState.toggleCodebaseQA() }

            // Panel
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(AnvilColor.accentPurple)
                        .accessibilityHidden(true)
                    Text("Ask about this codebase")
                        .font(AnvilFont.heading)
                        .foregroundStyle(AnvilColor.textPrimary)
                    Spacer()
                    Text("⌘/")
                        .font(AnvilFont.code)
                        .foregroundStyle(.tertiary)
                    Button { appState.toggleCodebaseQA() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AnvilColor.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close codebase QA")
                }
                .padding(.horizontal, AnvilSpacing.lg)
                .padding(.top, AnvilSpacing.lg)
                .padding(.bottom, AnvilSpacing.md)

                Divider()

                // Query input
                HStack(spacing: AnvilSpacing.sm) {
                    TextField("Ask anything about the codebase...", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .font(AnvilFont.body)
                        .foregroundStyle(.primary)
                        .focused($inputFocused)
                        .onSubmit { submitQuery() }

                    if isLoading {
                        AnvilLoadingIndicator(size: 16)
                    } else {
                        Button {
                            submitQuery()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(query.isEmpty ? AnvilColor.textTertiary : AnvilColor.accentPurple)
                        }
                        .buttonStyle(.plain)
                        .disabled(query.isEmpty)
                        .accessibilityLabel("Submit question")
                    }
                }
                .padding(.horizontal, AnvilSpacing.lg)
                .padding(.vertical, AnvilSpacing.md)

                Divider()

                // Response area
                if history.isEmpty && answer.isEmpty && errorMessage == nil {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: AnvilSpacing.lg) {
                            // Previous Q&A entries
                            ForEach(history) { entry in
                                QAEntryView(entry: entry)
                            }

                            // Current answer in progress
                            if !answer.isEmpty || isLoading {
                                currentAnswerView
                            }

                            // Error
                            if let err = errorMessage {
                                HStack(spacing: AnvilSpacing.sm) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 11))
                                        .foregroundStyle(AnvilColor.accentAmber)
                                    Text(err)
                                        .font(AnvilFont.label)
                                        .foregroundStyle(AnvilColor.textSecondary)
                                }
                                .padding(AnvilSpacing.md)
                                .background(AnvilColor.accentAmber.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        .padding(AnvilSpacing.lg)
                    }
                }
            }
            .frame(width: 700, height: 540)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 20)
        }
        .onAppear { inputFocused = true }
    }

    // MARK: - Sub-views

    private var emptyStateView: some View {
        VStack(spacing: AnvilSpacing.md) {
            Image(systemName: "questionmark.bubble")
                .font(.system(size: 36))
                .foregroundStyle(AnvilColor.textTertiary)

            VStack(spacing: AnvilSpacing.xs) {
                Text("Ask anything about your code")
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textPrimary)
                Text("Reads the project file tree for context")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            // Suggested questions
            VStack(spacing: AnvilSpacing.xs) {
                ForEach(suggestedQuestions, id: \.self) { q in
                    Button {
                        query = q
                        submitQuery()
                    } label: {
                        Text(q)
                            .font(AnvilFont.label)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AnvilSpacing.xl)
    }

    private var currentAnswerView: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.md) {
            // Current question
            if !query.isEmpty {
                HStack(spacing: AnvilSpacing.sm) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AnvilColor.textTertiary)
                    Text(query)
                        .font(AnvilFont.body)
                        .foregroundStyle(AnvilColor.textSecondary)
                }
            }

            // Answer
            if !answer.isEmpty {
                Text(answer)
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .textSelection(.enabled)

                // Citations
                if !citations.isEmpty {
                    citationsView(citations)
                }
            } else if isLoading {
                HStack(spacing: AnvilSpacing.sm) {
                    AnvilLoadingIndicator(size: 14)
                    Text("Searching codebase...")
                        .font(AnvilFont.body)
                        .foregroundStyle(AnvilColor.textTertiary)
                }
            }
        }
        .padding(AnvilSpacing.md)
    }

    private func citationsView(_ files: [CitedFile]) -> some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.xs) {
            Text("Files referenced:")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)

            QACitationFlowLayout(spacing: AnvilSpacing.xs) {
                ForEach(files) { file in
                    Button {
                        openFile(file.path)
                    } label: {
                        Label(file.displayName, systemImage: "doc.text")
                            .font(AnvilFont.code)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    // MARK: - Logic

    private func submitQuery() {
        guard !query.isEmpty, !isLoading else { return }

        let currentQuery = query
        query = ""
        answer = ""
        citations = []
        errorMessage = nil
        isLoading = true

        Task {
            await runQuery(currentQuery)
        }
    }

    private func runQuery(_ q: String) async {
        guard let projectPath = container.currentProjectPath else {
            isLoading = false
            errorMessage = "No project open. Open a project to ask questions about it."
            return
        }

        // Build file tree context
        let tree = container.fileSystemService.readTree(at: projectPath, maxDepth: 3)
        let treeText = buildTreeText(tree)

        // Build prompt
        let prompt = """
        You are a helpful assistant answering questions about a software project.

        Here is the project file structure:

        \(treeText)

        The user asks:
        \(q)

        Answer clearly and concisely. If you reference specific files, mention their paths.
        At the end of your answer, list any files you referenced on separate lines starting with "FILE: ".
        """

        let client = await container.getOrCreateACPClient()

        do {
            let response = try await client.complete(prompt: prompt)
            let parsed = parseResponse(response)
            answer = parsed.answer
            citations = parsed.files
            isLoading = false

            // Archive to history
            let entry = QAEntry(
                id: UUID().uuidString,
                question: q,
                answer: parsed.answer,
                citations: parsed.files
            )
            history.append(entry)
            answer = ""
            citations = []

        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    private func buildTreeText(_ nodes: [FileSystemService.FileNode], indent: String = "") -> String {
        var lines: [String] = []
        for node in nodes.prefix(50) {
            lines.append("\(indent)\(node.isDirectory ? "📁" : "📄") \(node.name)")
            if let children = node.children {
                lines.append(buildTreeText(children, indent: indent + "  "))
            }
        }
        return lines.joined(separator: "\n")
    }

    private func parseResponse(_ text: String) -> (answer: String, files: [CitedFile]) {
        var answerLines: [String] = []
        var filePaths: [String] = []

        for line in text.components(separatedBy: "\n") {
            if line.hasPrefix("FILE: ") {
                let path = String(line.dropFirst("FILE: ".count)).trimmingCharacters(in: .whitespaces)
                filePaths.append(path)
            } else {
                answerLines.append(line)
            }
        }

        let answer = answerLines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let files = filePaths.map { path in
            CitedFile(
                path: path,
                displayName: URL(fileURLWithPath: path).lastPathComponent
            )
        }

        return (answer, files)
    }

    private func openFile(_ path: String) {
        let fullPath: String
        if path.hasPrefix("/") {
            fullPath = path
        } else if let base = container.currentProjectPath {
            fullPath = (base as NSString).appendingPathComponent(path)
        } else {
            return
        }
        appState.toggleCodebaseQA()
        appState.pendingFileToOpen = fullPath
        appState.switchSpace(.build)
    }

    private var suggestedQuestions: [String] {
        [
            "What is the overall architecture of this project?",
            "Where are the main entry points?",
            "How is data persistence handled?",
            "What testing approach does this project use?",
        ]
    }
}

// MARK: - Supporting Types

struct CitedFile: Identifiable {
    let id: String = UUID().uuidString
    let path: String
    let displayName: String
}

struct QAEntry: Identifiable {
    let id: String
    let question: String
    let answer: String
    let citations: [CitedFile]
}

// MARK: - QAEntryView

private struct QAEntryView: View {
    let entry: QAEntry

    var body: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            // Question
            HStack(spacing: AnvilSpacing.sm) {
                Image(systemName: "person.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(AnvilColor.textTertiary)
                Text(entry.question)
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textSecondary)
                    .fontWeight(.medium)
            }

            // Answer
            Text(entry.answer)
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textPrimary)
                .textSelection(.enabled)

            // Citations (display only in history -- no open action)
            if !entry.citations.isEmpty {
                HStack(spacing: AnvilSpacing.xs) {
                    Text("References:")
                        .font(AnvilFont.label)
                        .foregroundStyle(.tertiary)
                    ForEach(entry.citations) { file in
                        Text(file.displayName)
                            .font(AnvilFont.code)
                            .foregroundStyle(AnvilColor.accentBlue)
                    }
                }
            }
        }
        .padding(AnvilSpacing.md)
    }
}

// MARK: - QACitationFlowLayout

/// Simple left-to-right wrapping layout for citation chips.
private struct QACitationFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 600
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
