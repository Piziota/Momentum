import SwiftUI

// MARK: - Checkbox

struct Checkbox: View {
    var done: Bool
    var tint: Color = Theme.accent
    var size: CGFloat = 20
    var action: () -> Void

    @State private var hover = false

    var body: some View {
        Button(action: {
            withAnimation(Theme.spring) { action() }
        }) {
            ZStack {
                Circle()
                    .strokeBorder(done ? tint : (hover ? tint.opacity(0.85) : Theme.strokeHi),
                                  lineWidth: 1.6)
                    .frame(width: size, height: size)

                Circle()
                    .fill(tint)
                    .frame(width: size, height: size)
                    .scaleEffect(done ? 1 : 0.1)
                    .opacity(done ? 1 : 0)

                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(.white)
                    .scaleEffect(done ? 1 : 0.4)
                    .opacity(done ? 1 : 0)

                if hover && !done {
                    Circle().fill(tint.opacity(0.14)).frame(width: size, height: size)
                }
            }
            .frame(width: size + 4, height: size + 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHoverSpring { hover = $0 }
    }
}

// MARK: - Small square checkbox for checkpoints

struct MiniCheck: View {
    var done: Bool
    var tint: Color = Theme.accent
    var action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: { withAnimation(Theme.spring) { action() } }) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(done ? tint : (hover ? tint.opacity(0.8) : Theme.strokeHi), lineWidth: 1.5)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(tint)
                    .scaleEffect(done ? 1 : 0.2)
                    .opacity(done ? 1 : 0)
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.white)
                    .opacity(done ? 1 : 0)
            }
            .frame(width: 16, height: 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHoverSpring { hover = $0 }
    }
}

// MARK: - Chips & pills

struct TagChip: View {
    var tag: Tag
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(tag.color).frame(width: 5, height: 5)
            Text(tag.name)
                .font(Theme.ui(compact ? 10 : 11, .medium))
                .lineLimit(1)
        }
        .fixedSize()
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 2 : 3)
        .background(Capsule().fill(tag.color.opacity(0.13)))
        .overlay(Capsule().strokeBorder(tag.color.opacity(0.25), lineWidth: 0.8))
        .foregroundStyle(tag.color)
    }
}

struct DuePill: View {
    var date: Date
    var isDone: Bool = false
    var compact: Bool = false

    private var tint: Color {
        if isDone { return Theme.textFaint }
        let off = DateFmt.days(from: Date(), to: date)
        if date < Date() && off <= 0 { return Theme.red }
        if off == 0 { return Theme.amber }
        if off <= 2 { return Theme.blue }
        return Theme.textDim
    }

    private var icon: String {
        if isDone { return "checkmark" }
        let off = DateFmt.days(from: Date(), to: date)
        if date < Date() && off <= 0 { return "exclamationmark.circle.fill" }
        if off == 0 { return "sun.max.fill" }
        return "calendar"
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: compact ? 8 : 9, weight: .semibold))
            Text(DateFmt.dueLabel(date)).font(Theme.ui(compact ? 10 : 11, .medium)).lineLimit(1)
        }
        .fixedSize()
        .padding(.horizontal, compact ? 6 : 7)
        .padding(.vertical, compact ? 2 : 3)
        .background(Capsule().fill(tint.opacity(0.14)))
        .foregroundStyle(tint)
    }
}

struct Pill: View {
    var text: String
    var icon: String? = nil
    var tint: Color = Theme.textDim

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: 9, weight: .semibold)) }
            Text(text).font(Theme.ui(11, .medium)).lineLimit(1)
        }
        .fixedSize()
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Capsule().fill(tint.opacity(0.13)))
        .foregroundStyle(tint)
    }
}

struct PriorityFlag: View {
    var priority: Priority
    var body: some View {
        if priority != .none {
            Image(systemName: priority == .high ? "flag.fill" : "flag")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(priority.tint)
                .help(priority.label)
        }
    }
}

// MARK: - Progress

struct ProgressRing: View {
    var value: Double
    var tint: Color = Theme.accent
    var size: CGFloat = 56
    var lineWidth: CGFloat = 6
    var label: String? = nil

    var body: some View {
        ZStack {
            Circle().strokeBorder(Theme.stroke, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, value)))
                .stroke(
                    AngularGradient(colors: [tint.opacity(0.65), tint],
                                    center: .center,
                                    startAngle: .degrees(0), endAngle: .degrees(360)),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(Theme.spring, value: value)
            if let label {
                Text(label)
                    .font(Theme.display(size * 0.3, .bold))
                    .foregroundStyle(Theme.text)
            }
        }
        .frame(width: size, height: size)
    }
}

struct ProgressBar: View {
    var value: Double
    var tint: Color = Theme.accent
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.stroke)
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.75), tint],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
        .animation(Theme.spring, value: value)
    }
}

struct Sparkline: View {
    var values: [Int]
    var tint: Color = Theme.accent

    var body: some View {
        Canvas { ctx, size in
            guard values.count > 1 else { return }
            let maxV = max(1, values.max() ?? 1)
            let stepX = size.width / CGFloat(values.count - 1)
            func pt(_ i: Int) -> CGPoint {
                CGPoint(x: CGFloat(i) * stepX,
                        y: size.height - (CGFloat(values[i]) / CGFloat(maxV)) * (size.height - 4) - 2)
            }
            var line = Path()
            line.move(to: pt(0))
            for i in 1..<values.count { line.addLine(to: pt(i)) }

            var fill = line
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.addLine(to: CGPoint(x: 0, y: size.height))
            fill.closeSubpath()

            ctx.fill(fill, with: .linearGradient(
                Gradient(colors: [tint.opacity(0.28), tint.opacity(0.0)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            ctx.stroke(line, with: .color(tint), style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))

            let last = pt(values.count - 1)
            ctx.fill(Path(ellipseIn: CGRect(x: last.x - 2.5, y: last.y - 2.5, width: 5, height: 5)),
                     with: .color(tint))
        }
    }
}

// MARK: - Buttons

struct IconButton: View {
    var icon: String
    var help: String = ""
    var tint: Color = Theme.textDim
    var size: CGFloat = 13
    var action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(hover ? Theme.text : tint)
                .frame(width: size + 14, height: size + 14)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(hover ? Theme.strokeHi : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHoverSpring { hover = $0 }
    }
}

struct PrimaryButton: View {
    var title: String
    var icon: String? = nil
    var tint: Color = Theme.accent
    var action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 11, weight: .bold)) }
                Text(title).font(Theme.ui(12, .semibold))
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(LinearGradient(colors: [tint.opacity(hover ? 1 : 0.92), tint.opacity(hover ? 0.85 : 0.78)],
                                         startPoint: .top, endPoint: .bottom))
            )
            .foregroundStyle(.white)
            .shadow(color: tint.opacity(hover ? 0.42 : 0.22), radius: hover ? 10 : 5, y: 2)
            .scaleEffect(hover ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .onHoverSpring { hover = $0 }
    }
}

struct GhostButton: View {
    var title: String
    var icon: String? = nil
    var action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon { Image(systemName: icon).font(.system(size: 10, weight: .semibold)) }
                Text(title).font(Theme.ui(11.5, .medium))
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(hover ? Theme.strokeHi : Theme.stroke.opacity(0.5)))
            .foregroundStyle(hover ? Theme.text : Theme.textDim)
        }
        .buttonStyle(.plain)
        .onHoverSpring { hover = $0 }
    }
}

// MARK: - Segmented view switcher with a sliding highlight

struct ModeSwitcher: View {
    @Binding var mode: ViewMode
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ViewMode.allCases) { m in
                let on = m == mode
                Button(action: { withAnimation(Theme.spring) { mode = m } }) {
                    HStack(spacing: 5) {
                        Image(systemName: m.icon).font(.system(size: 10.5, weight: .semibold))
                        Text(m.label).font(Theme.ui(11.5, .semibold))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .foregroundStyle(on ? Theme.text : Theme.textDim)
                    .background(
                        ZStack {
                            if on {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Theme.raised)
                                    .shadow(color: .black.opacity(0.14), radius: 4, y: 1)
                                    .matchedGeometryEffect(id: "modepill", in: ns)
                            }
                        }
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.stroke.opacity(0.6)))
    }
}

// MARK: - Headers & empty states

struct SectionHeader: View {
    var title: String
    var count: Int? = nil
    var icon: String? = nil
    var tint: Color = Theme.textDim

    var body: some View {
        HStack(spacing: 7) {
            if let icon {
                Image(systemName: icon).font(.system(size: 11, weight: .bold)).foregroundStyle(tint)
            }
            Text(title.uppercased())
                .font(Theme.ui(10.5, .bold))
                .tracking(0.8)
                .foregroundStyle(tint)
            if let count, count > 0 {
                Text("\(count)")
                    .font(Theme.ui(10, .bold))
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Capsule().fill(tint.opacity(0.16)))
                    .foregroundStyle(tint)
            }
            Rectangle().fill(Theme.stroke).frame(height: 1)
        }
    }
}

struct EmptyState: View {
    var icon: String
    var title: String
    var message: String
    var tint: Color = Theme.accent

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(tint.opacity(0.12)).frame(width: 58, height: 58)
                Image(systemName: icon)
                    .font(.system(size: 23, weight: .medium))
                    .foregroundStyle(tint)
            }
            Text(title).font(Theme.display(15, .semibold)).foregroundStyle(Theme.text)
            Text(message)
                .font(Theme.ui(12))
                .foregroundStyle(Theme.textDim)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }
}

// MARK: - Project glyph

struct ProjectGlyph: View {
    var project: Project?
    var size: CGFloat = 22

    var body: some View {
        let tint = project?.color ?? Theme.textFaint
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(tint.opacity(0.16))
            .overlay(
                Image(systemName: project?.icon ?? "tray")
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(tint)
            )
            .frame(width: size, height: size)
    }
}

// MARK: - Inline text field styled for the app

struct InlineField: View {
    var placeholder: String
    @Binding var text: String
    var font: Font = Theme.ui(12.5)
    var onSubmit: () -> Void = {}
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(font)
            .foregroundStyle(Theme.text)
            .focused($focused)
            .onSubmit(onSubmit)
            .padding(.horizontal, 9).padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.stroke.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(focused ? Theme.accent.opacity(0.7) : .clear, lineWidth: 1.4)
            )
            .animation(Theme.quick, value: focused)
    }
}

// MARK: - Stat tile

struct StatTile: View {
    var value: String
    var label: String
    var icon: String
    var tint: Color

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(tint.opacity(0.14))
                Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundStyle(tint)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(Theme.display(17, .bold)).foregroundStyle(Theme.text)
                Text(label).font(Theme.ui(10.5, .medium)).foregroundStyle(Theme.textDim)
            }
        }
        .padding(.horizontal, 11).padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
