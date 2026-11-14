import SwiftUI

/// Command-palette style capture. One line in, a structured task out.
struct QuickAddPalette: View {
    @EnvironmentObject var store: AppStore
    @Binding var open: Bool

    @State private var text = ""
    @State private var projectID: UUID? = nil
    @State private var chosenKind: ItemKind? = nil
    @FocusState private var focused: Bool
    @Namespace private var kindNS

    /// What it looks like, unless you say otherwise.
    private var suggestedKind: ItemKind {
        let p = parsed
        let words = p.title.lowercased()
        if words.hasPrefix("learn") || words.contains("read ") || words.contains("course")
            || words.contains("study") || words.contains("practice") || words.contains("tutorial") {
            return .learning
        }
        if let due = p.due, DateFmt.hasTime(due) { return .event }
        if p.estimateHours ?? 0 >= 4 { return .project }
        return .task
    }

    private var kind: ItemKind { chosenKind ?? suggestedKind }

    private var parsed: ParsedInput { QuickParser.parse(text) }

    private var resolvedProject: Project? {
        if let q = parsed.projectQuery,
           let match = store.projects.first(where: { $0.name.lowercased().hasPrefix(q.lowercased()) }) {
            return match
        }
        return store.project(projectID)
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Dimmed backdrop
            Color.black.opacity(0.32)
                .ignoresSafeArea()
                .onTapGesture { close() }

            VStack(spacing: 0) {
                field
                Divider().overlay(Theme.stroke)
                kindPicker
                if !text.isEmpty { Divider().overlay(Theme.stroke); understood }
                Divider().overlay(Theme.stroke)
                footer
            }
            .frame(width: 660)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.strokeHi, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 36, y: 14)
            .padding(.top, 110)
        }
        .onAppear { focused = true }
    }

    // MARK: Field

    private var field: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.accent, Theme.violet],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13, weight: .black)).foregroundStyle(.white)
            }
            .frame(width: 30, height: 30)

            TextField("What needs doing?", text: $text)
                .textFieldStyle(.plain)
                .font(Theme.display(18, .medium))
                .foregroundStyle(Theme.text)
                .focused($focused)
                .onSubmit(commit)

            Button(action: close) {
                Text("esc")
                    .font(Theme.mono(9.5, .semibold))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Theme.strokeHi))
                    .foregroundStyle(Theme.textFaint)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 16).padding(.vertical, 15)
    }

    // MARK: What kind of thing is this?

    private var kindPicker: some View {
        HStack(spacing: 7) {
            Text("WHAT IS IT?")
                .font(Theme.ui(9.5, .bold)).tracking(0.7)
                .foregroundStyle(Theme.textFaint)
                .frame(width: 74, alignment: .leading)

            ForEach(ItemKind.allCases) { k in
                let on = k == kind
                Button(action: { withAnimation(Theme.spring) { chosenKind = k } }) {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 5) {
                            Image(systemName: k.icon).font(.system(size: 10.5, weight: .semibold))
                            Text(k.label).font(Theme.ui(11.5, .semibold))
                        }
                        .foregroundStyle(on ? k.tint : Theme.textDim)
                        Text(k.blurb)
                            .font(Theme.ui(9.5))
                            .foregroundStyle(on ? Theme.textDim : Theme.textFaint)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        ZStack {
                            if on {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(k.tint.opacity(0.14))
                                    .matchedGeometryEffect(id: "kindpill", in: kindNS)
                            }
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(on ? k.tint.opacity(0.55) : Theme.stroke, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(k.blurb)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    // MARK: Live interpretation

    private var understood: some View {
        HStack(spacing: 7) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.violet)

            Text(parsed.title.isEmpty ? "—" : parsed.title)
                .font(Theme.ui(12, .medium))
                .foregroundStyle(Theme.text)
                .lineLimit(1)

            if let p = resolvedProject {
                HStack(spacing: 4) {
                    Circle().fill(p.color).frame(width: 5, height: 5)
                    Text(p.name).font(Theme.ui(10.5, .medium)).foregroundStyle(p.color)
                }
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(p.color.opacity(0.14)))
            }

            ForEach(parsed.hints, id: \.self) { h in
                Text(h)
                    .font(Theme.ui(10.5, .medium))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Theme.strokeHi))
                    .foregroundStyle(Theme.textDim)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 9)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Menu {
                Button("No project") { projectID = nil }
                ForEach(store.projects) { p in Button(p.name) { projectID = p.id } }
            } label: {
                HStack(spacing: 5) {
                    ProjectGlyph(project: resolvedProject, size: 15)
                    Text(resolvedProject?.name ?? "No project")
                        .font(Theme.ui(11.5, .medium))
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            Text("fri · 5pm · #tag · @project · !high · ~2h")
                .font(Theme.mono(10))
                .foregroundStyle(Theme.textFaint)

            PrimaryButton(title: "Add", icon: "return") { commit() }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    // MARK: Actions

    private func commit() {
        let raw = text.trimmingCharacters(in: .whitespaces)
        // Do nothing on an empty field. (A Space-based capture hotkey sends its key-up
        // into the new palette, which would otherwise "click" Add and dismiss it.)
        guard !raw.isEmpty else { return }
        let p = parsed
        let cal = Calendar.current
        var item = Item(projectID: resolvedProject?.id ?? defaultProjectID,
                        title: p.title.isEmpty ? raw : p.title)
        item.kind = kind
        item.priority = p.priority
        item.due = p.due
        item.estimateHours = p.estimateHours
        item.tagIDs = p.tagNames.map { store.tagNamed($0).id }

        // The category decides how it sits in time.
        switch kind {
        case .project:
            // Spans days, so it gets a start and shows as a bar on the timeline.
            item.start = cal.startOfDay(for: min(Date(), p.due ?? Date()))
            if item.due == nil {
                item.due = cal.date(bySettingHour: 18, minute: 0, second: 0,
                                    of: cal.date(byAdding: .day, value: 7, to: Date()) ?? Date())
            }
        case .event:
            // A single point in time — no span, and it needs a date to be an event at all.
            item.start = nil
            if item.due == nil {
                item.due = cal.date(bySettingHour: 9, minute: 0, second: 0, of: Date())
            }
        case .learning:
            // Ongoing: no deadline pressure unless you asked for one.
            item.start = nil
            item.status = .active
        case .task:
            item.start = nil
        }

        store.add(item)
        chosenKind = nil
        text = ""
        close()
    }

    private var defaultProjectID: UUID? {
        if case .project(let id) = store.route { return id }
        return nil
    }

    private func close() {
        withAnimation(Theme.quick) { open = false }
        text = ""
    }
}
