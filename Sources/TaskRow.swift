import SwiftUI

struct TaskRow: View {
    @EnvironmentObject var store: AppStore
    var item: Item
    var showProject: Bool = true

    @State private var hover = false
    @State private var expanded = false
    @State private var newCheckpoint = ""

    private var project: Project? { store.project(item.projectID) }
    private var tint: Color { project?.color ?? Theme.accent }
    private var selected: Bool { store.selectedTaskID == item.id }
    private var blocked: Bool { store.isBlocked(item) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mainRow
            if expanded && !item.checkpoints.isEmpty {
                checkpointList
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .card(hovering: hover, selected: selected)
        .offset(y: hover ? -1 : 0)
        .onHoverSpring { hover = $0 }
        .contextMenu { contextMenu }
    }

    // MARK: Main row

    private var mainRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Checkbox(done: item.isDone, tint: tint) { store.toggleDone(item.id) }
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(Theme.ui(13, .medium))
                        .foregroundStyle(item.isDone ? Theme.textFaint : Theme.text)
                        .strikethrough(item.isDone, color: Theme.textFaint)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    PriorityFlag(priority: item.priority)

                    if blocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.red)
                            .help("Waiting on another task")
                    }
                    Spacer(minLength: 0)
                }

                // Next concrete step, so the row tells you what to actually do.
                if let next = item.nextCheckpoint, !item.isDone {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(Theme.textFaint)
                        Text(next.title)
                            .font(Theme.ui(11.5))
                            .foregroundStyle(Theme.textDim)
                            .lineLimit(1)
                        if let d = next.due { DuePill(date: d, compact: true) }
                    }
                }

                metaRow
            }

            Spacer(minLength: 4)

            trailing
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(Theme.quick) { store.selectedTaskID = item.id } }
    }

    private var metaRow: some View {
        HStack(spacing: 6) {
            // The category, so a one-day event reads differently from project work.
            if item.category != .task {
                HStack(spacing: 3) {
                    Image(systemName: item.category.icon).font(.system(size: 8.5, weight: .bold))
                    Text(item.category.label).font(Theme.ui(10, .semibold))
                }
                .fixedSize()
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(item.category.tint.opacity(0.13)))
                .foregroundStyle(item.category.tint)
            }
            if showProject, let p = project {
                HStack(spacing: 4) {
                    Circle().fill(p.color).frame(width: 5, height: 5)
                    Text(p.name)
                        .font(Theme.ui(10.5, .medium))
                        .foregroundStyle(Theme.textDim)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            if let due = item.due { DuePill(date: due, isDone: item.isDone, compact: true) }
            ForEach(store.tagsFor(item)) { TagChip(tag: $0, compact: true) }
            if let est = item.estimateHours {
                Pill(text: est == est.rounded() ? "\(Int(est))h" : String(format: "%.1fh", est),
                     icon: "clock", tint: Theme.textFaint)
            }
            Spacer(minLength: 0)
        }
        .clipped()
    }

    private var trailing: some View {
        HStack(spacing: 8) {
            if !item.pages.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "doc.text").font(.system(size: 9, weight: .semibold))
                    Text("\(item.pages.count)").font(Theme.ui(10, .semibold))
                }
                .foregroundStyle(Theme.textFaint)
            }

            if let summary = item.checkpointSummary {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(summary)
                        .font(Theme.mono(10, .semibold))
                        .foregroundStyle(item.progress == 1 ? Theme.green : Theme.textDim)
                    ProgressBar(value: item.progress, tint: tint, height: 3).frame(width: 46)
                }
            }

            if !item.checkpoints.isEmpty {
                Button(action: { withAnimation(Theme.spring) { expanded.toggle() } }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                        .foregroundStyle(hover || expanded ? Theme.textDim : Theme.textFaint.opacity(0.5))
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Inline checkpoints

    private var checkpointList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Theme.stroke).frame(height: 1)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(item.checkpoints) { cp in
                    HStack(spacing: 8) {
                        MiniCheck(done: cp.done, tint: tint) {
                            store.toggleCheckpoint(item.id, cp.id)
                        }
                        Text(cp.title)
                            .font(Theme.ui(12))
                            .foregroundStyle(cp.done ? Theme.textFaint : Theme.text)
                            .strikethrough(cp.done, color: Theme.textFaint)
                        if let d = cp.due, !cp.done { DuePill(date: d, compact: true) }
                        Spacer(minLength: 0)
                    }
                }

                HStack(spacing: 7) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.textFaint)
                    TextField("Add a checkpoint", text: $newCheckpoint)
                        .textFieldStyle(.plain)
                        .font(Theme.ui(12))
                        .onSubmit {
                            store.addCheckpoint(item.id, title: newCheckpoint)
                            newCheckpoint = ""
                        }
                }
                .padding(.top, 1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .padding(.leading, 20)
        }
    }

    // MARK: Context menu

    @ViewBuilder private var contextMenu: some View {
        Button(item.isDone ? "Mark as not done" : "Mark as done") { store.toggleDone(item.id) }
        Divider()
        Menu("Due") {
            Button("Today") { setDue(0) }
            Button("Tomorrow") { setDue(1) }
            Button("In 3 days") { setDue(3) }
            Button("Next week") { setDue(7) }
            Divider()
            Button("Clear") { store.edit(item.id) { $0.due = nil } }
        }
        Menu("Category") {
            ForEach(ItemKind.allCases) { k in
                Button(k.label) { store.edit(item.id) { $0.kind = k } }
            }
        }
        Menu("Priority") {
            ForEach(Priority.allCases) { p in
                Button(p.label) { store.edit(item.id) { $0.priority = p } }
            }
        }
        Menu("Status") {
            ForEach(TaskStatus.allCases) { s in
                Button(s.label) {
                    store.edit(item.id) { t in
                        t.status = s
                        t.completedAt = (s == .done) ? Date() : nil
                    }
                }
            }
        }
        Menu("Move to project") {
            Button("No project") { store.edit(item.id) { $0.projectID = nil } }
            ForEach(store.projects) { p in
                Button(p.name) { store.edit(item.id) { $0.projectID = p.id } }
            }
        }
        Divider()
        Button("Duplicate") {
            var copy = item
            copy.id = UUID()
            copy.title += " (copy)"
            copy.createdAt = Date()
            copy.completedAt = nil
            copy.checkpoints = item.checkpoints.map { c in
                var n = c; n.id = UUID(); n.done = false; n.completedAt = nil; return n
            }
            store.add(copy)
        }
        Button("Delete", role: .destructive) { store.delete(item.id) }
    }

    private func setDue(_ days: Int) {
        let cal = Calendar.current
        let base = cal.date(byAdding: .day, value: days, to: Date()) ?? Date()
        store.edit(item.id) { $0.due = cal.date(bySettingHour: 18, minute: 0, second: 0, of: base) }
    }
}
