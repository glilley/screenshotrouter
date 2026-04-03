import AppKit

/// A borderless floating panel for the folder picker HUD.
class FolderPickerPanel: NSPanel {

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
    }

    override var canBecomeKey: Bool { true }
}
