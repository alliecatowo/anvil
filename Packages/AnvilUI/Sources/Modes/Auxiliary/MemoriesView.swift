import SwiftUI
import AnvilApplication
import AnvilDomain

// MARK: - Memories ViewModel

@MainActor
final class MemoriesViewModel: ObservableObject {
    @Published var entries: [MemoryEntry] = []
    @Published var filterCategory: MemoryCategory?

    private let service = MemoryService()

    var filteredEntries: [MemoryEntry] {
        guard let filter = filterCategory else { return entries }
        return entries.filter { $0.category == filter }
    }

    func load() {
        Task {
            do {
                let loaded = try await service.loadEntries()
                self.entries = loaded
            } catch {
                self.entries = []
            }
        }
    }

    func deleteEntry(_ id: String) {
        Task {
            do {
                try await service.deleteEntry(id: id)
                self.entries.removeAll { $0.id == id }
            } catch {
                // Removal failed — keep entry in list
            }
        }
    }

    func scanSession(_ session: AgentSession) {
        Task {
            do {
                let newEntries = try await service.scanSession(session)
                self.entries.append(contentsOf: newEntries)
            } catch {
                // Scan failed — no memories added
            }
        }
    }
}

// MARK: - Memories Panel (for agent inspector)

struct MemoriesPanel: View {
    @ObservedObject var viewModel: MemoriesViewModel
    let sessionId: String?

    private var sessionEntries: [MemoryEntry] {
        guard let sessionId else { return viewModel.filteredEntries }
        return viewModel.filteredEntries.filter { $0.sessionId == sessionId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AnvilSpacing.xs) {
                    filterChip(label: "All", category: nil)
                    ForEach(MemoryCategory.allCases, id: \.rawValue) { category in
                        filterChip(label: category.displayName, category: category)
                    }
                }
            }

            if sessionEntries.isEmpty {
                Text("No memories for this session.")
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, AnvilSpacing.lg)
            } else {
                LazyVStack(alignment: .leading, spacing: AnvilSpacing.xs) {
                    ForEach(sessionEntries) { entry in
                        memoryRow(entry)
                    }
                }
            }
        }
        .onAppear {
            viewModel.load()
        }
    }

    private func filterChip(label: String, category: MemoryCategory?) -> some View {
        let isActive = viewModel.filterCategory == category
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.filterCategory = category
            }
        } label: {
            Text(label)
                .font(AnvilFont.label)
                .foregroundStyle(isActive ? AnvilColor.textPrimary : AnvilColor.textTertiary)
                .padding(.horizontal, AnvilSpacing.sm)
                .padding(.vertical, AnvilSpacing.xxs)
                .background(isActive ? AnvilColor.accentBlue.opacity(0.15) : AnvilColor.backgroundSecondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func memoryRow(_ entry: MemoryEntry) -> some View {
        HStack(alignment: .top, spacing: AnvilSpacing.sm) {
            Image(systemName: entry.category.icon)
                .font(.system(size: 12))
                .foregroundStyle(AnvilColor.accentBlue)
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.summary)
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .lineLimit(2)

                HStack(spacing: AnvilSpacing.xs) {
                    Text(entry.category.displayName)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)

                    Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                }

                if let detail = entry.detail {
                    Text(detail)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(AnvilColor.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                viewModel.deleteEntry(entry.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .buttonStyle(.borderless)
            .help("Remove memory")
            .accessibilityLabel("Delete memory: \(entry.summary)")
        }
        .padding(AnvilSpacing.xs)
        .background(AnvilColor.backgroundSecondary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - All Memories View (standalone, for Library)

struct AllMemoriesView: View {
    @StateObject private var viewModel = MemoriesViewModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Build Memories")
                    .font(AnvilFont.subheading)
                    .foregroundStyle(AnvilColor.textPrimary)
                Spacer()
                Text("\(viewModel.entries.count) entries")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.sm)
            .background(AnvilColor.backgroundToolbar)

            Divider()

            ScrollView {
                MemoriesPanel(viewModel: viewModel, sessionId: nil)
                    .padding(AnvilSpacing.md)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
