import SwiftUI
import AppKit

// MARK: - Color utilities

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b, a: Double
        if s.count == 8 {
            r = Double((v >> 24) & 0xFF) / 255
            g = Double((v >> 16) & 0xFF) / 255
            b = Double((v >> 8) & 0xFF) / 255
            a = Double(v & 0xFF) / 255
        } else {
            r = Double((v >> 16) & 0xFF) / 255
            g = Double((v >> 8) & 0xFF) / 255
            b = Double(v & 0xFF) / 255
            a = 1
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// A colour that resolves differently in light and dark appearance.
    /// Hex is parsed straight into NSColor — going via SwiftUI's Color inside the
    /// appearance block resolves to clear and makes the whole UI invisible.
    static func dual(light: String, dark: String) -> Color {
        let lightColor = NSColor.fromHex(light)
        let darkColor = NSColor.fromHex(dark)
        return Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? darkColor : lightColor
        })
    }

    var hexString: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .gray
        return String(format: "#%02X%02X%02X",
                      Int(round(ns.redComponent * 255)),
                      Int(round(ns.greenComponent * 255)),
                      Int(round(ns.blueComponent * 255)))
    }
}

extension NSColor {
    /// "#RRGGBB" or "#RRGGBBAA" → NSColor in sRGB.
    static func fromHex(_ hex: String) -> NSColor {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        if s.count == 8 {
            return NSColor(srgbRed: CGFloat((v >> 24) & 0xFF) / 255,
                           green: CGFloat((v >> 16) & 0xFF) / 255,
                           blue: CGFloat((v >> 8) & 0xFF) / 255,
                           alpha: CGFloat(v & 0xFF) / 255)
        }
        return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
                       green: CGFloat((v >> 8) & 0xFF) / 255,
                       blue: CGFloat(v & 0xFF) / 255,
                       alpha: 1)
    }
}

// MARK: - Appearance

/// Bright, dark, or whatever the system is set to.
///
/// The whole palette is built from `Color.dual`, which resolves against the
/// *appearance* it is drawn in — so switching theme is a matter of setting one
/// appearance on the application. That also carries the window chrome, the
/// scroll bars, the menus and every NSVisualEffectView along with it, which
/// setting a SwiftUI colour scheme on the root view alone would not.
enum ThemeChoice: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Match System"
        case .light:  return "Bright"
        case .dark:   return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    private var appearance: NSAppearance? {
        switch self {
        case .system: return nil          // nil = inherit from macOS
        case .light:  return NSAppearance(named: .aqua)
        case .dark:   return NSAppearance(named: .darkAqua)
        }
    }

    func apply() {
        NSApp?.appearance = appearance
    }

    /// The next one, for the single-click switcher in the sidebar footer.
    var next: ThemeChoice {
        let all = ThemeChoice.allCases
        let i = all.firstIndex(of: self) ?? 0
        return all[(i + 1) % all.count]
    }

    // Stored in defaults rather than the task file: it is a preference about
    // this Mac, not part of your data.
    static let key = "themeChoice"

    static var saved: ThemeChoice {
        ThemeChoice(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .system
    }
}

// MARK: - Design tokens

struct Theme {
    // Surfaces
    static let bg        = Color.dual(light: "#F4F5F8", dark: "#0E1014")
    static let surface   = Color.dual(light: "#FFFFFF", dark: "#16181F")
    static let surfaceHi = Color.dual(light: "#FFFFFF", dark: "#1D2029")
    static let raised    = Color.dual(light: "#FFFFFF", dark: "#22252F")
    static let stroke    = Color.dual(light: "#00000014", dark: "#FFFFFF14")
    static let strokeHi  = Color.dual(light: "#00000024", dark: "#FFFFFF24")

    // Text
    static let text      = Color.dual(light: "#15171C", dark: "#ECEDF1")
    static let textDim   = Color.dual(light: "#5C6270", dark: "#9BA1AE")
    static let textFaint = Color.dual(light: "#8C919C", dark: "#646B7A")

    // Accents
    static let accent    = Color.dual(light: "#5A68F0", dark: "#6C7BFF")
    static let violet    = Color.dual(light: "#8E4CE6", dark: "#A86BFF")
    static let blue      = Color.dual(light: "#1E86E8", dark: "#4DA3FF")
    static let teal      = Color.dual(light: "#0FA896", dark: "#2DD4BF")
    static let green     = Color.dual(light: "#15A86B", dark: "#35D08A")
    static let amber     = Color.dual(light: "#D98400", dark: "#FFB020")
    static let red       = Color.dual(light: "#E03A3A", dark: "#FF5C5C")
    static let pink      = Color.dual(light: "#E0458F", dark: "#FF6BAE")

    static let palette: [String] = [
        "#6C7BFF", "#A86BFF", "#4DA3FF", "#2DD4BF",
        "#35D08A", "#FFB020", "#FF7A45", "#FF5C5C",
        "#FF6BAE", "#8C93A8"
    ]

    // Geometry
    static let r: CGFloat = 12       // standard corner radius
    static let rSm: CGFloat = 8
    static let rLg: CGFloat = 18

    // Fonts
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // Motion
    static let spring = Animation.spring(response: 0.34, dampingFraction: 0.78)
    static let quick  = Animation.spring(response: 0.22, dampingFraction: 0.85)
    static let soft   = Animation.easeOut(duration: 0.18)
}

// MARK: - Blur backdrop

struct VisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = .active
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.blendingMode = blending
    }
}

// MARK: - Reusable surface styling

struct CardStyle: ViewModifier {
    var hovering: Bool = false
    var selected: Bool = false
    var radius: CGFloat = Theme.r

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(selected ? Theme.raised : Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(selected ? Theme.accent.opacity(0.55)
                                           : (hovering ? Theme.strokeHi : Theme.stroke),
                                  lineWidth: selected ? 1.4 : 1)
            )
            .shadow(color: .black.opacity(hovering ? 0.16 : 0.07),
                    radius: hovering ? 14 : 6, x: 0, y: hovering ? 6 : 2)
    }
}

extension View {
    func card(hovering: Bool = false, selected: Bool = false, radius: CGFloat = Theme.r) -> some View {
        modifier(CardStyle(hovering: hovering, selected: selected, radius: radius))
    }

    /// Fires on hover with a spring, without each call site re-declaring state.
    func onHoverSpring(_ action: @escaping (Bool) -> Void) -> some View {
        onHover { inside in withAnimation(Theme.quick) { action(inside) } }
    }
}

// MARK: - Date helpers

struct DateFmt {
    static let cal = Calendar.current

    static let weekdayShort: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f
    }()
    static let dayMonth: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d MMM"; return f
    }()
    static let dayMonthYear: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d MMM yyyy"; return f
    }()
    static let monthYear: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f
    }()
    static let time: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()
    static let fullDay: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE d MMMM"; return f
    }()

    static func days(from a: Date, to b: Date) -> Int {
        cal.dateComponents([.day], from: cal.startOfDay(for: a), to: cal.startOfDay(for: b)).day ?? 0
    }

    static func hasTime(_ d: Date) -> Bool {
        let c = cal.dateComponents([.hour, .minute], from: d)
        return (c.hour ?? 0) != 0 || (c.minute ?? 0) != 0
    }

    /// Human label for a due date, relative where that reads better.
    static func dueLabel(_ d: Date) -> String {
        let off = days(from: Date(), to: d)
        let clock = hasTime(d) ? " · \(time.string(from: d))" : ""
        switch off {
        case 0:  return "Today" + clock
        case 1:  return "Tomorrow" + clock
        case -1: return "Yesterday"
        case 2...6:   return weekdayShort.string(from: d) + clock
        case -6...(-2): return "\(-off) days ago"
        default:
            if cal.component(.year, from: d) == cal.component(.year, from: Date()) {
                return dayMonth.string(from: d)
            }
            return dayMonthYear.string(from: d)
        }
    }

    static func greeting() -> String {
        switch cal.component(.hour, from: Date()) {
        case 0..<5:   return "Still up"
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default:      return "Good night"
        }
    }
}
