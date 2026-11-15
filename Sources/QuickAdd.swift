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

    // Explicit when-pickers. Each stays nil until you choose, so anything typed
    // into the field ("fri 5pm") still drives them.
    @State private var pickedDay: Date? = nil
    @State private var pickedTime: DateComponents? = nil
    @State private var noDate = false
    @State private var noTime = false
    @State private var showDatePicker = false
    @State private var showTimePicker = false

    private let cal = Calendar.current

    // MARK: Date and time, typed or picked

    private var parsedDay: Date? {
        parsed.due.map { cal.startOfDay(for: $0) }
    }
    private var parsedTime: DateComponents? {
        guard let d = parsed.due, DateFmt.hasTime(d) else { return nil }
        return cal.dateComponents([.hour, .minute], from: d)
    }
    /// What you picked wins; otherwise whatever was typed.
    private var effectiveDay: Date? {
        if noDate { return nil }
        return pickedDay ?? parsedDay
    }
    private var effectiveTime: DateComponents? {
        if noDate || noTime { return nil }
        return pickedTime ?? parsedTime
    }
    /// A time with no date means today — matching how the text parser behaves.
    private var effectiveDue: Date? {
        if noDate { return nil }
        let time = effectiveTime
        guard let day = effectiveDay ?? (time != nil ? cal.startOfDay(for: Date()) : nil) else {
            return nil
        }
        guard let t = time else { return day }
        return cal.date(bySettingHour: t.hour ?? 9, minute: t.minute ?? 0, second: 0, of: day)
    }

    private func isDay(_ offset: Int) -> Bool {
        guard let d = effectiveDay else { return false }
        return cal.isDate(d, inSameDayAs: cal.date(byAdding: .day, value: offset, to: Date()) ?? Date())
    }
    private func setDay(_ offset: Int) {
        noDate = false
        pickedDay = cal.startOfDay(for: cal.date(byAdding: .day, value: offset, to: Date()) ?? Date())
    }
    private func setTime(_ h: Int, _ m: Int) {
        noTime = false
        pickedTime = DateComponents(hour: h, minute: m)
    }
    private func isTime(_ h: Int, _ m: Int) -> Bool {
        guard let t = effectiveTime else { return false }
        return t.hour == h && t.minute == m
    }

    /// What it looks like, unless you say otherwise.
    private var suggestedKind: ItemKind {
        let p = parsed
        let words = p.title.lowercased()
        if words.hasPrefix("learn") || words.contains("read ") || words.contains("course")
            || words.contains("study") || words.contains("practice") || words.contains("tutorial") {
            return .learning
        }
        if effectiveTime != nil { return .event }
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
                Divider().overlay(Theme.stroke)
                whenPicker
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

    // MARK: When — date required-ish, time optional

    private var whenPicker: some View {
        VStack(alignment: .leading, spacing: 7) {
            // --- Date
            HStack(spacing: 6) {
                Text("WHEN?")
                    .font(Theme.ui(9.5, .bold)).tracking(0.7)
                    .foregroundStyle(Theme.textFaint)
                    .frame(width: 74, alignment: .leading)

                ChoiceChip(label: "Today", on: isDay(0), tint: Theme.amber) { setDay(0) }
                ChoiceChip(label: "Tomorrow", on: isDay(1), tint: Theme.blue) { setDay(1) }
                ChoiceChip(label: DateFmt.weekdayShort.string(
                    from: cal.date(byAdding: .day, value: 7, to: Date()) ?? Date()) + " (1w)",
                           on: isDay(7), tint: Theme.accent) { setDay(7) }

                // Any other date
                Button(action: { showDatePicker = true }) {
                    ChipBody(label: customDateLabel, icon: "calendar",
                             on: isCustomDate, tint: Theme.violet)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showDatePicker, arrowEdge: .bottom) {
                    VStack(spacing: 10) {
                        DatePicker("", selection: Binding(
                            get: { effectiveDay ?? cal.startOfDay(for: Date()) },
                            set: { d in noDate = false; pickedDay = cal.startOfDay(for: d) }
                        ), displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .frame(width: 250)
                        GhostButton(title: "Done") { showDatePicker = false }
                    }
                    .padding(12)
                }

                ChoiceChip(label: "No date", on: effectiveDay == nil && effectiveTime == nil,
                           tint: Theme.textFaint) {
                    noDate = true; noTime = true; pickedDay = nil; pickedTime = nil
                }
                Spacer(minLength: 0)
            }

            // --- Time (optional)
            HStack(spacing: 6) {
                Text("TIME")
                    .font(Theme.ui(9.5, .bold)).tracking(0.7)
                    .foregroundStyle(Theme.textFaint)
                    .frame(width: 74, alignment: .leading)

                ChoiceChip(label: "All day", on: effectiveTime == nil, tint: Theme.textFaint) {
                    noTime = true; pickedTime = nil
                }
                ChoiceChip(label: "09:00", on: isTime(9, 0), tint: Theme.teal) { setTime(9, 0) }
                ChoiceChip(label: "12:00", on: isTime(12, 0), tint: Theme.teal) { setTime(12, 0) }
                ChoiceChip(label: "17:00", on: isTime(17, 0), tint: Theme.teal) { setTime(17, 0) }

                Button(action: { showTimePicker = true }) {
                    ChipBody(label: customTimeLabel, icon: "clock",
                             on: isCustomTime, tint: Theme.violet)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showTimePicker, arrowEdge: .bottom) {
                    VStack(spacing: 10) {
                        DatePicker("", selection: Binding(
                            get: {
                                let base = effectiveDay ?? cal.startOfDay(for: Date())
                                guard let t = effectiveTime else {
                                    return cal.date(bySettingHour: 9, minute: 0, second: 0, of: base) ?? base
                                }
                                return cal.date(bySettingHour: t.hour ?? 9, minute: t.minute ?? 0,
                                                second: 0, of: base) ?? base
                            },
                            set: { d in
                                noTime = false
                                pickedTime = cal.dateComponents([.hour, .minute], from: d)
                            }
                        ), displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.stepperField)
                        .labelsHidden()
                        .frame(width: 110)
                        GhostButton(title: "Done") { showTimePicker = false }
                    }
                    .padding(12)
                }

                Text("optional")
                    .font(Theme.ui(10))
                    .foregroundStyle(Theme.textFaint)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private var isCustomDate: Bool {
        guard effectiveDay != nil else { return false }
        return !isDay(0) && !isDay(1) && !isDay(7)
    }
    private var customDateLabel: String {
        guard let d = effectiveDay, isCustomDate else { return "Pick a date" }
        return DateFmt.dayMonth.string(from: d)
    }
    private var isCustomTime: Bool {
        guard effectiveTime != nil else { return false }
        return !isTime(9, 0) && !isTime(12, 0) && !isTime(17, 0)
    }
    private var customTimeLabel: String {
        guard let t = effectiveTime, isCustomTime else { return "Other" }
        return String(format: "%02d:%02d", t.hour ?? 0, t.minute ?? 0)
    }

    /// The parser's hints, with its date replaced by whatever the pickers actually settled on,
    /// so the summary can never contradict the chips above it.
    private var shownHints: [String] {
        var hints = parsed.hints.filter { !$0.hasPrefix("due ") }
        if let due = effectiveDue {
            hints.insert("due " + DateFmt.dueLabel(due), at: 0)
        }
        return hints
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

            ForEach(shownHints, id: \.self) { h in
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
        item.due = effectiveDue            // the pickers win over anything typed
        item.estimateHours = p.estimateHours
        item.tagIDs = p.tagNames.map { store.tagNamed($0).id }

        // The category decides how it sits in time.
        switch kind {
        case .project:
            // Spans days, so it gets a start and shows as a bar on the timeline.
            item.start = cal.startOfDay(for: min(Date(), effectiveDue ?? Date()))
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
        chosenKind = nil
        pickedDay = nil
        pickedTime = nil
        noDate = false
        noTime = false
    }
}

// MARK: - Chips used by the when-picker

/// Visual body of a chip, split out so a Button or a popover anchor can reuse it.
struct ChipBody: View {
    var label: String
    var icon: String? = nil
    var on: Bool
    var tint: Color

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon).font(.system(size: 9, weight: .semibold))
            }
            Text(label).font(Theme.ui(11, .semibold)).lineLimit(1)
        }
        .fixedSize()
        .padding(.horizontal, 9).padding(.vertical, 4.5)
        .background(Capsule().fill(on ? tint.opacity(0.18) : Theme.stroke.opacity(0.6)))
        .overlay(Capsule().strokeBorder(on ? tint.opacity(0.65) : .clear, lineWidth: 1))
        .foregroundStyle(on ? tint : Theme.textDim)
    }
}

struct ChoiceChip: View {
    var label: String
    var icon: String? = nil
    var on: Bool
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: { withAnimation(Theme.quick) { action() } }) {
            ChipBody(label: label, icon: icon, on: on, tint: tint)
        }
        .buttonStyle(.plain)
    }
}
