import Foundation
import SwiftUI
import Combine

final class AppStore: ObservableObject {

    // MARK: Data
    @Published var projects: [Project] = []
    @Published var tasks: [Item] = []
    @Published var tags: [Tag] = []

    // MARK: UI state (not persisted beyond defaults)
    @Published var route: Route = .today
    @Published var mode: ViewMode = .list
    @Published var selectedTaskID: UUID? = nil
    @Published var search: String = ""
    @Published var showDone: Bool = false
    @Published var sortKey: SortKey = .due
    @Published var quickAddOpen: Bool = false

    /// Which system-wide capture hotkey is active, and whether it took.
    @Published var hotkeyID: String = UserDefaults.standard.string(forKey: "captureHotkey")
        ?? HotkeyCenter.defaultID
    @Published var hotkeyFailed: Bool = false

    var hotkeyLabel: String { HotkeyCenter.combo(hotkeyID).label }

    func setHotkey(_ id: String) {
        hotkeyID = id
        UserDefaults.standard.set(id, forKey: "captureHotkey")
        hotkeyFailed = !HotkeyCenter.shared.register(id)
    }

    private var seeded = false
    private var saveWork: DispatchWorkItem?
    private var bag = Set<AnyCancellable>()

    // MARK: - Storage location

    static var storeURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Momentum", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("store.json")
    }

    init() {
        load()
        if !seeded {
            seedSampleData()
            seeded = true
            save(now: true)
        }
        applyLaunchOverrides()
        // Any change to the data triggers a debounced write + reminder refresh.
        Publishers.MergeMany(
            $projects.map { _ in () }.eraseToAnyPublisher(),
            $tasks.map { _ in () }.eraseToAnyPublisher(),
            $tags.map { _ in () }.eraseToAnyPublisher()
        )
        .dropFirst(3)
        .sink { [weak self] _ in self?.save() }
        .store(in: &bag)
    }

    /// Lets a launch environment pick the starting view — used for screenshots and testing.
    private func applyLaunchOverrides() {
        let env = ProcessInfo.processInfo.environment
        switch env["MOMENTUM_ROUTE"] {
        case "today": route = .today
        case "upcoming": route = .upcoming
        case "all": route = .all
        default: break
        }
        if let m = env["MOMENTUM_MODE"], let mode = ViewMode(rawValue: m) { self.mode = mode }
        if env["MOMENTUM_SELECT"] == "first" {
            selectedTaskID = sorted(tasks.filter { !$0.isDone }).first?.id
        }
        if env["MOMENTUM_QUICKADD"] == "1" { quickAddOpen = true }
    }

    // MARK: - Persistence

    func load() {
        guard let data = try? Data(contentsOf: Self.storeURL) else { return }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        guard let snap = try? dec.decode(Snapshot.self, from: data) else { return }
        projects = snap.projects
        tasks = snap.tasks
        tags = snap.tags
        seeded = snap.seeded
    }

    func save(now: Bool = false) {
        saveWork?.cancel()
        let snap = Snapshot(version: 1, projects: projects, tasks: tasks, tags: tags, seeded: true)
        let work = DispatchWorkItem { [snap] in
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            enc.dateEncodingStrategy = .iso8601
            guard let data = try? enc.encode(snap) else { return }
            let tmp = Self.storeURL.appendingPathExtension("tmp")
            do {
                try data.write(to: tmp, options: .atomic)
                _ = try? FileManager.default.replaceItemAt(Self.storeURL, withItemAt: tmp)
            } catch {
                try? data.write(to: Self.storeURL, options: .atomic)
            }
        }
        saveWork = work
        if now {
            work.perform()
        } else {
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.6, execute: work)
        }
        Reminders.shared.reschedule(for: tasks, projects: projects)
    }

    // MARK: - Lookups

    func project(_ id: UUID?) -> Project? {
        guard let id else { return nil }
        return projects.first { $0.id == id }
    }
    func tag(_ id: UUID) -> Tag? { tags.first { $0.id == id } }
    func task(_ id: UUID?) -> Item? {
        guard let id else { return nil }
        return tasks.first { $0.id == id }
    }
    var selectedTask: Item? { task(selectedTaskID) }

    func tagsFor(_ item: Item) -> [Tag] { item.tagIDs.compactMap { tag($0) } }

    func openCount(for project: Project) -> Int {
        tasks.filter { $0.projectID == project.id && !$0.isDone }.count
    }

    // MARK: - Derived buckets

    var overdue: [Item] {
        tasks.filter { $0.isOverdue }.sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }
    }
    var dueToday: [Item] {
        tasks.filter { !$0.isDone && ($0.dueDayOffset == 0) }
            .sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }
    }
    var dueSoon: [Item] {            // next 2–7 days
        tasks.filter {
            guard let o = $0.dueDayOffset, !$0.isDone else { return false }
            return o >= 1 && o <= 7
        }.sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }
    }
    var inProgress: [Item] {
        tasks.filter { $0.status == .active && !$0.isDone }
    }
    var noDate: [Item] {
        tasks.filter { $0.due == nil && !$0.isDone }
    }
    var completedToday: [Item] {
        tasks.filter {
            guard let c = $0.completedAt else { return false }
            return Calendar.current.isDateInToday(c)
        }
    }

    /// Checkpoints that are themselves due today or overdue — easy to miss otherwise.
    var liveCheckpoints: [(Item, Checkpoint)] {
        var out: [(Item, Checkpoint)] = []
        for t in tasks where !t.isDone {
            for c in t.checkpoints where !c.done {
                if let d = c.due, DateFmt.days(from: Date(), to: d) <= 0 { out.append((t, c)) }
            }
        }
        return out.sorted { ($0.1.due ?? .distantFuture) < ($1.1.due ?? .distantFuture) }
    }

    // MARK: - The task list for the current route

    func items(for route: Route) -> [Item] {
        var out: [Item]
        switch route {
        case .today:
            out = tasks.filter {
                if $0.isOverdue { return true }
                if let o = $0.dueDayOffset, o == 0 { return true }
                return $0.status == .active
            }
        case .upcoming:
            out = tasks.filter { $0.due != nil }
        case .all:
            out = tasks
        case .project(let id):
            out = tasks.filter { $0.projectID == id }
        case .tag(let id):
            out = tasks.filter { $0.tagIDs.contains(id) }
        }
        if !showDone { out = out.filter { !$0.isDone } }
        if !search.isEmpty {
            let q = search.lowercased()
            out = out.filter {
                $0.title.lowercased().contains(q)
                || $0.notes.lowercased().contains(q)
                || $0.checkpoints.contains { $0.title.lowercased().contains(q) }
                || $0.pages.contains { $0.title.lowercased().contains(q) || $0.body.lowercased().contains(q) }
                || tagsFor($0).contains { $0.name.lowercased().contains(q) }
            }
        }
        return sorted(out)
    }

    func sorted(_ list: [Item]) -> [Item] {
        switch sortKey {
        case .due:
            return list.sorted { a, b in
                if a.isDone != b.isDone { return !a.isDone }
                return (a.due ?? .distantFuture) < (b.due ?? .distantFuture)
            }
        case .priority:
            return list.sorted { a, b in
                if a.priority.rawValue != b.priority.rawValue { return a.priority.rawValue > b.priority.rawValue }
                return (a.due ?? .distantFuture) < (b.due ?? .distantFuture)
            }
        case .created:
            return list.sorted { $0.createdAt > $1.createdAt }
        case .title:
            return list.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    var routeTitle: String {
        switch route {
        case .today: return "Today"
        case .upcoming: return "Upcoming"
        case .all: return "All tasks"
        case .project(let id): return project(id)?.name ?? "Project"
        case .tag(let id): return "#" + (tag(id)?.name ?? "tag")
        }
    }

    var routeTint: Color {
        switch route {
        case .today: return Theme.accent
        case .upcoming: return Theme.blue
        case .all: return Theme.textDim
        case .project(let id): return project(id)?.color ?? Theme.accent
        case .tag(let id): return tag(id)?.color ?? Theme.accent
        }
    }

    // MARK: - Mutations

    func add(_ item: Item) {
        tasks.append(item)
        selectedTaskID = item.id
    }

    func update(_ item: Item) {
        guard let i = tasks.firstIndex(where: { $0.id == item.id }) else { return }
        tasks[i] = item
    }

    /// Mutate a task in place by id.
    func edit(_ id: UUID, _ change: (inout Item) -> Void) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        change(&tasks[i])
    }

    func delete(_ id: UUID) {
        tasks.removeAll { $0.id == id }
        // Drop dangling dependencies.
        for i in tasks.indices { tasks[i].dependsOn.removeAll { $0 == id } }
        if selectedTaskID == id { selectedTaskID = nil }
    }

    func toggleDone(_ id: UUID) {
        edit(id) { t in
            if t.isDone {
                t.status = .backlog
                t.completedAt = nil
            } else {
                t.status = .done
                t.completedAt = Date()
                for i in t.checkpoints.indices where !t.checkpoints[i].done {
                    t.checkpoints[i].done = true
                    t.checkpoints[i].completedAt = Date()
                }
            }
        }
    }

    func toggleCheckpoint(_ taskID: UUID, _ cpID: UUID) {
        edit(taskID) { t in
            guard let i = t.checkpoints.firstIndex(where: { $0.id == cpID }) else { return }
            t.checkpoints[i].done.toggle()
            t.checkpoints[i].completedAt = t.checkpoints[i].done ? Date() : nil
            // Finishing the last checkpoint completes the task; unticking reopens it.
            if t.checkpoints.allSatisfy({ $0.done }) {
                t.status = .done
                t.completedAt = Date()
            } else if t.isDone {
                t.status = .active
                t.completedAt = nil
            } else if t.status == .backlog {
                t.status = .active
            }
        }
    }

    func addCheckpoint(_ taskID: UUID, title: String, due: Date? = nil) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        edit(taskID) { $0.checkpoints.append(Checkpoint(title: title, due: due)) }
    }

    func addPage(_ taskID: UUID, title: String = "Untitled page") -> UUID {
        let p = Page(title: title)
        edit(taskID) { $0.pages.append(p) }
        return p.id
    }

    // Projects

    func addProject(name: String, colorHex: String? = nil, icon: String = "folder.fill") -> Project {
        let used = Set(projects.map { $0.colorHex })
        let hex = colorHex ?? (Theme.palette.first { !used.contains($0) } ?? Theme.palette.randomElement()!)
        let p = Project(name: name, colorHex: hex, icon: icon)
        projects.append(p)
        return p
    }

    func updateProject(_ p: Project) {
        guard let i = projects.firstIndex(where: { $0.id == p.id }) else { return }
        projects[i] = p
    }

    func deleteProject(_ id: UUID) {
        projects.removeAll { $0.id == id }
        for i in tasks.indices where tasks[i].projectID == id { tasks[i].projectID = nil }
        if case .project(let r) = route, r == id { route = .today }
    }

    // Tags

    func tagNamed(_ name: String) -> Tag {
        let clean = name.trimmingCharacters(in: CharacterSet(charactersIn: "# ")).lowercased()
        if let existing = tags.first(where: { $0.name.lowercased() == clean }) { return existing }
        let used = Set(tags.map { $0.colorHex })
        let hex = Theme.palette.first { !used.contains($0) } ?? Theme.palette.randomElement()!
        let t = Tag(name: clean, colorHex: hex)
        tags.append(t)
        return t
    }

    func deleteTag(_ id: UUID) {
        tags.removeAll { $0.id == id }
        for i in tasks.indices { tasks[i].tagIDs.removeAll { $0 == id } }
        if case .tag(let r) = route, r == id { route = .today }
    }

    // Dependencies

    /// Adds a dependency unless it would create a cycle.
    func addDependency(from taskID: UUID, to prerequisite: UUID) -> Bool {
        guard taskID != prerequisite else { return false }
        if reaches(from: prerequisite, to: taskID) { return false }
        edit(taskID) { if !$0.dependsOn.contains(prerequisite) { $0.dependsOn.append(prerequisite) } }
        return true
    }

    private func reaches(from a: UUID, to b: UUID) -> Bool {
        var seen = Set<UUID>()
        var stack = [a]
        while let cur = stack.popLast() {
            if cur == b { return true }
            if !seen.insert(cur).inserted { continue }
            stack.append(contentsOf: task(cur)?.dependsOn ?? [])
        }
        return false
    }

    /// True when some prerequisite is still open.
    func isBlocked(_ item: Item) -> Bool {
        item.dependsOn.contains { task($0)?.isDone == false }
    }

    // MARK: - Stats for the Today header

    var todayTotal: Int { dueToday.count + overdue.count }
    var todayDone: Int { completedToday.count }
    var todayProgress: Double {
        let total = todayTotal + todayDone
        return total == 0 ? 0 : Double(todayDone) / Double(total)
    }

    /// Completions per day for the last 14 days — drives the sparkline.
    var recentActivity: [Int] {
        let cal = Calendar.current
        return (0..<14).reversed().map { back in
            guard let day = cal.date(byAdding: .day, value: -back, to: Date()) else { return 0 }
            return tasks.filter { c in
                guard let d = c.completedAt else { return false }
                return cal.isDate(d, inSameDayAs: day)
            }.count
        }
    }

    var streak: Int {
        let cal = Calendar.current
        var n = 0
        var day = Date()
        while true {
            let any = tasks.contains { t in
                guard let d = t.completedAt else { return false }
                return cal.isDate(d, inSameDayAs: day)
            }
            if any { n += 1 } else if n > 0 || !cal.isDateInToday(day) { break }
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
            if n > 400 { break }
        }
        return n
    }

    // MARK: - Sample data

    func clearSampleData() {
        tasks.removeAll()
        projects.removeAll()
        tags.removeAll()
        save(now: true)
    }

    private func seedSampleData() {
        let cal = Calendar.current
        func day(_ n: Int, hour: Int = 18) -> Date {
            let d = cal.date(byAdding: .day, value: n, to: Date()) ?? Date()
            return cal.date(bySettingHour: hour, minute: 0, second: 0, of: d) ?? d
        }

        let work = addProject(name: "Job applications", colorHex: "#6C7BFF", icon: "briefcase.fill")
        let build = addProject(name: "Finaustria", colorHex: "#2DD4BF", icon: "chart.line.uptrend.xyaxis")
        let life = addProject(name: "Personal", colorHex: "#FFB020", icon: "house.fill")

        let urgent = tagNamed("urgent")
        let waiting = tagNamed("waiting")
        let deep = tagNamed("deep-work")

        var a = Item(projectID: work.id,
                     title: "Finish and send the Erste application",
                     kind: .project,
                     notes: "Tailor the CV to the job description, then submit through their portal.",
                     status: .active, priority: .high,
                     start: day(-2, hour: 9), due: day(1, hour: 17),
                     tagIDs: [urgent.id])
        a.checkpoints = [
            Checkpoint(title: "Rewrite the CV summary", done: true, completedAt: day(-1)),
            Checkpoint(title: "Write the cover letter", done: true, completedAt: Date()),
            Checkpoint(title: "Proofread both", due: day(0, hour: 20)),
            Checkpoint(title: "Submit on the portal", due: day(1, hour: 17))
        ]
        a.pages = [Page(title: "Job description notes",
                        body: "# Erste — Data Analyst\n\n**What they want**\n- SQL, dashboards, stakeholder work\n- German B2 helpful, not required\n\n**My angle**\nFinaustria shows I can take a product from idea to live data.\n\n**Questions to ask**\n1. How big is the data team?\n2. What does the first 90 days look like?")]
        a.estimateHours = 4

        var b = Item(projectID: work.id,
                     title: "Follow up with the recruiter at Raiffeisen",
                     kind: .task,
                     status: .backlog, priority: .medium,
                     start: day(0), due: day(0, hour: 11),
                     tagIDs: [waiting.id])
        b.checkpoints = [Checkpoint(title: "Draft the follow-up email")]

        var c = Item(projectID: build.id,
                     title: "Ship the pricing page",
                     kind: .project,
                     notes: "Three tiers, annual toggle, and the FAQ block underneath.",
                     status: .active, priority: .high,
                     start: day(-5, hour: 10), due: day(4, hour: 18),
                     tagIDs: [deep.id])
        c.checkpoints = [
            Checkpoint(title: "Copy for the three tiers", done: true, completedAt: day(-3)),
            Checkpoint(title: "Build the layout", done: true, completedAt: day(-1)),
            Checkpoint(title: "Wire up the annual toggle", due: day(2, hour: 18)),
            Checkpoint(title: "Mobile pass", due: day(3, hour: 18)),
            Checkpoint(title: "Deploy", due: day(4, hour: 18))
        ]
        c.estimateHours = 12

        var d = Item(projectID: build.id,
                     title: "Set up the analytics events",
                     kind: .project,
                     status: .backlog, priority: .medium,
                     start: day(4), due: day(9, hour: 18))
        d.dependsOn = [c.id]
        d.checkpoints = [
            Checkpoint(title: "List the events worth tracking"),
            Checkpoint(title: "Add them to the signup flow"),
            Checkpoint(title: "Build the funnel dashboard")
        ]

        var e = Item(projectID: build.id,
                     title: "Write the launch post",
                     kind: .task,
                     status: .backlog, priority: .low,
                     start: day(9), due: day(14, hour: 12))
        e.dependsOn = [d.id]

        var f = Item(projectID: life.id,
                     title: "Renew the residence permit",
                     kind: .project,
                     notes: "Appointment booking opens 60 days before expiry.",
                     status: .backlog, priority: .high,
                     due: day(-1, hour: 12),
                     tagIDs: [urgent.id])
        f.checkpoints = [
            Checkpoint(title: "Collect the documents", done: true, completedAt: day(-4)),
            Checkpoint(title: "Book the appointment", due: day(-1, hour: 12))
        ]

        let g = Item(projectID: life.id, title: "Dentist, 2pm", kind: .event, status: .backlog,
                     priority: .none, due: day(3, hour: 14))

        var h = Item(projectID: life.id, title: "Read 30 pages of the SwiftUI book", kind: .learning,
                     status: .active, priority: .low, due: nil, tagIDs: [deep.id])
        h.checkpoints = [Checkpoint(title: "Chapter 4"), Checkpoint(title: "Chapter 5")]

        var done = Item(projectID: work.id, title: "Update the LinkedIn headline", kind: .task,
                        status: .done, priority: .low, due: day(-1))
        done.completedAt = Date()

        tasks = [a, b, c, d, e, f, g, h, done]

        // A couple of custom fields, so the Info tab has something real in it.
        if let i = projects.firstIndex(where: { $0.id == work.id }) {
            projects[i].fields = [
                FieldDef(name: "Company", kind: .text),
                FieldDef(name: "Job link", kind: .url),
                FieldDef(name: "Salary", kind: .number),
                FieldDef(name: "Stage", kind: .select,
                         options: ["Not applied", "Applied", "Screening", "Interview", "Offer", "Rejected"])
            ]
        }
        if let i = tasks.firstIndex(where: { $0.id == a.id }),
           let work2 = projects.first(where: { $0.id == work.id }) {
            for f in work2.fields {
                switch f.name {
                case "Company":  tasks[i].values[f.id.uuidString] = "Erste Group"
                case "Job link": tasks[i].values[f.id.uuidString] = "https://erstegroup.com/careers"
                case "Stage":    tasks[i].values[f.id.uuidString] = "Applied"
                default: break
                }
            }
        }
    }
}
