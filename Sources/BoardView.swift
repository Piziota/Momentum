import SwiftUI

struct BoardView: View {
    @EnvironmentObject var store: AppStore
    var items: [Item]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(TaskStatus.allCases) { status in
                    BoardColumn(status: status, items: items.filter { $0.status == status })
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

struct BoardColumn: View {
    @EnvironmentObject var store: AppStore
    var status: TaskStatus
    var items: [Item]

    @State private var targeted = false
    @State private var adding = false
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: status.icon)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(status.tint)
                Text(status.label.uppercased())
                    .font(Theme.ui(10.5, .bold)).tracking(0.7)
                    .foregroundStyle(Theme.textDim)
                Text("\(items.count)")
                    .font(Theme.ui(10, .bold))
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Capsule().fill(status.tint.opacity(0.16)))
                    .foregroundStyle(status.tint)
                Spacer()
                IconButton(icon: "plus", help: "Add here", size: 10) {
                    withAnimation(Theme.quick) { adding = true }
                }
            }
            .padding(.horizontal, 4)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 7) {
                    if adding {
                        InlineField(placeholder: "New task", text: $draft) { commit() }
                            .onDisappear { adding = false }
                    }
                    ForEach(items) { item in
                        BoardCard(item: item)
                            .draggable(item.id.uuidString)
                    }
                    if items.isEmpty && !adding {
                        Text("Drop tasks here")
                            .font(Theme.ui(11))
                            .foregroundStyle(Theme.textFaint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 26)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .padding(9)
        .frame(width: 264)
        .background(
            RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous)
                .fill(targeted ? status.tint.opacity(0.08) : Theme.stroke.opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous)
                .strokeBorder(targeted ? status.tint.opacity(0.6) : .clear, lineWidth: 1.5)
        )
        .dropDestination(for: String.self) { ids, _ in
            for raw in ids {
                guard let id = UUID(uuidString: raw) else { continue }
                store.edit(id) { t in
                    t.status = status
                    t.completedAt = (status == .done) ? Date() : nil
                    if status == .done {
                        for i in t.checkpoints.indices { t.checkpoints[i].done = true }
                    }
                }
            }
            return true
        } isTargeted: { on in
            withAnimation(Theme.quick) { targeted = on }
        }
    }

    private func commit() {
        let title = draft.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { adding = false; return }
        let parsed = QuickParser.parse(title)
        var item = Item(projectID: currentProjectID, title: parsed.title.isEmpty ? title : parsed.title)
        item.status = status
        item.priority = parsed.priority
        item.due = parsed.due
        item.tagIDs = parsed.tagNames.map { store.tagNamed($0).id }
        if status == .done { item.completedAt = Date() }
        store.add(item)
        draft = ""
        adding = false
    }

    private var currentProjectID: UUID? {
        if case .project(let id) = store.route { return id }
        return nil
    }
}

// MARK: - Compact card for the board

struct BoardCard: View {
    @EnvironmentObject var store: AppStore
    var item: Item
    @State private var hover = false

    private var project: Project? { store.project(item.projectID) }
    private var tint: Color { project?.color ?? Theme.accent }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 8) {
                Checkbox(done: item.isDone, tint: tint, size: 16) { store.toggleDone(item.id) }
                Text(item.title)
                    .font(Theme.ui(12.5, .medium))
                    .foregroundStyle(item.isDone ? Theme.textFaint : Theme.text)
                    .strikethrough(item.isDone, color: Theme.textFaint)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                PriorityFlag(priority: item.priority)
            }

            if let summary = item.checkpointSummary {
                HStack(spacing: 6) {
                    ProgressBar(value: item.progress, tint: tint, height: 3)
                    Text(summary).font(Theme.mono(9.5, .semibold)).foregroundStyle(Theme.textFaint)
                }
            }

            HStack(spacing: 5) {
                if let p = project {
                    HStack(spacing: 3) {
                        Circle().fill(p.color).frame(width: 4.5, height: 4.5)
                        Text(p.name).font(Theme.ui(10)).foregroundStyle(Theme.textDim).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if store.isBlocked(item) {
                    Image(systemName: "lock.fill").font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.red)
                }
                if let due = item.due { DuePill(date: due, isDone: item.isDone, compact: true) }
            }

            if !item.tagIDs.isEmpty {
                HStack(spacing: 4) {
                    ForEach(store.tagsFor(item)) { TagChip(tag: $0, compact: true) }
                }
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(hovering: hover, selected: store.selectedTaskID == item.id, radius: 10)
        .onHoverSpring { hover = $0 }
        .onTapGesture { store.selectedTaskID = item.id }
    }
}
