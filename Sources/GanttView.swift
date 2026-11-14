import SwiftUI

// MARK: - Row model

private enum GanttRow: Identifiable {
    case group(Project?, Int)        // project (nil = no project), open count
    case task(Item)

    var id: String {
        switch self {
        case .group(let p, _): return "g-" + (p?.id.uuidString ?? "none")
        case .task(let t): return "t-" + t.id.uuidString
        }
    }
    var height: CGFloat {
        switch self {
        case .group: return 27
        case .task: return 34
        }
    }
}

struct GanttView: View {
    @EnvironmentObject var store: AppStore
    var items: [Item]

    @State private var dayWidth: CGFloat = 30
    @State private var dragDelta: [UUID: Int] = [:]          // live preview while dragging
    @State private var resizeDelta: [UUID: (Int, Int)] = [:]  // (startDays, dueDays)

    private let cal = Calendar.current
    private let nameWidth: CGFloat = 212
    private let headerHeight: CGFloat = 46

    // MARK: Timeline bounds

    private var bounds: (start: Date, days: Int) {
        let spans = items.map { $0.span }
        let today = cal.startOfDay(for: Date())
        var lo = spans.map { cal.startOfDay(for: $0.start) }.min() ?? today
        var hi = spans.map { cal.startOfDay(for: $0.end) }.max() ?? today
        lo = min(lo, today)
        hi = max(hi, today)
        lo = cal.date(byAdding: .day, value: -4, to: lo) ?? lo
        hi = cal.date(byAdding: .day, value: 8, to: hi) ?? hi
        let days = max(32, DateFmt.days(from: lo, to: hi) + 1)
        return (lo, days)
    }

    private var rows: [GanttRow] {
        var out: [GanttRow] = []
        // Keep projects in sidebar order; unassigned last.
        var buckets: [(Project?, [Item])] = store.projects.map { p in
            (p, items.filter { $0.projectID == p.id })
        }
        let orphans = items.filter { $0.projectID == nil || store.project($0.projectID) == nil }
        if !orphans.isEmpty { buckets.append((nil, orphans)) }

        for (p, list) in buckets where !list.isEmpty {
            let sorted = list.sorted { $0.span.start < $1.span.start }
            out.append(.group(p, list.filter { !$0.isDone }.count))
            out.append(contentsOf: sorted.map { GanttRow.task($0) })
        }
        return out
    }

    private var contentWidth: CGFloat { CGFloat(bounds.days) * dayWidth }
    private var bodyHeight: CGFloat { rows.reduce(0) { $0 + $1.height } }

    // MARK: Geometry helpers

    private func x(for date: Date) -> CGFloat {
        CGFloat(DateFmt.days(from: bounds.start, to: date)) * dayWidth
    }

    /// Bar rect for a task, including any live drag/resize preview.
    private func rect(for item: Item, y: CGFloat) -> CGRect {
        let span = item.span
        // Events sit on one day, so they get a milestone marker rather than a bar.
        if item.category.isMilestone {
            let day = DateFmt.days(from: bounds.start, to: item.due ?? span.end)
                + (dragDelta[item.id] ?? 0)
            return CGRect(x: CGFloat(day) * dayWidth + 2, y: y + 7,
                          width: max(16, dayWidth - 4), height: 20)
        }
        var startDay = DateFmt.days(from: bounds.start, to: span.start)
        var endDay = DateFmt.days(from: bounds.start, to: span.end)
        if let d = dragDelta[item.id] { startDay += d; endDay += d }
        if let (ds, de) = resizeDelta[item.id] { startDay += ds; endDay += de }
        if endDay < startDay { endDay = startDay }
        let w = CGFloat(endDay - startDay + 1) * dayWidth
        return CGRect(x: CGFloat(startDay) * dayWidth + 2, y: y + 7,
                      width: max(dayWidth - 4, w - 4), height: 20)
    }

    private var rowOffsets: [String: CGFloat] {
        var out: [String: CGFloat] = [:]
        var y: CGFloat = 0
        for r in rows { out[r.id] = y; y += r.height }
        return out
    }

    var body: some View {
        VStack(spacing: 10) {
            toolbar
            if items.isEmpty {
                EmptyState(icon: "chart.bar.xaxis", title: "Nothing to plot",
                           message: "Give a task a start and a due date and it shows up here as a bar.")
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 0) {
                        nameColumn
                        ScrollView(.horizontal, showsIndicators: true) {
                            VStack(alignment: .leading, spacing: 0) {
                                dateHeader
                                timelineBody
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textFaint)
                Slider(value: $dayWidth, in: 14...62)
                    .frame(width: 110)
                    .controlSize(.mini)
            }
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.stroke.opacity(0.6)))

            Spacer()

            HStack(spacing: 12) {
                legend(color: Theme.accent, label: "Planned")
                legend(color: Theme.green, label: "Progress")
                HStack(spacing: 4) {
                    Rectangle().fill(Theme.pink).frame(width: 8, height: 8)
                        .rotationEffect(.degrees(45))
                    Text("Event").font(Theme.ui(10.5, .medium)).foregroundStyle(Theme.textDim)
                }
                HStack(spacing: 4) {
                    Rectangle().fill(Theme.red).frame(width: 1.6, height: 11)
                    Text("Today").font(Theme.ui(10.5, .medium)).foregroundStyle(Theme.textDim)
                }
                HStack(spacing: 4) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.violet)
                    Text("Depends on").font(Theme.ui(10.5, .medium)).foregroundStyle(Theme.textDim)
                }
            }
        }
    }

    private func legend(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 14, height: 7)
            Text(label).font(Theme.ui(10.5, .medium)).foregroundStyle(Theme.textDim)
        }
    }

    // MARK: Left names

    private var nameColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Spacer matching the date header.
            Text("TASK")
                .font(Theme.ui(10, .bold)).tracking(0.7)
                .foregroundStyle(Theme.textFaint)
                .frame(height: headerHeight, alignment: .bottomLeading)
                .padding(.bottom, 6)

            ForEach(rows) { row in
                switch row {
                case .group(let p, let open):
                    HStack(spacing: 6) {
                        ProjectGlyph(project: p, size: 16)
                        Text(p?.name ?? "No project")
                            .font(Theme.ui(11.5, .bold))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        if open > 0 {
                            Text("\(open)")
                                .font(Theme.ui(9.5, .bold))
                                .padding(.horizontal, 4).padding(.vertical, 0.5)
                                .background(Capsule().fill(Theme.stroke))
                                .foregroundStyle(Theme.textFaint)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(height: row.height, alignment: .bottom)
                    .padding(.bottom, 3)

                case .task(let item):
                    GanttName(item: item)
                        .frame(height: row.height)
                }
            }
        }
        .frame(width: nameWidth, alignment: .leading)
        .padding(.trailing, 10)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Theme.stroke).frame(width: 1)
        }
    }

    // MARK: Date header

    private var dateHeader: some View {
        let days = (0..<bounds.days).compactMap { cal.date(byAdding: .day, value: $0, to: bounds.start) }
        return VStack(alignment: .leading, spacing: 2) {
            // Month strip
            HStack(spacing: 0) {
                ForEach(monthRuns(days), id: \.0) { run in
                    Text(DateFmt.monthYear.string(from: run.1).uppercased())
                        .font(Theme.ui(9.5, .bold)).tracking(0.7)
                        .foregroundStyle(Theme.textFaint)
                        .frame(width: CGFloat(run.2) * dayWidth, alignment: .leading)
                        .padding(.leading, 3)
                }
            }
            .frame(height: 14)

            // Day strip
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { d in
                    let isToday = cal.isDateInToday(d)
                    let weekend = cal.isDateInWeekend(d)
                    VStack(spacing: 0) {
                        if dayWidth >= 26 {
                            Text(DateFmt.weekdayShort.string(from: d).prefix(1))
                                .font(Theme.ui(8.5, .medium))
                                .foregroundStyle(Theme.textFaint)
                        }
                        Text("\(cal.component(.day, from: d))")
                            .font(Theme.ui(dayWidth >= 22 ? 10 : 8.5, isToday ? .bold : .medium))
                            .foregroundStyle(isToday ? .white : (weekend ? Theme.textFaint : Theme.textDim))
                            .frame(width: 17, height: 16)
                            .background(Circle().fill(isToday ? Theme.red : .clear))
                    }
                    .frame(width: dayWidth)
                }
            }
            .frame(height: 28)
        }
        .frame(width: contentWidth, alignment: .leading)
        .padding(.bottom, 6)
    }

    private func monthRuns(_ days: [Date]) -> [(String, Date, Int)] {
        var out: [(String, Date, Int)] = []
        for d in days {
            let key = DateFmt.monthYear.string(from: d)
            if let last = out.last, last.0 == key {
                out[out.count - 1].2 += 1
            } else {
                out.append((key, d, 1))
            }
        }
        return out
    }

    // MARK: Timeline body

    private var timelineBody: some View {
        let offsets = rowOffsets
        var barRects: [UUID: CGRect] = [:]
        for row in rows {
            if case .task(let item) = row, let y = offsets[row.id] {
                barRects[item.id] = rect(for: item, y: y)
            }
        }

        return ZStack(alignment: .topLeading) {
            grid
            dependencyLayer(barRects)
            ForEach(rows) { row in
                if case .task(let item) = row, let y = offsets[row.id] {
                    GanttBar(item: item,
                             rect: rect(for: item, y: y),
                             dayWidth: dayWidth,
                             tint: store.project(item.projectID)?.color ?? Theme.accent,
                             onDrag: { d in dragDelta[item.id] = d },
                             onDragEnd: { d in
                                 commitShift(item, days: d)
                                 dragDelta[item.id] = nil
                             },
                             onResize: { s, e in resizeDelta[item.id] = (s, e) },
                             onResizeEnd: { s, e in
                                 commitResize(item, startDays: s, dueDays: e)
                                 resizeDelta[item.id] = nil
                             })
                    .environmentObject(store)
                }
            }
        }
        .frame(width: contentWidth, height: bodyHeight, alignment: .topLeading)
    }

    private var grid: some View {
        Canvas { ctx, size in
            // Weekend shading + day lines
            for i in 0..<bounds.days {
                guard let d = cal.date(byAdding: .day, value: i, to: bounds.start) else { continue }
                let xx = CGFloat(i) * dayWidth
                if cal.isDateInWeekend(d) {
                    ctx.fill(Path(CGRect(x: xx, y: 0, width: dayWidth, height: size.height)),
                             with: .color(Color.gray.opacity(0.055)))
                }
                var line = Path()
                line.move(to: CGPoint(x: xx, y: 0))
                line.addLine(to: CGPoint(x: xx, y: size.height))
                ctx.stroke(line, with: .color(Color.gray.opacity(0.1)), lineWidth: 0.5)
            }
            // Row separators
            var y: CGFloat = 0
            for r in rows {
                y += r.height
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(line, with: .color(Color.gray.opacity(0.08)), lineWidth: 0.5)
            }
            // Today
            let todayX = x(for: cal.startOfDay(for: Date())) + dayWidth / 2
            var tl = Path()
            tl.move(to: CGPoint(x: todayX, y: 0))
            tl.addLine(to: CGPoint(x: todayX, y: size.height))
            ctx.stroke(tl, with: .color(Theme.red.opacity(0.75)),
                       style: StrokeStyle(lineWidth: 1.4, dash: [3, 3]))
        }
    }

    /// Curved arrows from each prerequisite to the task that depends on it.
    private func dependencyLayer(_ rects: [UUID: CGRect]) -> some View {
        Canvas { ctx, _ in
            for row in rows {
                guard case .task(let item) = row, let to = rects[item.id] else { continue }
                for dep in item.dependsOn {
                    guard let from = rects[dep] else { continue }
                    let startP = CGPoint(x: from.maxX, y: from.midY)
                    let endP = CGPoint(x: to.minX - 5, y: to.midY)
                    var p = Path()
                    p.move(to: startP)
                    let midX = max(startP.x + 10, endP.x - 12)
                    p.addCurve(to: endP,
                               control1: CGPoint(x: midX, y: startP.y),
                               control2: CGPoint(x: midX, y: endP.y))
                    let late = from.maxX > to.minX      // prerequisite finishes after this starts
                    let colour = late ? Theme.red.opacity(0.8) : Theme.violet.opacity(0.75)
                    ctx.stroke(p, with: .color(colour),
                               style: StrokeStyle(lineWidth: 1.4, lineCap: .round,
                                                  dash: late ? [3, 2] : []))
                    // Arrowhead
                    var head = Path()
                    head.move(to: CGPoint(x: endP.x + 5, y: endP.y))
                    head.addLine(to: CGPoint(x: endP.x - 1, y: endP.y - 3.4))
                    head.addLine(to: CGPoint(x: endP.x - 1, y: endP.y + 3.4))
                    head.closeSubpath()
                    ctx.fill(head, with: .color(colour))
                }
            }
        }
    }

    // MARK: Commits

    private func commitShift(_ item: Item, days: Int) {
        guard days != 0 else { return }
        let span = item.span
        // An event has no span — moving it moves only its date.
        if item.category.isMilestone {
            store.edit(item.id) { t in
                t.due = cal.date(byAdding: .day, value: days, to: t.due ?? span.end)
            }
            return
        }
        store.edit(item.id) { t in
            t.start = cal.date(byAdding: .day, value: days, to: t.start ?? span.start)
            t.due = cal.date(byAdding: .day, value: days, to: t.due ?? span.end)
        }
    }

    private func commitResize(_ item: Item, startDays: Int, dueDays: Int) {
        guard startDays != 0 || dueDays != 0 else { return }
        let span = item.span
        store.edit(item.id) { t in
            if startDays != 0 {
                t.start = cal.date(byAdding: .day, value: startDays, to: t.start ?? span.start)
            }
            if dueDays != 0 {
                let base = t.due ?? span.end
                let moved = cal.date(byAdding: .day, value: dueDays, to: base) ?? base
                // Preserve the time of day on the due date.
                t.due = moved
            }
        }
    }
}

// MARK: - Task name in the left column

private struct GanttName: View {
    @EnvironmentObject var store: AppStore
    var item: Item
    @State private var hover = false

    var body: some View {
        HStack(spacing: 6) {
            Checkbox(done: item.isDone,
                     tint: store.project(item.projectID)?.color ?? Theme.accent,
                     size: 14) { store.toggleDone(item.id) }
            Text(item.title)
                .font(Theme.ui(11.5, .medium))
                .foregroundStyle(item.isDone ? Theme.textFaint : Theme.text)
                .strikethrough(item.isDone, color: Theme.textFaint)
                .lineLimit(1)
            if store.isBlocked(item) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.red)
            }
            Spacer(minLength: 0)
            if let s = item.checkpointSummary {
                Text(s).font(Theme.mono(9, .semibold)).foregroundStyle(Theme.textFaint)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .background(hover ? Theme.stroke.opacity(0.5) : .clear)
        .onHoverSpring { hover = $0 }
        .onTapGesture { store.selectedTaskID = item.id }
    }
}

// MARK: - A draggable, resizable bar

private struct GanttBar: View {
    @EnvironmentObject var store: AppStore
    var item: Item
    var rect: CGRect
    var dayWidth: CGFloat
    var tint: Color
    var onDrag: (Int) -> Void
    var onDragEnd: (Int) -> Void
    var onResize: (Int, Int) -> Void
    var onResizeEnd: (Int, Int) -> Void

    @State private var hover = false
    @State private var dragging = false

    private var overdue: Bool { item.isOverdue }

    var body: some View {
        if item.category.isMilestone { milestone } else { bar }
    }

    /// A one-day event: a diamond on its date, with the name beside it.
    private var milestone: some View {
        HStack(spacing: 5) {
            Rectangle()
                .fill(item.isDone ? Theme.textFaint : Theme.pink)
                .frame(width: 11, height: 11)
                .rotationEffect(.degrees(45))
                .overlay(
                    Rectangle()
                        .strokeBorder(.white.opacity(hover ? 0.9 : 0.35), lineWidth: 1)
                        .frame(width: 11, height: 11)
                        .rotationEffect(.degrees(45))
                )
                .shadow(color: Theme.pink.opacity(hover ? 0.6 : 0.25), radius: hover ? 7 : 3)
            Text(item.title)
                .font(Theme.ui(9.5, .semibold))
                .foregroundStyle(Theme.textDim)
                .lineLimit(1)
                .fixedSize()
        }
        .frame(width: rect.width, height: rect.height, alignment: .leading)
        .offset(x: rect.minX, y: rect.minY)
        .opacity(item.isDone ? 0.55 : 1)
        .onHoverSpring { hover = $0 }
        .help(tooltip)
        .gesture(
            DragGesture(minimumDistance: 3)
                .onChanged { v in onDrag(Int((v.translation.width / dayWidth).rounded())) }
                .onEnded { v in onDragEnd(Int((v.translation.width / dayWidth).rounded())) }
        )
        .onTapGesture { store.selectedTaskID = item.id }
    }

    private var bar: some View {
        ZStack(alignment: .leading) {
            // Track
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(LinearGradient(colors: [tint.opacity(0.34), tint.opacity(0.22)],
                                     startPoint: .top, endPoint: .bottom))

            // Progress
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LinearGradient(colors: [tint, tint.opacity(0.82)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: max(0, geo.size.width * item.progress))
            }

            HStack(spacing: 4) {
                if rect.width > 54 {
                    Text(item.title)
                        .font(Theme.ui(10, .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .padding(.leading, 6)
                }
                Spacer(minLength: 0)
                if overdue && rect.width > 34 {
                    Image(systemName: "exclamationmark")
                        .font(.system(size: 8.5, weight: .black))
                        .foregroundStyle(Theme.red)
                        .padding(.trailing, 5)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(overdue ? Theme.red.opacity(0.85)
                              : (hover || dragging ? tint : tint.opacity(0.45)),
                              lineWidth: hover || dragging ? 1.6 : 1)
        )
        .shadow(color: tint.opacity(dragging ? 0.5 : (hover ? 0.3 : 0)), radius: dragging ? 9 : 5, y: 2)
        // Resize handles
        .overlay(alignment: .leading) { handle(leading: true) }
        .overlay(alignment: .trailing) { handle(leading: false) }
        .frame(width: rect.width, height: rect.height)
        .offset(x: rect.minX, y: rect.minY)
        .opacity(item.isDone ? 0.55 : 1)
        .scaleEffect(y: dragging ? 1.12 : 1)
        .onHoverSpring { hover = $0 }
        .help(tooltip)
        .gesture(
            DragGesture(minimumDistance: 3)
                .onChanged { v in
                    dragging = true
                    onDrag(Int((v.translation.width / dayWidth).rounded()))
                }
                .onEnded { v in
                    dragging = false
                    onDragEnd(Int((v.translation.width / dayWidth).rounded()))
                }
        )
        .onTapGesture { store.selectedTaskID = item.id }
    }

    private func handle(leading: Bool) -> some View {
        Rectangle()
            .fill(Color.white.opacity(hover ? 0.22 : 0.001))
            .frame(width: 6)
            .overlay(
                Capsule().fill(.white.opacity(hover ? 0.75 : 0))
                    .frame(width: 2, height: 9)
            )
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { v in
                        let d = Int((v.translation.width / dayWidth).rounded())
                        leading ? onResize(d, 0) : onResize(0, d)
                    }
                    .onEnded { v in
                        let d = Int((v.translation.width / dayWidth).rounded())
                        leading ? onResizeEnd(d, 0) : onResizeEnd(0, d)
                    }
            )
    }

    private var tooltip: String {
        let s = item.span
        var parts = ["\(DateFmt.dayMonth.string(from: s.start)) → \(DateFmt.dayMonth.string(from: s.end))"]
        if let sum = item.checkpointSummary { parts.append("\(sum) checkpoints") }
        if item.progress > 0 { parts.append("\(Int(item.progress * 100))% done") }
        if store.isBlocked(item) { parts.append("blocked by another task") }
        return item.title + "\n" + parts.joined(separator: " · ")
    }
}
