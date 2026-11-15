import SwiftUI
import AppKit

/// The Learning shelf: one card per topic, with the links you have collected
/// under it. Separate from the task list because resources pile up over months
/// and are not things to tick off by Friday.
struct LearningView: View {
    @EnvironmentObject var store: AppStore
    @State private var newTopic = ""
    @State private var collapsed: Set<UUID> = []

    private var topics: [Item] {
        let list = store.learningTopics
        guard !store.search.isEmpty else { return list }
        let q = store.search.lowercased()
        return list.filter { topic in
            topic.title.lowercased().contains(q)
                || topic.links.contains {
                    $0.displayTitle.lowercased().contains(q) || $0.url.lowercased().contains(q)
                }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                addTopicRow

                if topics.isEmpty {
                    EmptyState(icon: store.search.isEmpty ? "books.vertical" : "magnifyingglass",
                               title: store.search.isEmpty ? "Nothing on the shelf yet"
                                                           : "No topic or link matches",
                               message: store.search.isEmpty
                                 ? "Add a topic above — “System design”, “SwiftUI”, “German B2” — then drop links under it as you find them."
                                 : "Search looks at topic names and at the links inside them.",
                               tint: Theme.violet)
                        .padding(.top, 30)
                } else {
                    ForEach(topics) { topic in
                        TopicCard(topic: topic,
                                  collapsed: collapsed.contains(topic.id),
                                  toggleCollapsed: { toggle(topic.id) })
                            .id(topic.id)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 28)
        }
        .animation(Theme.spring, value: topics.map(\.id))
    }

    private func toggle(_ id: UUID) {
        if collapsed.contains(id) { collapsed.remove(id) } else { collapsed.insert(id) }
    }

    private var addTopicRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.violet)
            InlineField(placeholder: "New topic — what are you learning?", text: $newTopic) {
                store.addTopic(newTopic)
                newTopic = ""
            }
            GhostButton(title: "Add topic", icon: "plus") {
                store.addTopic(newTopic)
                newTopic = ""
            }
            .disabled(newTopic.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - One topic and its links

struct TopicCard: View {
    @EnvironmentObject var store: AppStore
    var topic: Item
    var collapsed: Bool
    var toggleCollapsed: () -> Void

    @State private var newLink = ""
    @State private var hover = false

    private var links: [Resource] { topic.links }
    private var doneCount: Int { links.filter(\.done).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if !collapsed {
                VStack(alignment: .leading, spacing: 5) {
                    if links.isEmpty {
                        Text("No links yet — paste one below.")
                            .font(Theme.ui(11.5))
                            .foregroundStyle(Theme.textFaint)
                            .padding(.vertical, 6)
                    } else {
                        ForEach(links) { r in
                            ResourceRow(topicID: topic.id, resource: r)
                        }
                    }
                    addLinkRow
                }
                .padding(.top, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .card(hovering: hover)
        .onHoverSpring { hover = $0 }
        .animation(Theme.quick, value: collapsed)
        .animation(Theme.quick, value: links.count)
    }

    private var header: some View {
        HStack(spacing: 9) {
            Button(action: toggleCollapsed) {
                Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.textFaint)
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Image(systemName: "books.vertical.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.violet)

            Text(topic.title)
                .font(Theme.display(14, .semibold))
                .foregroundStyle(topic.isDone ? Theme.textDim : Theme.text)
                .strikethrough(topic.isDone, color: Theme.textDim)
                .lineLimit(1)

            if !links.isEmpty {
                Pill(text: "\(doneCount)/\(links.count)", icon: "checkmark", tint: Theme.green)
            }
            if topic.unreadLinks > 0 {
                Pill(text: "\(topic.unreadLinks) to read", icon: "bookmark.fill", tint: Theme.violet)
            }

            Spacer(minLength: 0)

            if hover {
                IconButton(icon: "sidebar.right", help: "Open in the inspector", size: 11) {
                    store.selectedTaskID = topic.id
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { store.selectedTaskID = topic.id }
        .contextMenu {
            Button("Open in inspector") { store.selectedTaskID = topic.id }
            Button(topic.isDone ? "Mark as still learning" : "Mark topic finished") {
                store.toggleDone(topic.id)
            }
            Divider()
            Button("Delete topic", role: .destructive) { store.delete(topic.id) }
        }
    }

    private var addLinkRow: some View {
        HStack(spacing: 7) {
            Image(systemName: "link")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textFaint)
                .frame(width: 16)
            InlineField(placeholder: "Paste a link…", text: $newLink, font: Theme.ui(12)) { add() }
            GhostButton(title: "Add", icon: "plus") { add() }
                .disabled(newLink.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.top, 2)
    }

    /// "https://x.com/post  Great intro" — anything after the URL becomes the title,
    /// so you can label a link in the same keystroke run without a second field.
    private func add() {
        let raw = newLink.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return }
        let parts = raw.split(separator: " ", maxSplits: 1).map(String.init)
        store.addResource(topic.id,
                          url: parts.first ?? raw,
                          title: parts.count > 1 ? parts[1] : "")
        newLink = ""
    }
}

// MARK: - A single link

struct ResourceRow: View {
    @EnvironmentObject var store: AppStore
    var topicID: UUID
    var resource: Resource

    @State private var hover = false
    @State private var renaming = false
    @State private var draftTitle = ""

    var body: some View {
        HStack(spacing: 8) {
            Button { store.toggleResource(topicID, resource.id) } label: {
                Image(systemName: resource.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(resource.done ? Theme.green : Theme.textFaint)
            }
            .buttonStyle(.plain)
            .help(resource.done ? "Mark as not read" : "Mark as read")

            if renaming {
                InlineField(placeholder: "Title", text: $draftTitle, font: Theme.ui(12)) {
                    store.renameResource(topicID, resource.id, to: draftTitle)
                    renaming = false
                }
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(resource.displayTitle)
                        .font(Theme.ui(12.5, .medium))
                        .foregroundStyle(resource.done ? Theme.textDim : Theme.text)
                        .strikethrough(resource.done, color: Theme.textDim)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        if !resource.host.isEmpty {
                            Text(resource.host)
                                .font(Theme.ui(10.5))
                                .foregroundStyle(Theme.textFaint)
                                .lineLimit(1)
                        }
                        Text("· added " + DateFmt.dayMonth.string(from: resource.addedAt))
                            .font(Theme.ui(10.5))
                            .foregroundStyle(Theme.textFaint)
                            .lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { open() }

                Spacer(minLength: 0)

                if hover {
                    IconButton(icon: "arrow.up.right.square", help: "Open in your browser", size: 11) { open() }
                    IconButton(icon: "pencil", help: "Rename", size: 11) {
                        draftTitle = resource.title.isEmpty ? resource.displayTitle : resource.title
                        renaming = true
                    }
                    IconButton(icon: "trash", help: "Remove this link", size: 11) {
                        store.removeResource(topicID, resource.id)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(hover ? Theme.stroke.opacity(0.6) : .clear)
        )
        .clipped()
        .onHoverSpring { hover = $0 }
        .contextMenu {
            Button("Open in browser") { open() }
            Button("Copy link") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(resource.normalizedURL, forType: .string)
            }
            Button(resource.done ? "Mark as not read" : "Mark as read") {
                store.toggleResource(topicID, resource.id)
            }
            Divider()
            Button("Remove", role: .destructive) { store.removeResource(topicID, resource.id) }
        }
    }

    private func open() {
        guard let u = URL(string: resource.normalizedURL) else { return }
        NSWorkspace.shared.open(u)
    }
}
