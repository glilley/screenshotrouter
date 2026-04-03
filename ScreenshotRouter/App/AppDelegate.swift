import AppKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let preferences = Preferences.shared
    private let hotKeyManager = HotKeyManager()
    private let notifier = Notifier()
    private var settingsWindowController: SettingsWindowController?
    private var folderPickerController: FolderPickerPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("applicationDidFinishLaunching")
        setupStatusItem()
        notifier.requestPermission()
        checkAccessibilityPermission()
        registerHotKey()

        if preferences.folders.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.openSettings()
            }
        }
    }

    // Called when user double-clicks the app in Finder while already running
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        openSettings()
        return false
    }

    // MARK: - Menu Bar

    private func log(_ msg: String) {
        let line = "\(Date()): \(msg)\n"
        let url = URL(fileURLWithPath: "/tmp/screenshotrouter_debug.log")
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path) {
                if let fh = try? FileHandle(forWritingTo: url) {
                    fh.seekToEndOfFile(); fh.write(data); fh.closeFile()
                }
            } else {
                try? data.write(to: url)
            }
        }
    }

    private static func menuBarIcon() -> NSImage? {
        let svg = """
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M10.852 14.772L10.469 15.695M10.852 9.22799L10.469 8.30499M13.148 14.772L13.53 15.696M13.531 8.30499L13.148 9.22799M14.772 10.852L15.695 10.469M14.772 13.148L15.695 13.531M17.598 6.49999C17.8281 6.10148 17.9635 5.65538 17.9936 5.19619C18.0237 4.737 17.9478 4.27704 17.7717 3.85189C17.5956 3.42673 17.3241 3.04779 16.9781 2.74437C16.6321 2.44095 16.221 2.22119 15.7765 2.10209C15.332 1.98298 14.866 1.96773 14.4147 2.05751C13.9634 2.14729 13.5388 2.33969 13.1737 2.61984C12.8086 2.89998 12.5129 3.26036 12.3093 3.67308C12.1058 4.08581 12 4.53982 12 4.99999C12.0006 4.33379 11.7794 3.68633 11.3714 3.15973C10.9633 2.63312 10.3916 2.25732 9.7463 2.09159C9.10104 1.92586 8.41897 1.97963 7.80764 2.24442C7.19632 2.50921 6.69052 2.96995 6.37001 3.55399C6.10618 4.03423 5.97891 4.57755 6.00201 5.12499M6.00201 5.12499C5.41416 5.27621 4.86843 5.55923 4.40617 5.95261C3.9439 6.34599 3.57723 6.83941 3.33392 7.3955C3.09061 7.95159 2.97706 8.55576 3.00185 9.16225C3.02664 9.76873 3.18913 10.3616 3.47701 10.896M6.00201 5.12499C6.02239 5.6089 6.15964 6.08067 6.40201 6.49999M17.998 5.12499C18.5859 5.27621 19.1316 5.55923 19.5939 5.95261C20.0561 6.34599 20.4228 6.83941 20.6661 7.3955C20.9094 7.95159 21.023 8.55576 20.9982 9.16225C20.9734 9.76873 20.8109 10.3616 20.523 10.896M19.505 10.294C20.3642 10.6429 21.0754 11.2796 21.5171 12.095C21.9587 12.9105 22.1033 13.854 21.9261 14.7643C21.749 15.6745 21.261 16.4949 20.5457 17.0852C19.8305 17.6754 18.9324 17.9988 18.005 18M4.03201 17.483C3.91163 18.4007 4.11323 19.3318 4.60246 20.1175C5.09169 20.9032 5.83827 21.495 6.71494 21.7919C7.59161 22.0888 8.54411 22.0725 9.4101 21.7457C10.2761 21.419 11.002 20.802 11.464 20C11.644 19.689 12.356 19.689 12.536 20C12.998 20.8018 13.7238 21.4187 14.5897 21.7454C15.4555 22.0721 16.4079 22.0885 17.2845 21.7917C18.161 21.495 18.9076 20.9035 19.3969 20.118C19.8862 19.3325 20.0881 18.4016 19.968 17.484M4.50001 10.291C3.6389 10.6387 2.92562 11.2752 2.4825 12.0914C2.03938 12.9075 1.89404 13.8524 2.07142 14.764C2.24879 15.6756 2.73781 16.497 3.45462 17.0874C4.17143 17.6779 5.07134 18.0005 6.00001 18M9.22801 10.852L8.30501 10.469M9.22801 13.148L8.30501 13.531M15 12C15 13.6568 13.6569 15 12 15C10.3432 15 9.00001 13.6568 9.00001 12C9.00001 10.3431 10.3432 8.99999 12 8.99999C13.6569 8.99999 15 10.3431 15 12Z" stroke="black" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
        """
        guard let data = svg.data(using: .utf8),
              let image = NSImage(data: data) else { return nil }
        image.isTemplate = true
        return image
    }

    private func setupStatusItem() {
        log("setupStatusItem called, main thread: \(Thread.isMainThread)")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true
        statusItem.autosaveName = "ScreenshotRouterStatusItem"
        log("statusItem created, button nil: \(statusItem.button == nil)")
        if let button = statusItem.button {
            button.image = AppDelegate.menuBarIcon()
            log("button image set")
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit ScreenshotRouter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(hotKeyManager: hotKeyManager)
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Permissions

    private func checkAccessibilityPermission() {
        if !HotKeyManager.hasAccessibility() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = "ScreenshotRouter needs Accessibility access to register its global keyboard shortcut.\n\nClick OK to open System Settings, then enable ScreenshotRouter under Privacy & Security → Accessibility. Relaunch the app after granting permission."
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Later")
                NSApp.activate(ignoringOtherApps: true)
                if alert.runModal() == .alertFirstButtonReturn {
                    HotKeyManager.requestAccessibility()
                }
            }
        }
    }

    // MARK: - Hot Key

    func registerHotKey() {
        let code = preferences.hotKeyCode
        let mods = preferences.hotKeyModifiers
        log("registerHotKey: code=\(code) mods=\(mods) display=\(KeyCodeMapper.displayString(keyCode: code, carbonModifiers: mods))")
        hotKeyManager.onLog = { [weak self] msg in self?.log("HKM: \(msg)") }
        hotKeyManager.register(keyCode: code, modifiers: mods)
        hotKeyManager.onTriggered = { [weak self] in
            self?.log(">>> HOTKEY FIRED <<<")
            self?.startScreenshotFlow()
        }
    }

    // MARK: - Screenshot Flow

    private func startScreenshotFlow() {
        if folderPickerController?.isShowingSuccess == true {
            folderPickerController?.forceClose()
            folderPickerController = nil
            return
        }
        log("startScreenshotFlow: checking screen capture access")
        let hasAccess = CGPreflightScreenCaptureAccess()
        log("screen capture access: \(hasAccess)")
        if !hasAccess {
            CGRequestScreenCaptureAccess()
            log("requested screen capture access - user must grant in System Settings")
            return
        }

        let folders = preferences.folders
        log("folders count: \(folders.count)")
        if folders.isEmpty {
            showNoFoldersAlert()
            return
        }

        log("launching screencapture -i")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = ScreenshotCapture.capture()
            self.log("screencapture result: \(result?.path ?? "nil (user cancelled)")")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                guard let sourceURL = result else { return }
                self.showFolderPicker(for: sourceURL)
            }
        }
    }

    private func showFolderPicker(for sourceURL: URL) {
        let controller = FolderPickerPanelController(
            sourceURL: sourceURL,
            folders: preferences.folders
        )
        controller.onFolderSelected = { [weak self] destinationFolder in
            self?.moveScreenshot(from: sourceURL, to: destinationFolder)
        }
        controller.onBrowse = { [weak self] in
            self?.browseForFolder(sourceURL: sourceURL)
        }
        controller.onSettings = { [weak self] in
            self?.folderPickerController?.forceClose()
            self?.folderPickerController = nil
            self?.openSettings()
        }
        controller.showPanel()
        folderPickerController = controller
    }

    private func moveScreenshot(from source: URL, to folder: URL) {
        do {
            let destination = uniqueURL(for: folder.appendingPathComponent(source.lastPathComponent))
            _ = folder.startAccessingSecurityScopedResource()
            defer { folder.stopAccessingSecurityScopedResource() }
            try FileManager.default.moveItem(at: source, to: destination)
            let shortName = folder.lastPathComponent
            notifier.show(title: "Screenshot saved", body: "Saved to \(shortName)")
        } catch {
            showErrorAlert("Could not save screenshot: \(error.localizedDescription)")
        }
    }

    private func browseForFolder(sourceURL: URL) {
        folderPickerController = nil
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Save Here"
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let folder = panel.url {
            moveScreenshot(from: sourceURL, to: folder)
        }
    }

    // MARK: - Helpers

    private func uniqueURL(for url: URL) -> URL {
        guard FileManager.default.fileExists(atPath: url.path) else { return url }
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let dir = url.deletingLastPathComponent()
        var counter = 1
        while true {
            let candidate = dir.appendingPathComponent("\(base)_\(counter).\(ext)")
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            counter += 1
        }
    }

    private func showNoFoldersAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "No folders configured"
        alert.informativeText = "Open Settings to add destination folders."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            openSettings()
        }
    }

    private func showErrorAlert(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "ScreenshotRouter Error"
        alert.informativeText = message
        alert.runModal()
    }
}
