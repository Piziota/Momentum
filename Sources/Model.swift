import Foundation
import SwiftUI

// MARK: - Enums

enum Priority: Int, Codable, CaseIterable, Identifiable {
    case none = 0, low = 1, medium = 2, high = 3

    var id: Int { rawValue }
    var label: String {
        switch self {
        case .none: return "No priority"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
    var short: String {
        switch self {
        case .none: return "—"
        case .low: return "P3"
        case .medium: return "P2"
        case .high: return "P1"
        }
    }
    var tint: Color {
        switch self {
        case .none: return Theme.textFaint
        case .low: return Theme.blue
        case .medium: return Theme.amber
        case .high: return Theme.red
        }
    }
}

enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case backlog, active, blocked, done

    var id: String { rawValue }
    var label: String {
        switch self {
        case .backlog: return "Backlog"
        case .active: return "In progress"
        case .blocked: return "Blocked"
        case .done: return "Done"
        }
    }
    var icon: String {
        switch self {
        case .backlog: return "tray"
        case .active: return "bolt.fill"
        case .blocked: return "exclamationmark.triangle.fill"
        case .done: return "checkmark.circle.fill"
        }
    }
    var tint: Color {
        switch self {
        case .backlog: return Theme.textFaint
        case .active: return Theme.blue
        case .blocked: return Theme.red
        case .done: return Theme.green
        }
    }
}

/// What kind of thing this is. Chosen when the task is created, because
/// a multi-step project, something you're learning and a one-day event
/// want to be treated differently.
enum ItemKind: String, Codable, CaseIterable, Identifiable {
    case project      // multi-step work with a span and checkpoints
    case learning     // ongoing, no deadline pressure
    case event        // happens on one day, at a time
    case task         // a plain one-off

    var id: String { rawValue }

    var label: String {
        switch self {
        case .project: return "Project"
        case .learning: return "Learning"
        case .event: return "Event"
        case .task: return "Task"
        }
    }
    var blurb: String {
        switch self {
        case .project: return "Multi-step, over days"
        case .learning: return "Ongoing, no deadline"
        case .event: return "Happens on one day"
        case .task: return "A single thing to do"
        }
    }
    var icon: String {
        switch self {
        case .project: return "square.stack.3d.up.fill"
        case .learning: return "book.fill"
        case .event: return "calendar.badge.clock"
        case .task: return "checkmark.circle"
        }
    }
    var tint: Color {
        switch self {
        case .project: return Theme.accent
        case .learning: return Theme.teal
        case .event: return Theme.pink
        case .task: return Theme.textDim
        }
    }
    /// Events sit at a single point in time, so the timeline draws them as a milestone.
    var isMilestone: Bool { self == .event }
}

enum FieldKind: String, Codable, CaseIterable, Identifiable {
    case text, number, url, date, select

    var id: String { rawValue }
    var label: String {
        switch self {
        case .text: return "Text"
        case .number: return "Number"
        case .url: return "Link"
        case .date: return "Date"
        case .select: return "Dropdown"
        }
    }
    var icon: String {
        switch self {
        case .text: return "textformat"
        case .number: return "number"
        case .url: return "link"
        case .date: return "calendar"
        case .select: return "chevron.down.square"
        }
    }
}

// MARK: - Leaf models

struct Tag: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var colorHex: String
    var color: Color { Color(hex: colorHex) }
}

struct Checkpoint: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var done: Bool = false
    var due: Date? = nil
    var completedAt: Date? = nil
}

struct Page: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String = "Untitled page"
    var body: String = ""
    var updatedAt: Date = Date()
}

struct FieldDef: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var kind: FieldKind
    var options: [String] = []
}

struct Project: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var colorHex: String
    var icon: String = "folder.fill"
    var fields: [FieldDef] = []
    var archived: Bool = false
    var color: Color { Color(hex: colorHex) }
}

struct Item: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var projectID: UUID?
    var title: String
    /// Optional so stores written before categories existed still decode.
    var kind: ItemKind? = nil
    var notes: String = ""
    var status: TaskStatus = .backlog
    var priority: Priority = .none
    var start: Date? = nil
    var due: Date? = nil
    var tagIDs: [UUID] = []
    var checkpoints: [Checkpoint] = []
    var pages: [Page] = []
    var values: [String: String] = [:]      // FieldDef.id.uuidString -> raw value
    var dependsOn: [UUID] = []
    var estimateHours: Double? = nil
    var createdAt: Date = Date()
    var completedAt: Date? = nil

    // MARK: Derived

    var isDone: Bool { status == .done }

    /// The category, falling back for anything created before categories existed.
    var category: ItemKind {
        if let kind { return kind }
        if !checkpoints.isEmpty || start != nil { return .project }
        return .task
    }

    var progress: Double {
        guard !checkpoints.isEmpty else { return isDone ? 1 : 0 }
        let done = checkpoints.filter { $0.done }.count
        return Double(done) / Double(checkpoints.count)
    }

    var checkpointSummary: String? {
        guard !checkpoints.isEmpty else { return nil }
        return "\(checkpoints.filter { $0.done }.count)/\(checkpoints.count)"
    }

    /// Timeline span used by the Gantt chart. Always returns something sensible.
    var span: (start: Date, end: Date) {
        let cal = Calendar.current
        if let s = start, let d = due { return (min(s, d), max(s, d)) }
        if let d = due { return (cal.startOfDay(for: d), d) }
        if let s = start { return (s, cal.date(byAdding: .day, value: 1, to: s) ?? s) }
        let today = cal.startOfDay(for: Date())
        return (today, cal.date(byAdding: .day, value: 1, to: today) ?? today)
    }

    var isOverdue: Bool {
        guard let due, !isDone else { return false }
        return due < Date()
    }

    var dueDayOffset: Int? {
        guard let due else { return nil }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: due)).day
    }

    /// The next thing to actually do — surfaces the earliest unfinished checkpoint.
    var nextCheckpoint: Checkpoint? {
        checkpoints.first { !$0.done }
    }
}

// MARK: - Routing

enum Route: Hashable {
    case today
    case upcoming
    case all
    case project(UUID)
    case tag(UUID)
}

enum ViewMode: String, CaseIterable, Identifiable {
    case list, board, calendar, gantt

    var id: String { rawValue }
    var label: String {
        switch self {
        case .list: return "List"
        case .board: return "Board"
        case .calendar: return "Calendar"
        case .gantt: return "Timeline"
        }
    }
    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .board: return "square.grid.3x1.below.line.grid.1x2"
        case .calendar: return "calendar"
        case .gantt: return "chart.bar.xaxis"
        }
    }
}

enum SortKey: String, CaseIterable, Identifiable {
    case due, priority, created, title
    var id: String { rawValue }
    var label: String {
        switch self {
        case .due: return "Due date"
        case .priority: return "Priority"
        case .created: return "Date added"
        case .title: return "Name"
        }
    }
}

// MARK: - Persisted snapshot

struct Snapshot: Codable {
    var version: Int = 1
    var projects: [Project] = []
    var tasks: [Item] = []
    var tags: [Tag] = []
    var seeded: Bool = false
}
