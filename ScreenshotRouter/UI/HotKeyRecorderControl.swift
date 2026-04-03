import AppKit
import Carbon

/// A clickable control that records the next key combination pressed.
class HotKeyRecorderControl: NSControl {

    private(set) var keyCode: UInt32 = 0
    private(set) var carbonModifiers: UInt32 = 0

    var onRecorded: ((UInt32, UInt32) -> Void)?
    /// Called when recording starts so the caller can unregister the active hotkey temporarily.
    var onRecordingStarted: (() -> Void)?
    /// Called when recording ends so the caller can re-register the hotkey.
    var onRecordingEnded: (() -> Void)?

    private var isRecording = false
    private let label = NSTextField(labelWithString: "Click to record")

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1

        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .center
        label.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        updateAppearance()

        let click = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
        addGestureRecognizer(click)
    }

    // MARK: - Public API

    func setHotKey(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        label.stringValue = KeyCodeMapper.displayString(keyCode: keyCode, carbonModifiers: carbonModifiers)
    }

    // MARK: - Recording

    @objc private func handleClick() {
        guard !isRecording else { return }
        isRecording = true
        label.stringValue = "Press a key combo…"
        window?.makeFirstResponder(self)   // essential: lets keyDown reach this control
        onRecordingStarted?()
        updateAppearance()
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }

        // Esc cancels recording
        if event.keyCode == 53 {
            finishRecording(cancelled: true)
            return
        }

        // Require at least one modifier
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard !flags.isEmpty else { return }

        keyCode = UInt32(event.keyCode)
        carbonModifiers = KeyCodeMapper.carbonModifiers(from: flags)
        let savedCode = keyCode
        let savedMods = carbonModifiers
        finishRecording(cancelled: false)
        onRecorded?(savedCode, savedMods)
    }

    private func finishRecording(cancelled: Bool) {
        isRecording = false
        if cancelled {
            label.stringValue = KeyCodeMapper.displayString(keyCode: keyCode, carbonModifiers: carbonModifiers)
        } else {
            label.stringValue = KeyCodeMapper.displayString(keyCode: keyCode, carbonModifiers: carbonModifiers)
        }
        onRecordingEnded?()
        updateAppearance()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func updateAppearance() {
        let bg: NSColor = isRecording ? NSColor.selectedControlColor.withAlphaComponent(0.2) : NSColor.controlBackgroundColor
        let border: NSColor = isRecording ? NSColor.selectedControlColor : NSColor.separatorColor
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = bg.cgColor
            layer?.borderColor = border.cgColor
        }
        label.textColor = .labelColor
    }
}
