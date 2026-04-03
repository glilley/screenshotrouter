import AppKit

class SettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {

    private let preferences = Preferences.shared
    private let hotKeyManager: HotKeyManager
    private var tableView: NSTableView!
    private var hotKeyRecorder: HotKeyRecorderControl!
    private var folders: [URL] = []

    init(hotKeyManager: HotKeyManager) {
        self.hotKeyManager = hotKeyManager
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 380),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ScreenshotRouter Settings"
        window.center()
        super.init(window: window)
        buildUI()
        reload()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI

    private func buildUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true

        // --- Hotkey section ---
        let hotkeyLabel = NSTextField(labelWithString: "Trigger shortcut:")
        hotkeyLabel.font = .systemFont(ofSize: 13)
        hotkeyLabel.translatesAutoresizingMaskIntoConstraints = false

        hotKeyRecorder = HotKeyRecorderControl(frame: .zero)
        hotKeyRecorder.translatesAutoresizingMaskIntoConstraints = false
        hotKeyRecorder.setHotKey(keyCode: preferences.hotKeyCode, carbonModifiers: preferences.hotKeyModifiers)

        hotKeyRecorder.onRecordingStarted = { [weak self] in
            self?.hotKeyManager.unregister()
        }
        hotKeyRecorder.onRecordingEnded = { [weak self] in
            guard let self else { return }
            self.hotKeyManager.register(keyCode: self.preferences.hotKeyCode, modifiers: self.preferences.hotKeyModifiers)
        }
        hotKeyRecorder.onRecorded = { [weak self] keyCode, modifiers in
            guard let self else { return }
            self.preferences.hotKeyCode = keyCode
            self.preferences.hotKeyModifiers = modifiers
            self.hotKeyManager.register(keyCode: keyCode, modifiers: modifiers)
        }

        // --- Folders section ---
        let foldersLabel = NSTextField(labelWithString: "Selected folders:")
        foldersLabel.font = .systemFont(ofSize: 13)
        foldersLabel.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        tableView = NSTableView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 24
        tableView.allowsMultipleSelection = false

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("folder"))
        col.title = "Folder"
        col.width = 400
        tableView.addTableColumn(col)
        tableView.headerView = nil

        scrollView.documentView = tableView
        tableView.frame = scrollView.bounds

        // Add / Remove buttons
        let addBtn = NSButton(title: "+", target: self, action: #selector(addFolder))
        addBtn.bezelStyle = .rounded
        addBtn.translatesAutoresizingMaskIntoConstraints = false

        let removeBtn = NSButton(title: "–", target: self, action: #selector(removeFolder))
        removeBtn.bezelStyle = .rounded
        removeBtn.translatesAutoresizingMaskIntoConstraints = false

        let btnStack = NSStackView(views: [addBtn, removeBtn])
        btnStack.orientation = .horizontal
        btnStack.spacing = 8
        btnStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(hotkeyLabel)
        contentView.addSubview(hotKeyRecorder)
        contentView.addSubview(foldersLabel)
        contentView.addSubview(scrollView)
        contentView.addSubview(btnStack)

        let pad: CGFloat = 20
        NSLayoutConstraint.activate([
            // Hotkey row
            hotkeyLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            hotkeyLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: pad),

            hotKeyRecorder.leadingAnchor.constraint(equalTo: hotkeyLabel.trailingAnchor, constant: 12),
            hotKeyRecorder.centerYAnchor.constraint(equalTo: hotkeyLabel.centerYAnchor),
            hotKeyRecorder.widthAnchor.constraint(equalToConstant: 160),
            hotKeyRecorder.heightAnchor.constraint(equalToConstant: 28),
            hotKeyRecorder.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -pad),

            // Folders label
            foldersLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            foldersLabel.topAnchor.constraint(equalTo: hotkeyLabel.bottomAnchor, constant: 20),

            // Table
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
            scrollView.topAnchor.constraint(equalTo: foldersLabel.bottomAnchor, constant: 8),
            scrollView.bottomAnchor.constraint(equalTo: btnStack.topAnchor, constant: -8),

            // Buttons
            btnStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            btnStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -pad),
        ])
    }

    private func reload() {
        folders = preferences.folders
        tableView.reloadData()
    }

    // MARK: - Actions

    @objc private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Add Folder"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        preferences.addFolder(url)
        reload()
    }

    @objc private func removeFolder() {
        let row = tableView.selectedRow
        guard row >= 0 else { return }
        preferences.removeFolder(at: row)
        reload()
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int { folders.count }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cell")
        var cell = tableView.makeView(withIdentifier: id, owner: nil) as? NSTableCellView
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = id
            let tf = NSTextField(labelWithString: "")
            tf.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(tf)
            cell?.textField = tf
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 4),
                tf.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                tf.trailingAnchor.constraint(equalTo: cell!.trailingAnchor),
            ])
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = folders[row].path
        let display = path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
        let prefix = row < 9 ? "\(row + 1).  " : "    "
        cell?.textField?.stringValue = prefix + display
        return cell
    }
}
