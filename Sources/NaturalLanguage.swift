import Foundation

/// Result of parsing a quick-capture line.
struct ParsedInput {
    var title: String = ""
    var tagNames: [String] = []
    var projectQuery: String? = nil
    var priority: Priority = .none
    var due: Date? = nil
    var estimateHours: Double? = nil
    /// Human description of what was understood, shown live under the field.
    var hints: [String] = []
}

/// Turns "Send CV to Erste fri 5pm #jobs !high @finaustria ~2h" into structured fields.
struct QuickParser {

    private static let months = ["jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
                                 "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12]
    private static let weekdays = ["sun": 1, "sunday": 1,
                                   "mon": 2, "monday": 2,
                                   "tue": 3, "tues": 3, "tuesday": 3,
                                   "wed": 4, "weds": 4, "wednesday": 4,
                                   "thu": 5, "thur": 5, "thurs": 5, "thursday": 5,
                                   "fri": 6, "friday": 6,
                                   "sat": 7, "saturday": 7]

    static func parse(_ raw: String) -> ParsedInput {
        var out = ParsedInput()
        let cal = Calendar.current
        let tokens = raw.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        var titleWords: [String] = []
        var i = 0
        var dayPart: Date? = nil          // date without time
        var timePart: (h: Int, m: Int)? = nil

        func lower(_ s: String) -> String { s.lowercased() }

        while i < tokens.count {
            let tok = tokens[i]
            let t = lower(tok)
            let next = i + 1 < tokens.count ? lower(tokens[i + 1]) : ""
            var consumed = 1

            // ---- tags
            if t.hasPrefix("#"), t.count > 1 {
                out.tagNames.append(String(t.dropFirst()))
                out.hints.append("#" + String(t.dropFirst()))
            }
            // ---- project
            else if t.hasPrefix("@"), t.count > 1 {
                out.projectQuery = String(tok.dropFirst())
                out.hints.append("in " + String(tok.dropFirst()))
            }
            // ---- estimate  ~2h / ~90m
            else if t.hasPrefix("~"), let v = estimate(String(t.dropFirst())) {
                out.estimateHours = v
                out.hints.append(String(format: "%.1fh estimate", v))
            }
            // ---- priority
            else if let p = priority(t) {
                out.priority = p
                out.hints.append(p.label.lowercased() + " priority")
            }
            // ---- relative days
            else if t == "today" || t == "tod" {
                dayPart = cal.startOfDay(for: Date())
            }
            else if t == "tomorrow" || t == "tmr" || t == "tom" {
                dayPart = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))
            }
            else if t == "eod" {
                dayPart = cal.startOfDay(for: Date()); timePart = (18, 0)
            }
            else if t == "tonight" {
                dayPart = cal.startOfDay(for: Date()); timePart = (20, 0)
            }
            else if t == "eow" {
                dayPart = nextWeekday(6); timePart = (17, 0)       // Friday
            }
            else if t == "next", next == "week" {
                dayPart = cal.date(byAdding: .day, value: 7, to: cal.startOfDay(for: Date()))
                consumed = 2
            }
            else if t == "next", next == "month" {
                dayPart = cal.date(byAdding: .month, value: 1, to: cal.startOfDay(for: Date()))
                consumed = 2
            }
            else if t == "next", let wd = weekdays[next] {
                dayPart = nextWeekday(wd, skipToday: true)
                consumed = 2
            }
            else if t == "this", let wd = weekdays[next] {
                dayPart = nextWeekday(wd)
                consumed = 2
            }
            else if t == "on" || t == "by" || t == "due", weekdays[next] != nil || next == "today" || next == "tomorrow" {
                // "on friday" / "by tomorrow" — drop the preposition, let the next token speak.
                consumed = 1
            }
            // ---- in 3 days / in 2 weeks
            else if t == "in", let n = Int(next), i + 2 < tokens.count {
                let unit = lower(tokens[i + 2])
                if unit.hasPrefix("day") {
                    dayPart = cal.date(byAdding: .day, value: n, to: cal.startOfDay(for: Date())); consumed = 3
                } else if unit.hasPrefix("week") {
                    dayPart = cal.date(byAdding: .day, value: n * 7, to: cal.startOfDay(for: Date())); consumed = 3
                } else if unit.hasPrefix("month") {
                    dayPart = cal.date(byAdding: .month, value: n, to: cal.startOfDay(for: Date())); consumed = 3
                } else {
                    titleWords.append(tok)
                }
            }
            // ---- bare weekday
            else if let wd = weekdays[t] {
                dayPart = nextWeekday(wd)
            }
            // ---- "12 dec" / "dec 12"
            else if let d = Int(t), (1...31).contains(d), let m = months[String(next.prefix(3))] {
                dayPart = makeDate(day: d, month: m); consumed = 2
            }
            else if let m = months[String(t.prefix(3))], t.count <= 9, let d = Int(next), (1...31).contains(d) {
                dayPart = makeDate(day: d, month: m); consumed = 2
            }
            // ---- 12/06 or 12.06
            else if let d = numericDate(t) {
                dayPart = d
            }
            // ---- times
            else if let tm = time(t) {
                timePart = tm
            }
            else {
                titleWords.append(tok)
            }

            i += consumed
        }

        if let day = dayPart {
            if let tp = timePart {
                out.due = cal.date(bySettingHour: tp.h, minute: tp.m, second: 0, of: day)
            } else {
                out.due = day
            }
        } else if let tp = timePart {
            // A time with no date means today, or tomorrow if it has already passed.
            let today = cal.date(bySettingHour: tp.h, minute: tp.m, second: 0, of: Date()) ?? Date()
            out.due = today > Date() ? today : cal.date(byAdding: .day, value: 1, to: today)
        }

        if let due = out.due {
            out.hints.insert("due " + DateFmt.dueLabel(due), at: 0)
        }
        // "Data Viz exam on 20 Nov" loses its date to the parser and would otherwise
        // leave a dangling "on". Drop trailing words that only introduced the date.
        let filler: Set<String> = ["on", "at", "by", "due", "before", "until", "till",
                                   "the", "this", "next", "is", "-", "–", ","]
        while let last = titleWords.last,
              filler.contains(last.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ",.-"))) {
            titleWords.removeLast()
        }

        out.title = titleWords.joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,-–"))
        return out
    }

    // MARK: - Pieces

    private static func priority(_ t: String) -> Priority? {
        switch t {
        case "!high", "!h", "!1", "p1", "!!!": return .high
        case "!med", "!medium", "!m", "!2", "p2", "!!": return .medium
        case "!low", "!l", "!3", "p3", "!": return .low
        default: return nil
        }
    }

    private static func estimate(_ s: String) -> Double? {
        if s.hasSuffix("h"), let v = Double(s.dropLast()) { return v }
        if s.hasSuffix("m"), let v = Double(s.dropLast()) { return v / 60 }
        if let v = Double(s) { return v }
        return nil
    }

    private static func time(_ s: String) -> (Int, Int)? {
        if s == "noon" { return (12, 0) }
        if s == "midnight" { return (0, 0) }
        var str = s
        var pm = false, am = false
        if str.hasSuffix("pm") { pm = true; str.removeLast(2) }
        else if str.hasSuffix("am") { am = true; str.removeLast(2) }

        var h = 0, m = 0
        if str.contains(":") {
            let parts = str.split(separator: ":")
            guard parts.count == 2, let a = Int(parts[0]), let b = Int(parts[1]) else { return nil }
            h = a; m = b
        } else if (am || pm), let a = Int(str) {
            h = a
        } else {
            return nil
        }
        guard (0...23).contains(h), (0...59).contains(m) else { return nil }
        if pm, h < 12 { h += 12 }
        if am, h == 12 { h = 0 }
        return (h, m)
    }

    private static func numericDate(_ s: String) -> Date? {
        let seps: [Character] = ["/", ".", "-"]
        guard let sep = seps.first(where: { s.contains($0) }) else { return nil }
        let parts = s.split(separator: sep)
        guard parts.count >= 2, let d = Int(parts[0]), let m = Int(parts[1]),
              (1...31).contains(d), (1...12).contains(m) else { return nil }
        var year: Int? = nil
        if parts.count == 3, let y = Int(parts[2]) { year = y < 100 ? 2000 + y : y }
        return makeDate(day: d, month: m, year: year)
    }

    private static func makeDate(day: Int, month: Int, year: Int? = nil) -> Date? {
        let cal = Calendar.current
        var c = DateComponents()
        c.day = day
        c.month = month
        c.year = year ?? cal.component(.year, from: Date())
        guard let d = cal.date(from: c) else { return nil }
        // No year given and the date has gone — assume they mean next year.
        if year == nil, d < cal.startOfDay(for: Date()) {
            c.year = (c.year ?? 2026) + 1
            return cal.date(from: c)
        }
        return d
    }

    private static func nextWeekday(_ weekday: Int, skipToday: Bool = false) -> Date? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let current = cal.component(.weekday, from: today)
        var delta = (weekday - current + 7) % 7
        if delta == 0 && skipToday { delta = 7 }
        return cal.date(byAdding: .day, value: delta, to: today)
    }
}
