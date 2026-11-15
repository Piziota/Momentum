import SwiftUI

enum DetailTab: String, CaseIterable, Identifiable {
    case checkpoints, pages, links, info
    var id: String { rawValue }
    var label: String {
        switch self {
        case .checkpoints: return "Checkpoints"
        case .pages: return "Pages"
        case .links: return "Links"
        case .info: return "Info"
        }
    }
    var icon: String {
        switch self {
        case .checkpoints: return "checklist"
        case .pages: return "doc.text"
        case .links: return "link"
        case .info: return "slider.horizontal.3"
        }
    }
}

struct DetailView: View {
    @EnvironmentObject var store: AppStore
    var item: Item

    @State private var tab: DetailTab = .checkpoints
    @State private var newCheckpoint = ""
    @State private var newLink = ""
    @State private var openPage: UUID? = nil
    @Namespace private var tabNS

    private var project: Project? { store.project(item.projectID) }
    private var tint: Color { project?.color ?? Theme.accent }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            tabBar
            Divider().overlay(Theme.stroke)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch tab {
                    case .checkpoints: checkpointsTab
                    case .pages: pagesTab
                    case .links: linksTab
                    case .info: infoTab
                    }
                }
                .padding(14)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            // A topic you are learning opens on its links, not an empty checklist.
            if item.category == .learning, item.checkpoints.isEmpty { tab = .links }
        }
        .frame(width: 368)
        .background(VisualEffect(material: .contentBackground).ignoresSafeArea())
        .overlay(alignment: .leading) { Rectangle().fill(Theme.stroke).frame(width: 1) }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Menu {
                    Button("No project") { store.edit(item.id) { $0.projectID = nil } }
                    ForEach(store.projects) { p in
                        Button(p.name) { store.edit(item.id) { $0.projectID = p.id } }
                    }
                } label: {
                    HStack(spacing: 5) {
                        ProjectGlyph(project: project, size: 16)
                        Text(project?.name ?? "No project")
                            .font(Theme.ui(11.5, .semibold))
                            .foregroundStyle(tint)
                        Image(systemName: "chevron.down").font(.system(size: 7, weight: .bold))
                            .foregroundStyle(Theme.textFaint)
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Spacer()
                IconButton(icon: "xmark", help: "Close") {
                    withAnimation(Theme.spring) { store.selectedTaskID = nil }
                }
            }

            // Title
            TextField("Task name", text: Binding(
                get: { item.title },
                set: { v in store.edit(item.id) { $0.title = v } }
            ), axis: .vertical)
            .textFieldStyle(.plain)
            .font(Theme.display(16, .semibold))
            .foregroundStyle(Theme.text)

            // Category / status / priority
            HStack(spacing: 6) {
                Menu {
                    ForEach(ItemKind.allCases) { k in
                        Button(k.label + " — " + k.blurb) { store.edit(item.id) { $0.kind = k } }
                    }
                } label: {
                    Pill(text: item.category.label, icon: item.category.icon,
                         tint: item.category.tint)
                }
                .menuStyle(.borderlessButton).fixedSize()

                Menu {
                    ForEach(TaskStatus.allCases) { s in
                        Button(s.label) {
                            store.edit(item.id) { t in
                                t.status = s
                                t.completedAt = (s == .done) ? Date() : nil
                            }
                        }
                    }
                } label: {
                    Pill(text: item.status.label, icon: item.status.icon, tint: item.status.tint)
                }
                .menuStyle(.borderlessButton).fixedSize()

                Menu {
                    ForEach(Priority.allCases) { p in
                        Button(p.label) { store.edit(item.id) { $0.priority = p } }
                    }
                } label: {
                    Pill(text: item.priority == .none ? "Priority" : item.priority.label,
                         icon: "flag.fill", tint: item.priority.tint)
                }
                .menuStyle(.borderlessButton).fixedSize()

                Spacer()
            }

            HStack(spacing: 7) {
                DateButton(label: "Start", date: Binding(
                    get: { item.start },
                    set: { v in store.edit(item.id) { $0.start = v } }
                ), icon: "play.circle", tint: Theme.blue)

                DateButton(label: "Due", date: Binding(
                    get: { item.due },
                    set: { v in store.edit(item.id) { $0.due = v } }
                ), icon: "target", tint: item.isOverdue ? Theme.red : Theme.amber)
            }

            if !item.checkpoints.isEmpty {
                HStack(spacing: 7) {
                    ProgressBar(value: item.progress, tint: tint, height: 5)
                    Text("\(Int(item.progress * 100))%")
                        .font(Theme.mono(10, .bold))
                        .foregroundStyle(item.progress == 1 ? Theme.green : Theme.textDim)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 38)
        .padding(.bottom, 12)
    }

    // MARK: Tab bar

    private var tabBar: some View {
        HStack(spacing: 3) {
            ForEach(DetailTab.allCases) { t in
                let on = t == tab
                Button(action: { withAnimation(Theme.spring) { tab = t } }) {
                    VStack(spacing: 5) {
                        HStack(spacing: 5) {
                            Image(systemName: t.icon).font(.system(size: 10, weight: .semibold))
                            Text(t.label).font(Theme.ui(11.5, .semibold))
                            if t == .checkpoints, !item.checkpoints.isEmpty {
                                Text("\(item.checkpoints.count)")
                                    .font(Theme.ui(9.5, .bold))
                                    .padding(.horizontal, 4).padding(.vertical, 0.5)
                                    .background(Capsule().fill(Theme.stroke))
                            }
                            if t == .links, !item.links.isEmpty {
                                Text("\(item.links.count)")
                                    .font(Theme.ui(9.5, .bold))
                                    .padding(.horizontal, 4).padding(.vertical, 0.5)
                                    .background(Capsule().fill(Theme.stroke))
                            }
                            if t == .pages, !item.pages.isEmpty {
                                Text("\(item.pages.count)")
                                    .font(Theme.ui(9.5, .bold))
                                    .padding(.horizontal, 4).padding(.vertical, 0.5)
                                    .background(Capsule().fill(Theme.stroke))
                            }
                        }
                        .foregroundStyle(on ? Theme.text : Theme.textDim)
                        ZStack {
                            if on {
                                Capsule().fill(tint).frame(height: 2)
                                    .matchedGeometryEffect(id: "tab", in: tabNS)
                            } else {
                                Capsule().fill(.clear).frame(height: 2)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
    }

    // MARK: Checkpoints

    private var checkpointsTab: some View {
        VStack(alignment: .leading, spacing: 9) {
            if item.checkpoints.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Break it into steps")
                        .font(Theme.ui(12.5, .semibold)).foregroundStyle(Theme.text)
                    Text("Checkpoints are the small things under this task. Each can have its own date, and finishing them all completes the task.")
                        .font(Theme.ui(11.5)).foregroundStyle(Theme.textDim)
                }
                .padding(.bottom, 2)
            }

            ForEach(item.checkpoints) { cp in
                CheckpointEditRow(taskID: item.id, checkpoint: cp, tint: tint)
            }

            HStack(spacing: 7) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 13)).foregroundStyle(tint.opacity(0.8))
                TextField("Add a checkpoint", text: $newCheckpoint)
                    .textFieldStyle(.plain)
                    .font(Theme.ui(12.5))
                    .onSubmit {
                        // "Proofread fri" also sets the checkpoint's date.
                        let parsed = QuickParser.parse(newCheckpoint)
                        store.addCheckpoint(item.id,
                                            title: parsed.title.isEmpty ? newCheckpoint : parsed.title,
                                            due: parsed.due)
                        newCheckpoint = ""
                    }
            }
            .padding(.horizontal, 9).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.stroke.opacity(0.5)))

            if !item.notes.isEmpty || true {
                VStack(alignment: .leading, spacing: 5) {
                    Text("NOTES").font(Theme.ui(10, .bold)).tracking(0.7).foregroundStyle(Theme.textFaint)
                    TextEditor(text: Binding(
                        get: { item.notes },
                        set: { v in store.edit(item.id) { $0.notes = v } }
                    ))
                    .font(Theme.ui(12))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 70)
                    .padding(7)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.stroke.opacity(0.45)))
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: Pages

    private var pagesTab: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Pages attached to this task")
                    .font(Theme.ui(11.5)).foregroundStyle(Theme.textDim)
                Spacer()
                GhostButton(title: "New page", icon: "plus") {
                    let id = store.addPage(item.id)
                    withAnimation(Theme.quick) { openPage = id }
                }
            }

            if item.pages.isEmpty {
                EmptyState(icon: "doc.text", title: "No pages yet",
                           message: "Pages hold the long-form stuff: meeting notes, research, links, drafts. Markdown works.",
                           tint: tint)
            }

            ForEach(item.pages) { page in
                PageCard(taskID: item.id, page: page, tint: tint,
                         expanded: openPage == page.id) {
                    withAnimation(Theme.spring) {
                        openPage = (openPage == page.id) ? nil : page.id
                    }
                }
            }
        }
    }

    // MARK: Info

    // MARK: Links

    @ViewBuilder private var linksTab: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Image(systemName: "link")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textFaint)
                    .frame(width: 14)
                InlineField(placeholder: "Paste a link…", text: $newLink, font: Theme.ui(12)) { addLink() }
                GhostButton(title: "Add", icon: "plus") { addLink() }
                    .disabled(newLink.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.bottom, 2)

            if item.links.isEmpty {
                Text("Resources you collect for this one — articles, videos, docs. They also show up under Learning.")
                    .font(Theme.ui(11.5))
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            } else {
                ForEach(item.links) { r in
                    ResourceRow(topicID: item.id, resource: r)
                }
            }
        }
    }

    private func addLink() {
        let raw = newLink.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return }
        let parts = raw.split(separator: " ", maxSplits: 1).map(String.init)
        store.addResource(item.id, url: parts.first ?? raw,
                          title: parts.count > 1 ? parts[1] : "")
        newLink = ""
    }

    private var infoTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Tags
            VStack(alignment: .leading, spacing: 6) {
                Text("TAGS").font(Theme.ui(10, .bold)).tracking(0.7).foregroundStyle(Theme.textFaint)
                TagEditor(item: item)
            }

            // Estimate
            VStack(alignment: .leading, spacing: 6) {
                Text("TIME ESTIMATE").font(Theme.ui(10, .bold)).tracking(0.7).foregroundStyle(Theme.textFaint)
                HStack(spacing: 6) {
                    ForEach([1.0, 2.0, 4.0, 8.0, 16.0], id: \.self) { h in
                        let on = item.estimateHours == h
                        Button(action: {
                            store.edit(item.id) { $0.estimateHours = on ? nil : h }
                        }) {
                            Text("\(Int(h))h")
                                .font(Theme.ui(11, .semibold))
                                .padding(.horizontal, 9).padding(.vertical, 4)
                                .background(Capsule().fill(on ? tint.opacity(0.2) : Theme.stroke.opacity(0.6)))
                                .foregroundStyle(on ? tint : Theme.textDim)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Dependencies
            VStack(alignment: .leading, spacing: 6) {
                Text("WAITING ON").font(Theme.ui(10, .bold)).tracking(0.7).foregroundStyle(Theme.textFaint)
                if item.dependsOn.isEmpty {
                    Text("Nothing — this can start any time.")
                        .font(Theme.ui(11.5)).foregroundStyle(Theme.textFaint)
                }
                ForEach(item.dependsOn, id: \.self) { depID in
                    if let dep = store.task(depID) {
                        HStack(spacing: 7) {
                            Image(systemName: dep.isDone ? "checkmark.circle.fill" : "clock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(dep.isDone ? Theme.green : Theme.amber)
                            Text(dep.title).font(Theme.ui(11.5)).foregroundStyle(Theme.text).lineLimit(1)
                            Spacer()
                            IconButton(icon: "xmark", size: 9) {
                                store.edit(item.id) { $0.dependsOn.removeAll { $0 == depID } }
                            }
                        }
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Theme.stroke.opacity(0.5)))
                    }
                }
                Menu {
                    ForEach(store.tasks.filter { $0.id != item.id && !item.dependsOn.contains($0.id) }) { t in
                        Button(t.title) { _ = store.addDependency(from: item.id, to: t.id) }
                    }
                } label: {
                    Label("Add a prerequisite", systemImage: "plus")
                        .font(Theme.ui(11.5, .medium))
                }
                .menuStyle(.borderlessButton).fixedSize()
            }

            // Custom fields
            if let p = project, !p.fields.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(p.name.uppercased() + " FIELDS")
                        .font(Theme.ui(10, .bold)).tracking(0.7).foregroundStyle(Theme.textFaint)
                    ForEach(p.fields) { f in
                        CustomFieldRow(item: item, field: f)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CUSTOM FIELDS").font(Theme.ui(10, .bold)).tracking(0.7).foregroundStyle(Theme.textFaint)
                    Text(project == nil
                         ? "Put this task in a project to use custom fields."
                         : "Add fields to this project (right-click it in the sidebar → Edit project).")
                        .font(Theme.ui(11.5)).foregroundStyle(Theme.textFaint)
                }
            }

            // Meta
            VStack(alignment: .leading, spacing: 4) {
                Text("Added \(DateFmt.dayMonthYear.string(from: item.createdAt))")
                    .font(Theme.ui(10.5)).foregroundStyle(Theme.textFaint)
                if let c = item.completedAt {
                    Text("Completed \(DateFmt.dayMonthYear.string(from: c))")
                        .font(Theme.ui(10.5)).foregroundStyle(Theme.textFaint)
                }
            }
            .padding(.top, 2)

            Button(action: { withAnimation(Theme.spring) { store.delete(item.id) } }) {
                HStack(spacing: 5) {
                    Image(systemName: "trash").font(.system(size: 10, weight: .semibold))
                    Text("Delete task").font(Theme.ui(11.5, .semibold))
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.red.opacity(0.12)))
                .foregroundStyle(Theme.red)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Checkpoint row with inline editing

struct CheckpointEditRow: View {
    @EnvironmentObject var store: AppStore
    var taskID: UUID
    var checkpoint: Checkpoint
    var tint: Color
    @State private var hover = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            MiniCheck(done: checkpoint.done, tint: tint) {
                store.toggleCheckpoint(taskID, checkpoint.id)
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                TextField("Checkpoint", text: Binding(
                    get: { checkpoint.title },
                    set: { v in
                        store.edit(taskID) { t in
                            if let i = t.checkpoints.firstIndex(where: { $0.id == checkpoint.id }) {
                                t.checkpoints[i].title = v
                            }
                        }
                    }
                ), axis: .vertical)
                .textFieldStyle(.plain)
                .font(Theme.ui(12.5))
                .foregroundStyle(checkpoint.done ? Theme.textFaint : Theme.text)
                .strikethrough(checkpoint.done, color: Theme.textFaint)

                HStack(spacing: 5) {
                    DateButton(label: "Date", date: Binding(
                        get: { checkpoint.due },
                        set: { v in
                            store.edit(taskID) { t in
                                if let i = t.checkpoints.firstIndex(where: { $0.id == checkpoint.id }) {
                                    t.checkpoints[i].due = v
                                }
                            }
                        }
                    ), icon: "calendar", tint: Theme.textDim, compact: true)
                }
            }

            Spacer(minLength: 0)

            if hover {
                IconButton(icon: "trash", size: 9) {
                    store.edit(taskID) { $0.checkpoints.removeAll { $0.id == checkpoint.id } }
                }
            }
        }
        .padding(.horizontal, 9).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(hover ? Theme.stroke.opacity(0.7) : Theme.stroke.opacity(0.4)))
        .onHoverSpring { hover = $0 }
    }
}

// MARK: - Date button with popover picker

struct DateButton: View {
    var label: String
    @Binding var date: Date?
    var icon: String
    var tint: Color
    var compact: Bool = false

    @State private var open = false
    @State private var hover = false

    var body: some View {
        Button(action: { open = true }) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: compact ? 8.5 : 9.5, weight: .semibold))
                Text(date.map { DateFmt.dueLabel($0) } ?? label)
                    .font(Theme.ui(compact ? 10.5 : 11.5, .medium))
            }
            .padding(.horizontal, compact ? 6 : 8).padding(.vertical, compact ? 3 : 5)
            .background(Capsule().fill(date == nil
                                       ? (hover ? Theme.strokeHi : Theme.stroke.opacity(0.6))
                                       : tint.opacity(0.15)))
            .foregroundStyle(date == nil ? Theme.textDim : tint)
        }
        .buttonStyle(.plain)
        .onHoverSpring { hover = $0 }
        .popover(isPresented: $open, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                DatePicker("", selection: Binding(
                    get: { date ?? Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date())! },
                    set: { date = $0 }
                ), displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.graphical)
                .labelsHidden()
                .frame(width: 250)

                HStack(spacing: 6) {
                    GhostButton(title: "Today") { setRelative(0) }
                    GhostButton(title: "Tomorrow") { setRelative(1) }
                    GhostButton(title: "Next week") { setRelative(7) }
                    Spacer()
                    if date != nil {
                        GhostButton(title: "Clear", icon: "xmark") { date = nil; open = false }
                    }
                }
            }
            .padding(12)
        }
    }

    private func setRelative(_ days: Int) {
        let cal = Calendar.current
        let base = cal.date(byAdding: .day, value: days, to: Date()) ?? Date()
        date = cal.date(bySettingHour: 18, minute: 0, second: 0, of: base)
        open = false
    }
}

// MARK: - Tag editor

struct TagEditor: View {
    @EnvironmentObject var store: AppStore
    var item: Item
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if !item.tagIDs.isEmpty {
                HStack(spacing: 5) {
                    ForEach(store.tagsFor(item)) { t in
                        HStack(spacing: 4) {
                            TagChip(tag: t)
                            Button(action: {
                                store.edit(item.id) { $0.tagIDs.removeAll { $0 == t.id } }
                            }) {
                                Image(systemName: "xmark").font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(t.color)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            HStack(spacing: 6) {
                TextField("Add a tag", text: $draft)
                    .textFieldStyle(.plain)
                    .font(Theme.ui(11.5))
                    .onSubmit {
                        let name = draft.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
                        guard !name.isEmpty else { return }
                        let tag = store.tagNamed(name)
                        store.edit(item.id) { if !$0.tagIDs.contains(tag.id) { $0.tagIDs.append(tag.id) } }
                        draft = ""
                    }
                if !store.tags.isEmpty {
                    Menu {
                        ForEach(store.tags.filter { !item.tagIDs.contains($0.id) }) { t in
                            Button("#" + t.name) {
                                store.edit(item.id) { $0.tagIDs.append(t.id) }
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                    }
                    .menuStyle(.borderlessButton).fixedSize()
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.stroke.opacity(0.5)))
        }
    }
}

// MARK: - Custom field row

struct CustomFieldRow: View {
    @EnvironmentObject var store: AppStore
    var item: Item
    var field: FieldDef

    private var key: String { field.id.uuidString }
    private var value: String { item.values[key] ?? "" }

    private func set(_ v: String) {
        store.edit(item.id) { t in
            if v.isEmpty { t.values.removeValue(forKey: key) } else { t.values[key] = v }
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: field.kind.icon)
                    .font(.system(size: 9)).foregroundStyle(Theme.textFaint)
                Text(field.name).font(Theme.ui(11.5, .medium)).foregroundStyle(Theme.textDim)
            }
            .frame(width: 96, alignment: .leading)

            switch field.kind {
            case .select:
                Menu {
                    Button("—") { set("") }
                    ForEach(field.options, id: \.self) { o in Button(o) { set(o) } }
                } label: {
                    Text(value.isEmpty ? "Choose" : value)
                        .font(Theme.ui(11.5, .medium))
                        .foregroundStyle(value.isEmpty ? Theme.textFaint : Theme.text)
                }
                .menuStyle(.borderlessButton)

            case .date:
                DateButton(label: "Pick a date", date: Binding(
                    get: {
                        guard let t = Double(value) else { return nil }
                        return Date(timeIntervalSince1970: t)
                    },
                    set: { d in set(d.map { String($0.timeIntervalSince1970) } ?? "") }
                ), icon: "calendar", tint: Theme.blue, compact: true)

            case .url:
                HStack(spacing: 5) {
                    TextField("https://", text: Binding(get: { value }, set: { set($0) }))
                        .textFieldStyle(.plain).font(Theme.ui(11.5))
                    if let u = URL(string: value), !value.isEmpty {
                        Button(action: { NSWorkspace.shared.open(u) }) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 10)).foregroundStyle(Theme.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }

            case .number:
                TextField("0", text: Binding(get: { value }, set: { set($0.filter { "0123456789.,-".contains($0) }) }))
                    .textFieldStyle(.plain).font(Theme.mono(11.5))

            case .text:
                TextField("—", text: Binding(get: { value }, set: { set($0) }))
                    .textFieldStyle(.plain).font(Theme.ui(11.5))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.stroke.opacity(0.45)))
    }
}
