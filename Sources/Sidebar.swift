import SwiftUI

struct Sidebar: View {
    @EnvironmentObject var store: AppStore
    @State private var newProject = ""
    @State private var addingProject = false
    @State private var editingProject: Project? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
            searchField
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    smartLists
                    projectList
                    if !store.tags.isEmpty { tagList }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            footer
        }
        .background(VisualEffect(material: .sidebar).ignoresSafeArea())
        .sheet(item: $editingProject) { p in
            ProjectEditor(project: p).environmentObject(store)
        }
    }

    // MARK: Brand

    private var brand: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.accent, Theme.violet],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.white)
            }
            .frame(width: 22, height: 22)
            .shadow(color: Theme.accent.opacity(0.4), radius: 6, y: 2)

            Text("Momentum")
                .font(Theme.display(14.5, .bold))
                .foregroundStyle(Theme.text)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 38)          // clears the traffic lights
        .padding(.bottom, 12)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textFaint)
            TextField("Search everything", text: $store.search)
                .textFieldStyle(.plain)
                .font(Theme.ui(12))
            if !store.search.isEmpty {
                Button(action: { store.search = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textFaint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.stroke.opacity(0.7)))
        .padding(.horizontal, 12)
        .padding(.bottom, 14)
    }

    // MARK: Smart lists

    private var smartLists: some View {
        VStack(spacing: 2) {
            SidebarRow(icon: "sun.max.fill", title: "Today", tint: Theme.accent,
                       count: store.todayTotal,
                       urgent: !store.overdue.isEmpty,
                       selected: store.route == .today) { store.route = .today }

            SidebarRow(icon: "calendar", title: "Upcoming", tint: Theme.blue,
                       count: store.dueSoon.count,
                       selected: store.route == .upcoming) { store.route = .upcoming }

            SidebarRow(icon: "books.vertical.fill", title: "Learning", tint: Theme.violet,
                       count: store.unreadLinks,
                       selected: store.route == .learning) { store.route = .learning }

            SidebarRow(icon: "square.stack.3d.up", title: "All tasks", tint: Theme.textDim,
                       count: store.tasks.filter { !$0.isDone }.count,
                       selected: store.route == .all) { store.route = .all }
        }
    }

    // MARK: Projects

    private var projectList: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("PROJECTS")
                    .font(Theme.ui(10, .bold)).tracking(0.8)
                    .foregroundStyle(Theme.textFaint)
                Spacer()
                IconButton(icon: "plus", help: "New project", size: 10) {
                    withAnimation(Theme.quick) { addingProject = true }
                }
            }
            .padding(.horizontal, 6)

            ForEach(store.projects) { p in
                SidebarRow(icon: p.icon, title: p.name, tint: p.color,
                           count: store.openCount(for: p),
                           selected: store.route == .project(p.id)) {
                    store.route = .project(p.id)
                }
                .contextMenu {
                    Button("Edit project") { editingProject = p }
                    Button("Delete project", role: .destructive) { store.deleteProject(p.id) }
                }
            }

            if addingProject {
                InlineField(placeholder: "Project name", text: $newProject) {
                    let name = newProject.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty {
                        let p = store.addProject(name: name)
                        store.route = .project(p.id)
                    }
                    newProject = ""
                    addingProject = false
                }
                .padding(.horizontal, 4)
                .transition(.opacity)
            }
        }
    }

    // MARK: Tags

    private var tagList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TAGS")
                .font(Theme.ui(10, .bold)).tracking(0.8)
                .foregroundStyle(Theme.textFaint)
                .padding(.horizontal, 6)

            ForEach(store.tags) { t in
                SidebarRow(icon: "number", title: t.name, tint: t.color,
                           count: store.tasks.filter { $0.tagIDs.contains(t.id) && !$0.isDone }.count,
                           selected: store.route == .tag(t.id)) {
                    store.route = .tag(t.id)
                }
                .contextMenu {
                    Button("Delete tag", role: .destructive) { store.deleteTag(t.id) }
                }
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 8) {
            Rectangle().fill(Theme.stroke).frame(height: 1)
            HStack(spacing: 8) {
                IconButton(icon: store.theme.icon,
                           help: "Theme: \(store.theme.label) — click for \(store.theme.next.label)",
                           size: 11) {
                    store.setTheme(store.theme.next)
                }
                if store.streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.amber)
                        Text("\(store.streak)d")
                            .font(Theme.ui(10.5, .semibold))
                            .foregroundStyle(Theme.textDim)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
                Spacer()
                Toggle(isOn: $store.showDone) { Text("Done").font(Theme.ui(10.5)) }
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .foregroundStyle(Theme.textDim)
            }
            .padding(.leading, 6)
            .padding(.trailing, 14)
            .padding(.bottom, 10)
        }
    }
}

// MARK: - A single sidebar row

struct SidebarRow: View {
    var icon: String
    var title: String
    var tint: Color
    var count: Int = 0
    var urgent: Bool = false
    var selected: Bool
    var action: () -> Void

    @State private var hover = false

    var body: some View {
        Button(action: { withAnimation(Theme.quick) { action() } }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(selected ? tint : (hover ? Theme.text : Theme.textDim))
                    .frame(width: 16)

                Text(title)
                    .font(Theme.ui(12.5, selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Theme.text : (hover ? Theme.text : Theme.textDim))
                    .lineLimit(1)

                Spacer(minLength: 2)

                if count > 0 {
                    Text("\(count)")
                        .font(Theme.ui(10.5, .semibold))
                        .foregroundStyle(urgent ? .white : (selected ? tint : Theme.textFaint))
                        .padding(.horizontal, 5).padding(.vertical, 1.5)
                        .background(
                            Capsule().fill(urgent ? Theme.red
                                                  : (selected ? tint.opacity(0.18) : Theme.stroke))
                        )
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? tint.opacity(0.14) : (hover ? Theme.stroke.opacity(0.8) : .clear))
            )
            .overlay(alignment: .leading) {
                if selected {
                    Capsule().fill(tint).frame(width: 2.5, height: 14).offset(x: -1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHoverSpring { hover = $0 }
    }
}

// MARK: - Project editor sheet

struct ProjectEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State var project: Project
    @State private var newFieldName = ""
    @State private var newFieldKind: FieldKind = .text

    private let icons = ["folder.fill", "briefcase.fill", "chart.line.uptrend.xyaxis", "house.fill",
                         "book.fill", "heart.fill", "airplane", "cart.fill", "hammer.fill",
                         "graduationcap.fill", "music.note", "camera.fill", "leaf.fill", "flame.fill"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit project").font(Theme.display(16, .bold)).foregroundStyle(Theme.text)

            VStack(alignment: .leading, spacing: 6) {
                Text("NAME").font(Theme.ui(10, .bold)).tracking(0.7).foregroundStyle(Theme.textFaint)
                InlineField(placeholder: "Project name", text: $project.name)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("COLOUR").font(Theme.ui(10, .bold)).tracking(0.7).foregroundStyle(Theme.textFaint)
                HStack(spacing: 7) {
                    ForEach(Theme.palette, id: \.self) { hex in
                        Button(action: { project.colorHex = hex }) {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle().strokeBorder(.white.opacity(project.colorHex == hex ? 0.95 : 0),
                                                          lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("ICON").font(Theme.ui(10, .bold)).tracking(0.7).foregroundStyle(Theme.textFaint)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 6), count: 7), spacing: 6) {
                    ForEach(icons, id: \.self) { ic in
                        Button(action: { project.icon = ic }) {
                            Image(systemName: ic)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(project.icon == ic ? project.color : Theme.textDim)
                                .frame(width: 28, height: 28)
                                .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(project.icon == ic ? project.color.opacity(0.16) : Theme.stroke.opacity(0.6)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("CUSTOM FIELDS").font(Theme.ui(10, .bold)).tracking(0.7).foregroundStyle(Theme.textFaint)
                Text("Extra info you want on every task in this project.")
                    .font(Theme.ui(11)).foregroundStyle(Theme.textFaint)

                ForEach(project.fields) { f in
                    HStack(spacing: 7) {
                        Image(systemName: f.kind.icon).font(.system(size: 10)).foregroundStyle(Theme.textDim)
                        Text(f.name).font(Theme.ui(12)).foregroundStyle(Theme.text)
                        Text(f.kind.label).font(Theme.ui(10)).foregroundStyle(Theme.textFaint)
                        Spacer()
                        IconButton(icon: "trash", size: 10) {
                            project.fields.removeAll { $0.id == f.id }
                        }
                    }
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Theme.stroke.opacity(0.5)))
                }

                HStack(spacing: 7) {
                    InlineField(placeholder: "Field name", text: $newFieldName) { addField() }
                    Picker("", selection: $newFieldKind) {
                        ForEach(FieldKind.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 110)
                    GhostButton(title: "Add", icon: "plus") { addField() }
                }
            }

            HStack {
                Spacer()
                GhostButton(title: "Cancel") { dismiss() }
                PrimaryButton(title: "Save", icon: "checkmark", tint: project.color) {
                    store.updateProject(project)
                    dismiss()
                }
            }
        }
        .padding(20)
        .frame(width: 430)
        .background(Theme.bg)
    }

    private func addField() {
        let n = newFieldName.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        project.fields.append(FieldDef(name: n, kind: newFieldKind))
        newFieldName = ""
    }
}
