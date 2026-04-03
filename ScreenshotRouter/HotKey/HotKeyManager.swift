import AppKit

class HotKeyManager {

    var onTriggered: (() -> Void)?
    var onLog: ((String) -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var pendingKeyCode: UInt32 = 0
    private var pendingMods: UInt32 = 0
    private var accessibilityTimer: Timer?

    // MARK: - Registration

    func register(keyCode: UInt32, modifiers: UInt32) {
        unregister()
        pendingKeyCode = keyCode
        pendingMods = modifiers
        log("register: keyCode=\(keyCode) mods=\(modifiers) [\(KeyCodeMapper.displayString(keyCode: keyCode, carbonModifiers: modifiers))]")

        if AXIsProcessTrusted() {
            installMonitors(keyCode: keyCode, modifiers: modifiers)
        } else {
            log("Accessibility not granted — showing prompt, will poll until granted")
            HotKeyManager.requestAccessibility()
            startAccessibilityPolling()
        }
    }

    func unregister() {
        stopAccessibilityPolling()
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor  { NSEvent.removeMonitor(m); localMonitor = nil }
    }

    deinit { unregister() }

    // MARK: - Monitor installation

    private func installMonitors(keyCode: UInt32, modifiers: UInt32) {
        let targetCode = keyCode
        let targetNSMods = KeyCodeMapper.nsModifiers(from: modifiers)

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            let pressed = event.modifierFlags.intersection([.command, .control, .option, .shift])
            if UInt32(event.keyCode) == targetCode && pressed == targetNSMods {
                self.log("global monitor fired")
                DispatchQueue.main.async { self.onTriggered?() }
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let pressed = event.modifierFlags.intersection([.command, .control, .option, .shift])
            if UInt32(event.keyCode) == targetCode && pressed == targetNSMods {
                self.log("local monitor fired")
                DispatchQueue.main.async { self.onTriggered?() }
                return nil
            }
            return event
        }

        log(globalMonitor != nil ? "NSEvent monitors installed ✓" : "NSEvent monitor FAILED")
    }

    // MARK: - Accessibility polling

    /// Polls every 1 s until Accessibility is granted, then installs monitors automatically.
    private func startAccessibilityPolling() {
        stopAccessibilityPolling()
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            if AXIsProcessTrusted() {
                timer.invalidate()
                self.accessibilityTimer = nil
                self.log("Accessibility granted — installing monitors now")
                self.installMonitors(keyCode: self.pendingKeyCode, modifiers: self.pendingMods)
            }
        }
    }

    private func stopAccessibilityPolling() {
        accessibilityTimer?.invalidate()
        accessibilityTimer = nil
    }

    // MARK: - Accessibility helpers

    static func hasAccessibility() -> Bool { AXIsProcessTrusted() }

    static func requestAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(opts as CFDictionary)
    }

    private func log(_ msg: String) { onLog?(msg) }
}
