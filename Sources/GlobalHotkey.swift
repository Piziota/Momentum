import Foundation
import Carbon.HIToolbox
import AppKit

/// A system-wide capture hotkey.
///
/// Uses Carbon's RegisterEventHotKey rather than an NSEvent global monitor, because
/// this route needs no Accessibility permission — it just works once the app is running.
final class HotkeyCenter {

    static let shared = HotkeyCenter()

    struct Combo: Identifiable, Equatable {
        let id: String
        let label: String
        let key: UInt32          // virtual key code
        let mods: UInt32         // Carbon modifier mask
        var isOff: Bool { key == 0 && mods == 0 }
    }

    /// A few safe choices — ⌘Space is Spotlight and ⌥Space is often a launcher,
    /// so the default avoids both.
    static let combos: [Combo] = [
        Combo(id: "ctrl-opt-space", label: "⌃⌥Space",
              key: UInt32(kVK_Space), mods: UInt32(controlKey | optionKey)),
        Combo(id: "ctrl-opt-n", label: "⌃⌥N",
              key: UInt32(kVK_ANSI_N), mods: UInt32(controlKey | optionKey)),
        Combo(id: "ctrl-shift-space", label: "⌃⇧Space",
              key: UInt32(kVK_Space), mods: UInt32(controlKey | shiftKey)),
        Combo(id: "opt-space", label: "⌥Space",
              key: UInt32(kVK_Space), mods: UInt32(optionKey)),
        Combo(id: "off", label: "Off", key: 0, mods: 0)
    ]

    static let defaultID = "ctrl-opt-space"
    static func combo(_ id: String) -> Combo {
        combos.first { $0.id == id } ?? combos[0]
    }

    /// Called on the main queue when the hotkey fires.
    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var installed = false

    private init() {}

    // MARK: - Registration

    /// Registers the given combo, replacing any previous one.
    /// Returns false when the combination is already taken by another app.
    @discardableResult
    func register(_ id: String) -> Bool {
        installHandlerIfNeeded()
        unregister()

        let combo = Self.combo(id)
        guard !combo.isOff else { return true }

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x4D4F_4D4E), id: 1)   // 'MOMN'
        let status = RegisterEventHotKey(combo.key, combo.mods, hotKeyID,
                                         GetEventDispatcherTarget(), 0, &ref)
        guard status == noErr, ref != nil else { return false }
        hotKeyRef = ref
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard !installed else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        // The callback captures nothing, so it converts to a C function pointer.
        let status = InstallEventHandler(GetEventDispatcherTarget(), { _, _, _ -> OSStatus in
            HotkeyCenter.shared.fire()
            return noErr
        }, 1, &spec, nil, &handlerRef)
        installed = (status == noErr)
    }

    fileprivate func fire() {
        DispatchQueue.main.async { [weak self] in self?.onTrigger?() }
    }
}

// MARK: - Bringing the app forward

enum AppWindows {
    /// Front the main window, reopening one if every window was closed.
    static func focusMain() {
        NSApp.activate(ignoringOtherApps: true)
        let main = NSApp.windows.first { w in
            w.canBecomeMain && !(w is NSPanel) && w.contentView != nil
        }
        if let main {
            if !main.isVisible { main.makeKeyAndOrderFront(nil) }
            main.makeKeyAndOrderFront(nil)
        } else {
            // No window left — ask SwiftUI for a fresh one.
            NSApp.sendAction(#selector(NSResponder.newWindowForTab(_:)), to: nil, from: nil)
        }
    }
}
