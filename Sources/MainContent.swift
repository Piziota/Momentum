import SwiftUI

struct MainContent: View {
    @EnvironmentObject var store: AppStore

    private var items: [Item] { store.items(for: store.route) }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().overlay(Theme.stroke)
            content
        }
        .background(Theme.bg)
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 7) {
                    if case .project(let id) = store.route, let p = store.project(id) {
                        ProjectGlyph(project: p, size: 20)
                    }
                    Text(store.routeTitle)
                        .font(Theme.display(16, .bold))
                        .foregroundStyle(Theme.text)
                }
                Text(subtitle)
                    .font(Theme.ui(11))
                    .foregroundStyle(Theme.textDim)
            }

            Spacer()

            if !store.search.isEmpty {
                Pill(text: "\(items.count) match\(items.count == 1 ? "" : "es")",
                     icon: "magnifyingglass", tint: Theme.accent)
            }

            Menu {
                Picker("Sort by", selection: $store.sortKey) {
                    ForEach(SortKey.allCases) { Text($0.label).tag($0) }
                }
                Divider()
                Toggle("Show completed", isOn: $store.showDone)
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 11, weight: .semibold))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Sort and filter")

            if !isLearning {
                ModeSwitcher(mode: $store.mode)
            }

            PrimaryButton(title: "New task", icon: "plus", tint: store.routeTint) {
                store.quickAddOpen = true
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 38)
        .padding(.bottom, 13)
    }

    private var isLearning: Bool {
        if case .learning = store.route { return true }
        return false
    }

    private var subtitle: String {
        let open = items.filter { !$0.isDone }.count
        switch store.route {
        case .learning:
            let topics = store.learningTopics.count
            let links = store.totalLinks
            if topics == 0 { return "No topics yet" }
            let unread = store.unreadLinks
            return "\(topics) topic\(topics == 1 ? "" : "s") · \(links) link\(links == 1 ? "" : "s")"
                + (unread > 0 ? " · \(unread) to read" : "")
        case .today:
            if store.overdue.isEmpty && store.dueToday.isEmpty { return "Nothing due — you're clear" }
            var bits: [String] = []
            if !store.overdue.isEmpty { bits.append("\(store.overdue.count) overdue") }
            if !store.dueToday.isEmpty { bits.append("\(store.dueToday.count) due today") }
            return bits.joined(separator: " · ")
        case .project(let id):
            guard let p = store.project(id) else { return "" }
            let done = store.tasks.filter { $0.projectID == id && $0.isDone }.count
            let total = store.tasks.filter { $0.projectID == id }.count
            return "\(open) open · \(done)/\(total) done" + (p.fields.isEmpty ? "" : " · \(p.fields.count) custom fields")
        default:
            return "\(open) open task\(open == 1 ? "" : "s")"
        }
    }

    // MARK: Content by mode

    @ViewBuilder private var content: some View {
        // Learning is a shelf of topics and links, not another cut of the task
        // list, so it ignores the list/board/calendar/timeline modes.
        if case .learning = store.route {
            LearningView()
        } else {
            byMode
        }
    }

    @ViewBuilder private var byMode: some View {
        switch store.mode {
        case .list:
            if case .today = store.route, store.search.isEmpty {
                TodayView()
            } else {
                GroupedList(items: items)
            }
        case .board:
            BoardView(items: items)
        case .calendar:
            CalendarView(items: items)
        case .gantt:
            GanttView(items: items)
        }
    }
}

// MARK: - Grouped list for non-Today routes

struct GroupedList: View {
    @EnvironmentObject var store: AppStore
    var items: [Item]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if items.isEmpty {
                    EmptyState(icon: store.search.isEmpty ? "tray" : "magnifyingglass",
                               title: store.search.isEmpty ? "Nothing here yet" : "No matches",
                               message: store.search.isEmpty
                                 ? "Hit ⌘N, or use the New task button. Try typing “Send CV fri 5pm #jobs !high”."
                                 : "Try a shorter search, or turn on completed tasks in the sort menu.",
                               tint: store.routeTint)
                } else {
                    ForEach(buckets, id: \.0) { name, list in
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeader(title: name, count: list.count,
                                          icon: icon(for: name), tint: tint(for: name))
                            VStack(spacing: 6) {
                                ForEach(list) { item in
                                    TaskRow(item: item, showProject: showProject)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    private var showProject: Bool {
        if case .project = store.route { return false }
        return true
    }

    /// Group by due horizon — the thing that actually matters for not missing deadlines.
    private var buckets: [(String, [Item])] {
        var overdue: [Item] = [], today: [Item] = [], week: [Item] = []
        var later: [Item] = [], none: [Item] = [], done: [Item] = []

        for i in items {
            if i.isDone { done.append(i); continue }
            guard let off = i.dueDayOffset else { none.append(i); continue }
            if i.isOverdue { overdue.append(i) }
            else if off == 0 { today.append(i) }
            else if off <= 7 { week.append(i) }
            else { later.append(i) }
        }

        var out: [(String, [Item])] = []
        if !overdue.isEmpty { out.append(("Overdue", overdue)) }
        if !today.isEmpty { out.append(("Today", today)) }
        if !week.isEmpty { out.append(("Next 7 days", week)) }
        if !later.isEmpty { out.append(("Later", later)) }
        if !none.isEmpty { out.append(("No date", none)) }
        if !done.isEmpty { out.append(("Completed", done)) }
        return out
    }

    private func icon(for name: String) -> String {
        switch name {
        case "Overdue": return "exclamationmark.triangle.fill"
        case "Today": return "sun.max.fill"
        case "Next 7 days": return "calendar"
        case "Later": return "clock"
        case "No date": return "tray"
        default: return "checkmark.circle.fill"
        }
    }

    private func tint(for name: String) -> Color {
        switch name {
        case "Overdue": return Theme.red
        case "Today": return Theme.amber
        case "Next 7 days": return Theme.accent
        case "Later": return Theme.blue
        case "No date": return Theme.textFaint
        default: return Theme.green
        }
    }
}
