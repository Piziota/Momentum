import SwiftUI

// MARK: - Page card (collapsed summary, expands into an editor)

struct PageCard: View {
    @EnvironmentObject var store: AppStore
    var taskID: UUID
    var page: Page
    var tint: Color
    var expanded: Bool
    var onToggle: () -> Void

    @State private var hover = false
    @State private var previewing = true

    private var snippet: String {
        page.body
            .split(separator: "\n")
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty && !$0.hasPrefix("#") }
            .map(String.init) ?? "Empty page"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 11)).foregroundStyle(tint)

                VStack(alignment: .leading, spacing: 2) {
                    if expanded {
                        TextField("Page title", text: Binding(
                            get: { page.title },
                            set: { v in edit { $0.title = v } }
                        ))
                        .textFieldStyle(.plain)
                        .font(Theme.ui(12.5, .semibold))
                        .foregroundStyle(Theme.text)
                    } else {
                        Text(page.title)
                            .font(Theme.ui(12.5, .semibold))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        Text(snippet)
                            .font(Theme.ui(11))
                            .foregroundStyle(Theme.textFaint)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                if expanded {
                    Button(action: { withAnimation(Theme.quick) { previewing.toggle() } }) {
                        HStack(spacing: 4) {
                            Image(systemName: previewing ? "pencil" : "eye")
                                .font(.system(size: 9, weight: .semibold))
                            Text(previewing ? "Edit" : "Preview").font(Theme.ui(10.5, .semibold))
                        }
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Capsule().fill(Theme.strokeHi))
                        .foregroundStyle(Theme.textDim)
                    }
                    .buttonStyle(.plain)

                    IconButton(icon: "trash", size: 10) {
                        store.edit(taskID) { $0.pages.removeAll { $0.id == page.id } }
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .rotationEffect(.degrees(expanded ? 90 : 0))
                    .foregroundStyle(Theme.textFaint)
            }
            .padding(.horizontal, 10).padding(.vertical, 9)
            .contentShape(Rectangle())
            .onTapGesture(perform: onToggle)

            if expanded {
                Rectangle().fill(Theme.stroke).frame(height: 1)
                Group {
                    if previewing {
                        MarkdownView(text: page.body)
                            .padding(11)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        TextEditor(text: Binding(
                            get: { page.body },
                            set: { v in edit { $0.body = v } }
                        ))
                        .font(Theme.mono(12))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 180)
                        .padding(8)
                    }
                }
                HStack {
                    Text("Updated \(DateFmt.dayMonth.string(from: page.updatedAt)) · Markdown")
                        .font(Theme.ui(10)).foregroundStyle(Theme.textFaint)
                    Spacer()
                }
                .padding(.horizontal, 11).padding(.bottom, 8)
            }
        }
        .card(hovering: hover, radius: 10)
        .onHoverSpring { hover = $0 }
    }

    private func edit(_ change: (inout Page) -> Void) {
        store.edit(taskID) { t in
            guard let i = t.pages.firstIndex(where: { $0.id == page.id }) else { return }
            change(&t.pages[i])
            t.pages[i].updatedAt = Date()
        }
    }
}

// MARK: - Minimal Markdown renderer

struct MarkdownView: View {
    var text: String

    private enum Block: Identifiable {
        case h1(String), h2(String), h3(String)
        case bullet(String, Int)
        case numbered(String, Int)
        case quote(String)
        case code([String])
        case rule
        case para(String)
        case blank

        var id: String { UUID().uuidString }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("This page is empty. Switch to Edit and start writing — Markdown works (# heading, - bullet, **bold**).")
                    .font(Theme.ui(11.5)).foregroundStyle(Theme.textFaint)
            } else {
                ForEach(Array(blocks().enumerated()), id: \.offset) { pair in
                    view(for: pair.element)
                }
            }
        }
    }

    @ViewBuilder
    private func view(for block: Block) -> some View {
        switch block {
        case .h1(let s):
            inline(s).font(Theme.display(17, .bold)).foregroundStyle(Theme.text).padding(.top, 3)
        case .h2(let s):
            inline(s).font(Theme.display(14.5, .bold)).foregroundStyle(Theme.text).padding(.top, 2)
        case .h3(let s):
            inline(s).font(Theme.ui(12.5, .bold)).foregroundStyle(Theme.textDim)
        case .bullet(let s, let depth):
            HStack(alignment: .top, spacing: 7) {
                Circle().fill(Theme.textFaint).frame(width: 4, height: 4).padding(.top, 6)
                inline(s).font(Theme.ui(12)).foregroundStyle(Theme.text)
            }
            .padding(.leading, CGFloat(depth) * 14)
        case .numbered(let s, let n):
            HStack(alignment: .top, spacing: 7) {
                Text("\(n).").font(Theme.mono(11, .semibold)).foregroundStyle(Theme.textFaint)
                inline(s).font(Theme.ui(12)).foregroundStyle(Theme.text)
            }
        case .quote(let s):
            HStack(spacing: 8) {
                Capsule().fill(Theme.accent.opacity(0.6)).frame(width: 2.5)
                inline(s).font(Theme.ui(12).italic()).foregroundStyle(Theme.textDim)
            }
        case .code(let lines):
            Text(lines.joined(separator: "\n"))
                .font(Theme.mono(11))
                .foregroundStyle(Theme.teal)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Theme.stroke.opacity(0.7)))
        case .rule:
            Rectangle().fill(Theme.stroke).frame(height: 1).padding(.vertical, 3)
        case .para(let s):
            inline(s).font(Theme.ui(12)).foregroundStyle(Theme.text)
        case .blank:
            Spacer().frame(height: 2)
        }
    }

    /// Inline bold/italic/code/links via AttributedString.
    private func inline(_ s: String) -> Text {
        if let attr = try? AttributedString(markdown: s,
                                            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return Text(attr)
        }
        return Text(s)
    }

    private func blocks() -> [Block] {
        var out: [Block] = []
        var inCode = false
        var codeLines: [String] = []
        var number = 0

        for raw in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            let line = raw
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if inCode { out.append(.code(codeLines)); codeLines = []; inCode = false }
                else { inCode = true }
                continue
            }
            if inCode { codeLines.append(line); continue }

            if trimmed.isEmpty { out.append(.blank); number = 0; continue }
            if trimmed == "---" || trimmed == "***" { out.append(.rule); continue }

            if trimmed.hasPrefix("### ") { out.append(.h3(String(trimmed.dropFirst(4)))); continue }
            if trimmed.hasPrefix("## ")  { out.append(.h2(String(trimmed.dropFirst(3)))); continue }
            if trimmed.hasPrefix("# ")   { out.append(.h1(String(trimmed.dropFirst(2)))); continue }
            if trimmed.hasPrefix("> ")   { out.append(.quote(String(trimmed.dropFirst(2)))); continue }

            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let indent = line.prefix { $0 == " " }.count / 2
                out.append(.bullet(String(trimmed.dropFirst(2)), indent))
                continue
            }
            // "1. item"
            if let dot = trimmed.firstIndex(of: "."),
               let n = Int(trimmed[trimmed.startIndex..<dot]),
               trimmed.index(after: dot) < trimmed.endIndex,
               trimmed[trimmed.index(after: dot)] == " " {
                number = n
                out.append(.numbered(String(trimmed[trimmed.index(dot, offsetBy: 2)...]), number))
                continue
            }

            out.append(.para(trimmed))
        }
        if inCode, !codeLines.isEmpty { out.append(.code(codeLines)) }
        return out
    }
}
