import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var store: AppStore
    var items: [Item]

    @State private var month: Date = Calendar.current.startOfDay(for: Date())
    @State private var selectedDay: Date? = Calendar.current.startOfDay(for: Date())

    private let cal = Calendar.current
    private let weekdaySymbols: [String] = {
        var c = Calendar.current
        let syms = c.shortWeekdaySymbols
        let first = c.firstWeekday - 1
        return Array(syms[first...] + syms[..<first])
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 10) {
                monthHeader
                weekdayHeader
                grid
            }
            dayPanel
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    // MARK: Header

    private var monthHeader: some View {
        HStack(spacing: 10) {
            Text(DateFmt.monthYear.string(from: month))
                .font(Theme.display(18, .bold))
                .foregroundStyle(Theme.text)
            Spacer()
            GhostButton(title: "Today") {
                withAnimation(Theme.spring) {
                    month = cal.startOfDay(for: Date())
                    selectedDay = month
                }
            }
            HStack(spacing: 2) {
                IconButton(icon: "chevron.left", help: "Previous month") { shift(-1) }
                IconButton(icon: "chevron.right", help: "Next month") { shift(1) }
            }
        }
    }

    private func shift(_ n: Int) {
        withAnimation(Theme.spring) {
            month = cal.date(byAdding: .month, value: n, to: month) ?? month
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 6) {
            ForEach(weekdaySymbols, id: \.self) { s in
                Text(s.uppercased())
                    .font(Theme.ui(10, .bold)).tracking(0.6)
                    .foregroundStyle(Theme.textFaint)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Grid

    private var gridDays: [Date] {
        guard let first = cal.date(from: cal.dateComponents([.year, .month], from: month)) else { return [] }
        let weekday = cal.component(.weekday, from: first)
        let lead = (weekday - cal.firstWeekday + 7) % 7
        guard let gridStart = cal.date(byAdding: .day, value: -lead, to: first) else { return [] }
        let daysInMonth = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        let cells = Int(ceil(Double(lead + daysInMonth) / 7.0)) * 7
        return (0..<cells).compactMap { cal.date(byAdding: .day, value: $0, to: gridStart) }
    }

    private var grid: some View {
        let days = gridDays
        let rows = max(1, days.count / 7)
        return VStack(spacing: 6) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { c in
                        let idx = r * 7 + c
                        if idx < days.count {
                            DayCell(day: days[idx],
                                    inMonth: cal.isDate(days[idx], equalTo: month, toGranularity: .month),
                                    items: tasks(on: days[idx]),
                                    selected: selectedDay.map { cal.isDate($0, inSameDayAs: days[idx]) } ?? false)
                            { withAnimation(Theme.quick) { selectedDay = days[idx] } }
                        } else {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private func tasks(on day: Date) -> [Item] {
        items.filter { item in
            if let d = item.due, cal.isDate(d, inSameDayAs: day) { return true }
            return item.checkpoints.contains { c in
                guard let cd = c.due else { return false }
                return cal.isDate(cd, inSameDayAs: day)
            }
        }
        .sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }
    }

    // MARK: Day detail panel

    private var dayPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let day = selectedDay {
                HStack(spacing: 6) {
                    Text(DateFmt.fullDay.string(from: day))
                        .font(Theme.display(14, .bold))
                        .foregroundStyle(Theme.text)
                    if cal.isDateInToday(day) {
                        Pill(text: "Today", tint: Theme.accent)
                    }
                }

                let list = tasks(on: day)
                if list.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 20)).foregroundStyle(Theme.textFaint)
                        Text("Nothing scheduled")
                            .font(Theme.ui(12)).foregroundStyle(Theme.textDim)
                        Text("Drag a task onto this day, or add one below.")
                            .font(Theme.ui(11)).foregroundStyle(Theme.textFaint)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    // The panel is narrow, so use the compact card rather than the full row.
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 6) {
                            ForEach(list) { BoardCard(item: $0) }
                        }
                    }
                }

                Spacer()
                DayQuickAdd(day: day)
            }
        }
        .padding(13)
        .frame(width: 300)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous)
            .fill(Theme.stroke.opacity(0.4)))
    }
}

// MARK: - One day in the grid

struct DayCell: View {
    @EnvironmentObject var store: AppStore
    var day: Date
    var inMonth: Bool
    var items: [Item]
    var selected: Bool
    var onTap: () -> Void

    @State private var hover = false
    @State private var targeted = false

    private var isToday: Bool { Calendar.current.isDateInToday(day) }
    private var hasOverdue: Bool { items.contains { $0.isOverdue } }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text("\(Calendar.current.component(.day, from: day))")
                    .font(Theme.display(12, isToday ? .bold : .medium))
                    .foregroundStyle(isToday ? .white : (inMonth ? Theme.text : Theme.textFaint.opacity(0.6)))
                    .frame(width: 19, height: 19)
                    .background(
                        Circle().fill(isToday ? Theme.accent : .clear)
                    )
                Spacer(minLength: 0)
                if items.count > 3 {
                    Text("+\(items.count - 3)")
                        .font(Theme.ui(9, .bold))
                        .foregroundStyle(Theme.textFaint)
                }
            }

            VStack(alignment: .leading, spacing: 2.5) {
                ForEach(items.prefix(3)) { item in
                    let tint = store.project(item.projectID)?.color ?? Theme.accent
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(item.isDone ? Theme.textFaint : tint)
                            .frame(width: 2.5, height: 9)
                        Text(item.title)
                            .font(Theme.ui(9.5, .medium))
                            .foregroundStyle(item.isDone ? Theme.textFaint : Theme.textDim)
                            .strikethrough(item.isDone, color: Theme.textFaint)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 3).padding(.vertical, 1.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 3.5).fill(tint.opacity(item.isDone ? 0.06 : 0.13)))
                    .draggable(item.id.uuidString)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(5)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(targeted ? Theme.accent.opacity(0.14)
                      : (selected ? Theme.raised : (hover ? Theme.surfaceHi : Theme.surface.opacity(inMonth ? 1 : 0.4))))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(targeted ? Theme.accent
                              : (selected ? Theme.accent.opacity(0.55)
                                 : (hasOverdue ? Theme.red.opacity(0.35) : Theme.stroke)),
                              lineWidth: selected || targeted ? 1.5 : 1)
        )
        .onHoverSpring { hover = $0 }
        .onTapGesture(perform: onTap)
        .dropDestination(for: String.self) { ids, _ in
            let cal = Calendar.current
            for raw in ids {
                guard let id = UUID(uuidString: raw) else { continue }
                store.edit(id) { t in
                    // Keep the time of day, move the date; keep the span length if it has a start.
                    let oldDue = t.due
                    let hour = oldDue.map { cal.component(.hour, from: $0) } ?? 18
                    let minute = oldDue.map { cal.component(.minute, from: $0) } ?? 0
                    let newDue = cal.date(bySettingHour: hour, minute: minute, second: 0, of: day)
                    if let s = t.start, let od = oldDue, let nd = newDue {
                        let delta = cal.dateComponents([.day], from: od, to: nd).day ?? 0
                        t.start = cal.date(byAdding: .day, value: delta, to: s)
                    }
                    t.due = newDue
                }
            }
            return true
        } isTargeted: { on in
            withAnimation(Theme.quick) { targeted = on }
        }
    }
}

// MARK: - Quick add straight onto a day

struct DayQuickAdd: View {
    @EnvironmentObject var store: AppStore
    var day: Date
    @State private var text = ""

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 12)).foregroundStyle(Theme.accent)
            TextField("Add to this day", text: $text)
                .textFieldStyle(.plain)
                .font(Theme.ui(12))
                .onSubmit(commit)
        }
        .padding(.horizontal, 9).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
    }

    private func commit() {
        let raw = text.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return }
        let parsed = QuickParser.parse(raw)
        let cal = Calendar.current
        var item = Item(projectID: projectID, title: parsed.title.isEmpty ? raw : parsed.title)
        item.priority = parsed.priority
        item.tagIDs = parsed.tagNames.map { store.tagNamed($0).id }
        // The day you clicked wins; a time in the text is respected.
        let hour = parsed.due.map { cal.component(.hour, from: $0) } ?? 18
        let minute = parsed.due.map { cal.component(.minute, from: $0) } ?? 0
        item.due = cal.date(bySettingHour: hour, minute: minute, second: 0, of: day)
        store.add(item)
        text = ""
    }

    private var projectID: UUID? {
        if case .project(let id) = store.route { return id }
        return nil
    }
}
