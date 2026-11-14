import Foundation
import UserNotifications
import AppKit

/// Schedules the local notifications that stop things being missed:
/// the evening before, the morning of, and an hour before a timed deadline.
final class Reminders: NSObject, UNUserNotificationCenterDelegate {

    static let shared = Reminders()
    private var authorised = false
    private var pendingReschedule: DispatchWorkItem?

    /// UNUserNotificationCenter traps when there is no bundle identifier
    /// (e.g. the binary run directly rather than through the .app).
    private var available: Bool { Bundle.main.bundleIdentifier != nil }

    func start() {
        guard available else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] ok, _ in
            DispatchQueue.main.async { self?.authorised = ok }
        }
    }

    func reschedule(for tasks: [Item], projects: [Project]) {
        guard available else { return }
        pendingReschedule?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.performReschedule(tasks: tasks, projects: projects)
        }
        pendingReschedule = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    private func performReschedule(tasks: [Item], projects: [Project]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let cal = Calendar.current
        let now = Date()
        var scheduled = 0
        let limit = 56                       // stay well under the system cap

        func projectName(_ id: UUID?) -> String {
            projects.first { $0.id == id }?.name ?? "No project"
        }

        func add(id: String, title: String, body: String, at date: Date) {
            guard scheduled < limit, date > now else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            scheduled += 1
        }

        // Soonest deadlines first, so the cap never eats the urgent ones.
        let upcoming = tasks
            .filter { !$0.isDone && $0.due != nil }
            .sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }

        for t in upcoming {
            guard let due = t.due else { continue }
            let where_ = projectName(t.projectID)

            // Evening before.
            if let evePrev = cal.date(byAdding: .day, value: -1, to: due),
               let eve = cal.date(bySettingHour: 19, minute: 0, second: 0, of: evePrev) {
                add(id: "\(t.id)-eve",
                    title: "Due tomorrow — \(t.title)",
                    body: "\(where_)\(t.checkpointSummary.map { " · \($0) checkpoints done" } ?? "")",
                    at: eve)
            }

            // Morning of.
            if let morning = cal.date(bySettingHour: 9, minute: 0, second: 0, of: due) {
                let next = t.nextCheckpoint.map { "Next: \($0.title)" } ?? where_
                add(id: "\(t.id)-morning", title: "Due today — \(t.title)", body: next, at: morning)
            }

            // An hour before a timed deadline.
            if DateFmt.hasTime(due), let hour = cal.date(byAdding: .hour, value: -1, to: due) {
                add(id: "\(t.id)-hour",
                    title: "In an hour — \(t.title)",
                    body: "Due at \(DateFmt.time.string(from: due)) · \(where_)",
                    at: hour)
            }

            // Checkpoint deadlines get their own nudge.
            for c in t.checkpoints where !c.done {
                if let cd = c.due, let morning = cal.date(bySettingHour: 9, minute: 0, second: 0, of: cd) {
                    add(id: "\(c.id)-cp",
                        title: "Checkpoint today — \(c.title)",
                        body: t.title, at: morning)
                }
            }
        }

        // The daily review: one prompt each morning to look at what slipped.
        let review = UNMutableNotificationContent()
        review.title = "Daily review"
        review.body = "Open Momentum: what's due today, and what slipped yesterday?"
        review.sound = .default
        var rc = DateComponents(); rc.hour = 8; rc.minute = 30
        center.add(UNNotificationRequest(identifier: "daily-review",
                                         content: review,
                                         trigger: UNCalendarNotificationTrigger(dateMatching: rc, repeats: true)))
    }

    // Show banners even while the app is frontmost.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler handler: @escaping () -> Void) {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first { $0.canBecomeMain }?.makeKeyAndOrderFront(nil)
        }
        handler()
    }
}
