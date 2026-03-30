import SwiftUI
import AnvilDomain

struct IntentSidebar: View {
    @ObservedObject var viewModel: IntentViewModel
    @EnvironmentObject private var appState: AppState
    @State private var quickAddText = ""
    @State private var isQuickAdding = false
    @FocusState private var isQuickAddFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            AnvilSidebarHeaderRow(
                title: "Plan",
                icon: "checklist",
                count: viewModel.filteredTickets.count
            ) {
                Button {
                    withAnimation(AnvilAnimation.standard) {
                        isQuickAdding = true
                        isQuickAddFocused = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .accessibilityLabel("New Ticket")
                .accessibilityIdentifier("intent.sidebar.new-ticket")
            }

            AnvilSidebarSegmentedPicker(
                label: "Plan View Mode",
                items: IntentViewMode.allCases.map {
                    AnvilSidebarSegmentedPicker<IntentViewMode>.SidebarPickerItem(
                        id: $0,
                        title: $0.rawValue,
                        icon: nil
                    )
                },
                selection: $viewModel.viewMode
            )
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.bottom, AnvilSpacing.xs)
            .onChange(of: viewModel.viewMode) { _, _ in
                viewModel.closeTicketDetailInMainPane()
            }

            AnvilSidebarSearchBar(text: $viewModel.searchText, placeholder: "Search tickets...")
            Divider()

            List {
                if isQuickAdding {
                    quickAddField
                }

                // MARK: - Pinned Section

                if !viewModel.sidebarPins.isEmpty {
                    AnvilSidebarSection(title: "Pinned", icon: "pin.fill") {
                        ForEach(viewModel.pinnedFilters, id: \.rawValue) { filter in
                            pinnedFilterRow(filter)
                        }

                        ForEach(viewModel.pinnedTickets) { ticket in
                            pinnedTicketRow(ticket)
                        }
                    }
                }

                // MARK: - Sprint Section

                AnvilSidebarSection(title: "Sprint", icon: "arrow.triangle.2.circlepath") {
                    Button {
                        viewModel.viewMode = .board
                        viewModel.closeTicketDetailInMainPane()
                    } label: {
                        cycleHeader
                    }
                    .buttonStyle(.plain)
                }

                // MARK: - Saved Filters Section

                AnvilSidebarSection(title: "Saved Filters", icon: "line.3.horizontal.decrease.circle") {
                    savedFilterRow(
                        title: "My Tickets",
                        icon: "person.fill",
                        count: viewModel.myTickets.count,
                        filter: .myTickets
                    ) {
                        applySavedFilter {
                            viewModel.applyFilterMine()
                        }
                    }

                    savedFilterRow(
                        title: "Blocked",
                        icon: "exclamationmark.triangle",
                        count: viewModel.blockedTickets.count,
                        filter: .blocked
                    ) {
                        applySavedFilter {
                            viewModel.applyFilterBlocked()
                        }
                    }

                    savedFilterRow(
                        title: "Due Soon",
                        icon: "clock.badge.exclamationmark",
                        count: viewModel.dueSoonTickets.count,
                        filter: .dueSoon
                    ) {
                        applySavedFilter {
                            viewModel.applyFilterDueSoon()
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Quick Add Field

    private var quickAddField: some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: "plus.circle")
                .font(.system(size: 12))
                .foregroundStyle(AnvilColor.accentBlue)

            TextField("New ticket title...", text: $quickAddText)
                .textFieldStyle(.plain)
                .font(AnvilFont.sidebarItem)
                .padding(.horizontal, AnvilSpacing.sm)
                .padding(.vertical, AnvilSpacing.xs)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .focused($isQuickAddFocused)
                .accessibilityIdentifier("intent.sidebar.quick-add-title")
                .onSubmit {
                    if !quickAddText.isEmpty {
                        withAnimation(AnvilAnimation.standard) {
                            viewModel.createTicket(title: quickAddText)
                        }
                        quickAddText = ""
                    }
                }
                .onKeyPress(.escape) {
                    quickAddText = ""
                    isQuickAdding = false
                    return .handled
                }

            if !quickAddText.isEmpty {
                Button {
                    quickAddText = ""
                    isQuickAdding = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel Quick Add")
                .accessibilityIdentifier("intent.sidebar.quick-add-cancel")
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Cycle Header

    private var cycleHeader: some View {
        AnvilSidebarRowButton(
            title: viewModel.currentCycle.name,
            icon: "arrow.triangle.2.circlepath",
            subtitle: "Current sprint",
            isActive: viewModel.viewMode == .board
        ) {
            viewModel.viewMode = .board
            viewModel.closeTicketDetailInMainPane()
        } trailing: {
            if let v = viewModel.currentCycle.velocity {
                AnvilBadge(text: "\(v) pts", color: AnvilColor.accentBlue)
            }
        }
    }

    // MARK: - Pinned Rows

    private func pinnedFilterRow(_ filter: PlanSidebarFilter) -> some View {
        AnvilSidebarRowButton(
            title: filter.title,
            icon: filter.icon,
            isActive: viewModel.currentSavedFilter == filter
        ) {
            applySavedFilter {
                switch filter {
                case .myTickets: viewModel.applyFilterMine()
                case .blocked:   viewModel.applyFilterBlocked()
                case .dueSoon:   viewModel.applyFilterDueSoon()
                }
            }
        }
        .contextMenu {
            Button { viewModel.togglePin(filter: filter) } label: {
                Label("Unpin", systemImage: "pin.slash")
            }
        }
    }

    private func pinnedTicketRow(_ ticket: Ticket) -> some View {
        AnvilSidebarRowButton(
            title: ticket.title,
            icon: IntentViewModel.statusIcon(ticket.status),
            isActive: viewModel.selectedTicketId == ticket.id
        ) {
            viewModel.selectTicket(ticket.id, openInMainPane: true)
        }
        .contextMenu {
            Button { viewModel.togglePin(ticketId: ticket.id) } label: {
                Label("Unpin", systemImage: "pin.slash")
            }
        }
    }

    // MARK: - Saved Filter Row

    private func savedFilterRow(title: String, icon: String, count: Int, filter: PlanSidebarFilter, action: @escaping () -> Void) -> some View {
        AnvilSidebarRowButton(
            title: title,
            icon: icon,
            isActive: viewModel.currentSavedFilter == filter,
            action: action
        ) {
            HStack(spacing: AnvilSpacing.xs) {
                if count > 0 {
                    AnvilBadge(text: "\(count)", color: AnvilColor.accentBlue)
                }
                PinButton(
                    isPinned: viewModel.isPinned(filter: filter),
                    action: { viewModel.togglePin(filter: filter) }
                )
            }
        }
        .accessibilityLabel("\(title), \(count) tickets")
    }

    // MARK: - Helpers

    private func applySavedFilter(_ action: () -> Void) {
        viewModel.viewMode = .list
        action()
        viewModel.closeTicketDetailInMainPane()
    }
}

// MARK: - Pin Button

private struct PinButton: View {
    let isPinned: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: isPinned ? "pin.fill" : "pin")
                .font(.system(size: 11))
                .foregroundStyle(isPinned ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
        .opacity(isPinned || isHovered ? 1.0 : 0.0)
        .onHover { isHovered = $0 }
        .accessibilityLabel(isPinned ? "Unpin" : "Pin")
    }
}
