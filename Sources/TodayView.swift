import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero
                stats
                sections
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Hero

    private var hero: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(DateFmt.greeting())
                    .font(Theme.display(27, .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [Theme.text, Theme.text.opacity(0.72)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                Text(DateFmt.fullDay.string(from: Date()))
                    .font(Theme.ui(13))
                    .foregroundStyle(Theme.textDim)
                focusLine.padding(.top, 5)
            }
            Spacer()
            ProgressRing(value: store.todayProgress,
                         tint: store.overdue.isEmpty ? Theme.green : Theme.amber,
                         size: 66, lineWidth: 7,
                         label: "\(Int(store.todayProgress * 100))%")
                .padding(.top, 4)
        }
        .padding(.top, 4)
    }

    private var focusLine: some View {
        HStack(spacing: 7) {
            if !store.overdue.isEmpty {
                Pill(text: "\(store.overdue.count) overdue", icon: "exclamationmark.circle.fill", tint: Theme.red)
            }
            if !store.dueToday.isEmpty {
                Pill(text: "\(store.dueToday.count) due today", icon: "sun.max.fill", tint: Theme.amber)
            }
            if store.overdue.isEmpty && store.dueToday.isEmpty {
                Pill(text: "Nothing due today", icon: "checkmark.seal.fill", tint: Theme.green)
            }
            if store.todayDone > 0 {
                Pill(text: "\(store.todayDone) done", icon: "checkmark", tint: Theme.green)
            }
        }
    }

    // MARK: Stats

    private var stats: some View {
        HStack(spacing: 10) {
            StatTile(value: "\(store.dueToday.count)", label: "Due today",
                     icon: "sun.max.fill", tint: Theme.amber)
            StatTile(value: "\(store.overdue.count)", label: "Overdue",
                     icon: "exclamationmark.triangle.fill", tint: Theme.red)
            StatTile(value: "\(store.inProgress.count)", label: "In progress",
                     icon: "bolt.fill", tint: Theme.blue)

            // Two weeks of completions.
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(store.recentActivity.reduce(0, +))")
                        .font(Theme.display(17, .bold)).foregroundStyle(Theme.text)
                    Text("Done · 14 days")
                        .font(Theme.ui(10.5, .medium)).foregroundStyle(Theme.textDim)
                }
                Sparkline(values: store.recentActivity, tint: Theme.green)
                    .frame(width: 70, height: 26)
            }
            .padding(.horizontal, 11).padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    // MARK: Sections

    private var sections: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !store.overdue.isEmpty {
                bucket("Overdue", icon: "exclamationmark.triangle.fill",
                       tint: Theme.red, items: store.overdue)
            }

            bucket("Today", icon: "sun.max.fill", tint: Theme.amber, items: store.dueToday,
                   emptyIcon: "checkmark.seal.fill",
                   emptyTitle: "Today is clear",
                   emptyMessage: "Nothing is due. Pull something forward from Next 7 days, or enjoy it.")

            if !store.liveCheckpoints.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Checkpoints due", count: store.liveCheckpoints.count,
                                  icon: "arrow.turn.down.right", tint: Theme.violet)
                    VStack(spacing: 6) {
                        ForEach(Array(store.liveCheckpoints.enumerated()), id: \.offset) { pair in
                            CheckpointRow(item: pair.element.0, checkpoint: pair.element.1)
                        }
                    }
                }
            }

            let active = store.inProgress.filter { $0.dueDayOffset == nil || ($0.dueDayOffset ?? 99) > 0 }
            if !active.isEmpty {
                bucket("In progress", icon: "bolt.fill", tint: Theme.blue, items: active)
            }

            // Don't repeat anything already listed above.
            let activeIDs = Set(active.map { $0.id })
            let soon = store.dueSoon.filter { !activeIDs.contains($0.id) }
            if !soon.isEmpty {
                bucket("Next 7 days", icon: "calendar", tint: Theme.accent, items: soon)
            }

            let someday = store.noDate.filter { $0.status != .active }
            if !someday.isEmpty {
                bucket("No date", icon: "tray", tint: Theme.textFaint, items: someday)
            }

            if store.showDone && !store.completedToday.isEmpty {
                bucket("Completed today", icon: "checkmark.circle.fill",
                       tint: Theme.green, items: store.completedToday)
            }
        }
    }

    @ViewBuilder
    private func bucket(_ title: String, icon: String, tint: Color, items: [Item],
                        emptyIcon: String? = nil, emptyTitle: String? = nil,
                        emptyMessage: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: title, count: items.count, icon: icon, tint: tint)
            if items.isEmpty {
                if let emptyIcon, let emptyTitle, let emptyMessage {
                    EmptyState(icon: emptyIcon, title: emptyTitle, message: emptyMessage, tint: tint)
                }
            } else {
                VStack(spacing: 6) {
                    ForEach(items) { TaskRow(item: $0) }
                }
            }
        }
    }
}

// MARK: - A standalone checkpoint row (for checkpoints due today)

struct CheckpointRow: View {
    @EnvironmentObject var store: AppStore
    var item: Item
    var checkpoint: Checkpoint
    @State private var hover = false

    var body: some View {
        HStack(spacing: 10) {
            MiniCheck(done: checkpoint.done, tint: Theme.violet) {
                store.toggleCheckpoint(item.id, checkpoint.id)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(checkpoint.title).font(Theme.ui(12.5, .medium)).foregroundStyle(Theme.text)
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.left")
                        .font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.textFaint)
                    Text(item.title).font(Theme.ui(11)).foregroundStyle(Theme.textDim).lineLimit(1)
                }
            }
            Spacer()
            if let d = checkpoint.due { DuePill(date: d, compact: true) }
        }
        .padding(.horizontal, 11).padding(.vertical, 9)
        .card(hovering: hover)
        .onHoverSpring { hover = $0 }
        .onTapGesture { store.selectedTaskID = item.id }
    }
}
