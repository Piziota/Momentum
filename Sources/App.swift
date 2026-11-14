import SwiftUI
import AppKit

@main
struct MomentumApp: App {
    @StateObject private var store = AppStore()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .frame(minWidth: 1080, minHeight: 680)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1320, height: 860)
        .commands { MomentumCommands(store: store) }

        // Menu bar: how many things are live right now, without opening the app.
        MenuBarExtra {
            MenuBarPanel().environmentObject(store)
        } label: {
            MenuBarLabel().environmentObject(store)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Reminders.shared.start()
        NSApp.setActivationPolicy(.regular)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

// MARK: - Root layout

struct RootView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                Sidebar()
                    .frame(width: 234)

                MainContent()
                    .frame(maxWidth: .infinity)

                if let item = store.selectedTask {
                    DetailView(item: item)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .id(item.id)
                }
            }

            if store.quickAddOpen {
                QuickAddPalette(open: $store.quickAddOpen)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .background(Theme.bg)
        .animation(Theme.spring, value: store.selectedTaskID)
        .animation(Theme.quick, value: store.quickAddOpen)
        .onAppear {
            // Capture from any app, without opening Momentum first.
            HotkeyCenter.shared.onTrigger = {
                AppWindows.focusMain()
                withAnimation(Theme.quick) { store.quickAddOpen = true }
            }
            store.hotkeyFailed = !HotkeyCenter.shared.register(store.hotkeyID)
            if ProcessInfo.processInfo.environment["MOMENTUM_HOTKEY_TEST"] == "1" {
                let line = "HOTKEY \(store.hotkeyID) registered=\(!store.hotkeyFailed)\n"
                FileHandle.standardError.write(line.data(using: .utf8)!)
            }
        }
    }
}

// MARK: - Menu bar

struct MenuBarLabel: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        let overdue = store.overdue.count
        let today = store.dueToday.count
        HStack(spacing: 3) {
            Image(systemName: overdue > 0 ? "exclamationmark.circle.fill" : "bolt.fill")
            if overdue + today > 0 {
                Text("\(overdue + today)")
            }
        }
    }
}

struct MenuBarPanel: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        if !store.overdue.isEmpty {
            Text("Overdue")
            ForEach(store.overdue.prefix(6)) { item in
                Button("⚠ " + item.title) { open(item) }
            }
            Divider()
        }

        Text("Due today")
        if store.dueToday.isEmpty {
            Button("Nothing due today") {}.disabled(true)
        } else {
            ForEach(store.dueToday.prefix(8)) { item in
                Button((item.isDone ? "✓ " : "○ ") + item.title) { store.toggleDone(item.id) }
            }
        }

        Divider()

        if !store.liveCheckpoints.isEmpty {
            Text("Checkpoints")
            ForEach(Array(store.liveCheckpoints.prefix(6).enumerated()), id: \.offset) { pair in
                Button("○ " + pair.element.1.title) {
                    store.toggleCheckpoint(pair.element.0.id, pair.element.1.id)
                }
            }
            Divider()
        }

        Button("Quick capture  (\(store.hotkeyLabel))") {
            store.quickAddOpen = true
            activate()
        }
        Button("Open Momentum") {
            store.route = .today
            activate()
        }
        Divider()
        Button("Quit Momentum") { NSApp.terminate(nil) }
    }

    private func open(_ item: Item) {
        store.selectedTaskID = item.id
        activate()
    }

    private func activate() { AppWindows.focusMain() }
}

// MARK: - Menus & shortcuts

struct MomentumCommands: Commands {
    @ObservedObject var store: AppStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Task") { store.quickAddOpen = true }
                .keyboardShortcut("n", modifiers: .command)
            Button("Quick Capture") { store.quickAddOpen = true }
                .keyboardShortcut(.space, modifiers: [.command, .shift])
        }

        CommandMenu("Go") {
            Group {
                Button("Today") { store.route = .today }.keyboardShortcut("1", modifiers: .command)
                Button("Upcoming") { store.route = .upcoming }.keyboardShortcut("2", modifiers: .command)
                Button("All Tasks") { store.route = .all }.keyboardShortcut("3", modifiers: .command)
            }
            Divider()
            Group {
                Button("List") { store.mode = .list }.keyboardShortcut("l", modifiers: [.command, .option])
                Button("Board") { store.mode = .board }.keyboardShortcut("b", modifiers: [.command, .option])
                Button("Calendar") { store.mode = .calendar }.keyboardShortcut("k", modifiers: [.command, .option])
                Button("Timeline") { store.mode = .gantt }.keyboardShortcut("g", modifiers: [.command, .option])
            }
            Divider()
            Toggle("Show Completed", isOn: $store.showDone)
                .keyboardShortcut("d", modifiers: [.command, .shift])
            Button("Close Inspector") { store.selectedTaskID = nil }
                .keyboardShortcut(.escape, modifiers: [])
        }

        CommandMenu("Task") {
            Button("Mark Selected Done") {
                if let id = store.selectedTaskID { store.toggleDone(id) }
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(store.selectedTaskID == nil)

            Button("Delete Selected") {
                if let id = store.selectedTaskID { store.delete(id) }
            }
            .keyboardShortcut(.delete, modifiers: [.command])
            .disabled(store.selectedTaskID == nil)
        }

        CommandGroup(after: .appInfo) {
            Menu("Global Capture Hotkey") {
                ForEach(HotkeyCenter.combos) { c in
                    Button((store.hotkeyID == c.id ? "✓  " : "    ") + c.label) {
                        store.setHotkey(c.id)
                    }
                }
            }
            if store.hotkeyFailed {
                Button("⚠ Hotkey in use by another app") {}.disabled(true)
            }
            Divider()
            Button("Reveal Data File in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([AppStore.storeURL])
            }
            Button("Remove Sample Data") { store.clearSampleData() }
        }
    }
}
