import AppKit

// MARK: - Clickable row view

private class FolderRowView: NSView {
    var onClick: (() -> Void)?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea { removeTrackingArea(ta) }
        let ta = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        trackingArea = ta
        addTrackingArea(ta)
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = NSColor(red: 50/255, green: 52/255, blue: 52/255, alpha: 1).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = NSColor(red: 42/255, green: 44/255, blue: 44/255, alpha: 1).cgColor
    }

    override func mouseDown(with event: NSEvent) {
        layer?.backgroundColor = NSColor(red: 28/255, green: 30/255, blue: 30/255, alpha: 1).cgColor
    }

    override func mouseUp(with event: NSEvent) {
        layer?.backgroundColor = NSColor(red: 42/255, green: 44/255, blue: 44/255, alpha: 1).cgColor
        if bounds.contains(convert(event.locationInWindow, from: nil)) {
            onClick?()
        }
    }
}

// MARK: - Clickable action button view

private class ActionButtonView: NSView {
    var onClick: (() -> Void)?
    private let normalBg: CGColor
    private let hoverBg: CGColor
    private var trackingArea: NSTrackingArea?

    init(normalBg: NSColor, hoverBg: NSColor) {
        self.normalBg = normalBg.cgColor
        self.hoverBg  = hoverBg.cgColor
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea { removeTrackingArea(ta) }
        let ta = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        trackingArea = ta
        addTrackingArea(ta)
    }

    override func mouseEntered(with event: NSEvent) { layer?.backgroundColor = hoverBg }
    override func mouseExited(with event: NSEvent)  { layer?.backgroundColor = normalBg }
    override func mouseDown(with event: NSEvent)    { layer?.backgroundColor = normalBg }

    override func mouseUp(with event: NSEvent) {
        layer?.backgroundColor = normalBg
        if bounds.contains(convert(event.locationInWindow, from: nil)) { onClick?() }
    }
}

// MARK: - Controller

class FolderPickerPanelController: NSObject {

    var onFolderSelected: ((URL) -> Void)?
    var onBrowse: (() -> Void)?
    var onSettings: (() -> Void)?
    private(set) var isShowingSuccess = false

    private let panel: FolderPickerPanel
    private let folders: [URL]
    private let sourceURL: URL
    private var monitor: Any?
    private var successTimer: Timer?

    init(sourceURL: URL, folders: [URL]) {
        self.sourceURL = sourceURL
        self.folders   = folders
        self.panel     = FolderPickerPanel()
        super.init()
        buildUI()
    }

    // MARK: - UI Construction

    private func buildUI() {
        let sidePad:      CGFloat = 16
        let rowH:         CGFloat = 40   // Figma: h-[40px]
        let rowGap:       CGFloat = 8
        let titleTopPad:  CGFloat = 16
        let titleH:       CGFloat = 20   // Figma: h-[20px]
        let titleRowGap:  CGFloat = 12   // Figma: gap-[12px] inside the stacked group
        let buttonH:      CGFloat = 32
        let bottomPad:    CGFloat = 16
        let bottomH:      CGFloat = 16 + buttonH + bottomPad
        let count  = folders.count
        let rowsH  = count == 0 ? rowH : CGFloat(count) * rowH + CGFloat(max(count - 1, 0)) * rowGap
        let totalH = titleTopPad + titleH + titleRowGap + rowsH + bottomH
        let totalW: CGFloat = 420

        let container = NSView(frame: NSRect(x: 0, y: 0, width: totalW, height: totalH))
        container.wantsLayer = true
        container.layer?.cornerRadius = 24   // Figma: rounded-[24px]
        container.layer?.masksToBounds = true
        container.layer?.backgroundColor = NSColor(red: 56/255, green: 56/255, blue: 55/255, alpha: 0.96).cgColor
        panel.contentView = container
        panel.setFrame(NSRect(x: 0, y: 0, width: totalW, height: totalH), display: false)

        // Title row — "Select folder" + cog
        let titleLabel = NSTextField(labelWithString: "Select folder")
        titleLabel.textColor = NSColor(red: 253/255, green: 253/255, blue: 253/255, alpha: 1)
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        let cogBtn = NSButton()
        cogBtn.isBordered = false
        cogBtn.image = FolderPickerPanelController.cogSVG()
        cogBtn.target = self
        cogBtn.action = #selector(settingsClicked)
        cogBtn.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(cogBtn)

        // Folder rows
        var rowViews: [NSView] = []
        for (i, folder) in folders.enumerated() {
            let row = makeFolderRow(index: i, folder: folder)
            row.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(row)
            rowViews.append(row)
        }

        // Buttons
        let cancelBtn = makeCancelButton()
        cancelBtn.onClick = { [weak self] in self?.cancelClicked() }
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false

        let browseBtn = makeBrowseButton()
        browseBtn.onClick = { [weak self] in self?.browseClicked() }
        browseBtn.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(cancelBtn)
        container.addSubview(browseBtn)

        // Layout — anchor from bottom upward
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: sidePad),
            titleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor,
                                               constant: -(bottomH + rowsH + titleRowGap)),

            cogBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -sidePad),
            cogBtn.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            cogBtn.widthAnchor.constraint(equalToConstant: 22),
            cogBtn.heightAnchor.constraint(equalToConstant: 22),

            browseBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -sidePad),
            browseBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -bottomPad),
            browseBtn.heightAnchor.constraint(equalToConstant: buttonH),
            browseBtn.widthAnchor.constraint(equalToConstant: 100),

            cancelBtn.trailingAnchor.constraint(equalTo: browseBtn.leadingAnchor, constant: -8),
            cancelBtn.centerYAnchor.constraint(equalTo: browseBtn.centerYAnchor),
            cancelBtn.heightAnchor.constraint(equalToConstant: buttonH),
            cancelBtn.widthAnchor.constraint(equalToConstant: 110),
        ])

        for (i, rowView) in rowViews.enumerated() {
            let distFromBottom = bottomH + CGFloat(rowViews.count - 1 - i) * (rowH + rowGap)
            NSLayoutConstraint.activate([
                rowView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: sidePad),
                rowView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -sidePad),
                rowView.heightAnchor.constraint(equalToConstant: rowH),
                rowView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -distFromBottom),
            ])
        }
    }

    private func makeFolderRow(index: Int, folder: URL) -> NSView {
        let row = FolderRowView(frame: .zero)
        row.wantsLayer = true
        row.layer?.cornerRadius = 20   // pill: 40/2
        row.layer?.backgroundColor = NSColor(red: 42/255, green: 44/255, blue: 44/255, alpha: 1).cgColor
        row.onClick = { [weak self] in self?.selectFolder(at: index) }

        // Number badge
        let badge = NSView()
        badge.wantsLayer = true
        badge.layer?.cornerRadius = 8
        badge.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.1).cgColor
        badge.translatesAutoresizingMaskIntoConstraints = false

        let badgeNum = NSTextField(labelWithString: "\(index + 1)")
        badgeNum.textColor = NSColor(red: 237/255, green: 237/255, blue: 236/255, alpha: 1)
        badgeNum.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        badgeNum.alignment = .center
        badgeNum.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(badgeNum)

        // Path label
        let pathLabel = NSTextField(labelWithString: prettyPath(folder))
        pathLabel.textColor = NSColor(red: 237/255, green: 237/255, blue: 236/255, alpha: 1)
        pathLabel.font = .systemFont(ofSize: 12)
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        row.addSubview(badge)
        row.addSubview(pathLabel)

        NSLayoutConstraint.activate([
            badge.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
            badge.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            badge.widthAnchor.constraint(equalToConstant: 24),
            badge.heightAnchor.constraint(equalToConstant: 24),

            badgeNum.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            badgeNum.centerYAnchor.constraint(equalTo: badge.centerYAnchor),

            pathLabel.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 8),
            pathLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
            pathLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])

        return row
    }

    private func makeCancelButton() -> ActionButtonView {
        let btn = ActionButtonView(
            normalBg: NSColor(red: 42/255, green: 44/255, blue: 44/255, alpha: 1),
            hoverBg:  NSColor(red: 58/255, green: 60/255, blue: 60/255, alpha: 1)
        )
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 16
        btn.layer?.backgroundColor = NSColor(red: 42/255, green: 44/255, blue: 44/255, alpha: 1).cgColor

        let label = NSTextField(labelWithString: "Cancel")
        label.textColor = NSColor(red: 237/255, green: 237/255, blue: 236/255, alpha: 1)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false

        let escBadge = NSView()
        escBadge.wantsLayer = true
        escBadge.layer?.cornerRadius = 8
        escBadge.layer?.backgroundColor = NSColor(red: 63/255, green: 65/255, blue: 65/255, alpha: 1).cgColor
        escBadge.translatesAutoresizingMaskIntoConstraints = false

        let escLabel = NSTextField(labelWithString: "Esc")   // capital E per Figma
        escLabel.textColor = NSColor(red: 237/255, green: 237/255, blue: 236/255, alpha: 1)
        escLabel.font = .systemFont(ofSize: 10, weight: .medium)
        escLabel.alignment = .center
        escLabel.translatesAutoresizingMaskIntoConstraints = false
        escBadge.addSubview(escLabel)

        btn.addSubview(label)
        btn.addSubview(escBadge)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: btn.leadingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: btn.centerYAnchor),

            escBadge.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
            escBadge.trailingAnchor.constraint(equalTo: btn.trailingAnchor, constant: -12),
            escBadge.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
            escBadge.widthAnchor.constraint(equalToConstant: 28),
            escBadge.heightAnchor.constraint(equalToConstant: 22),

            escLabel.centerXAnchor.constraint(equalTo: escBadge.centerXAnchor),
            escLabel.centerYAnchor.constraint(equalTo: escBadge.centerYAnchor),
        ])

        return btn
    }

    private func makeBrowseButton() -> ActionButtonView {
        let btn = ActionButtonView(
            normalBg: NSColor(red: 253/255, green: 253/255, blue: 253/255, alpha: 1),
            hoverBg:  NSColor(red: 220/255, green: 220/255, blue: 220/255, alpha: 1)
        )
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 16
        btn.layer?.backgroundColor = NSColor(red: 253/255, green: 253/255, blue: 253/255, alpha: 1).cgColor

        let label = NSTextField(labelWithString: "Browse")
        label.textColor = NSColor(red: 56/255, green: 56/255, blue: 55/255, alpha: 1)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false

        let slashBadge = NSView()
        slashBadge.wantsLayer = true
        slashBadge.layer?.cornerRadius = 8
        slashBadge.layer?.backgroundColor = NSColor(red: 63/255, green: 65/255, blue: 65/255, alpha: 0.1).cgColor
        slashBadge.translatesAutoresizingMaskIntoConstraints = false

        let slashLabel = NSTextField(labelWithString: "/")
        slashLabel.textColor = NSColor(red: 56/255, green: 56/255, blue: 55/255, alpha: 0.5)
        slashLabel.font = .systemFont(ofSize: 10, weight: .medium)
        slashLabel.alignment = .center
        slashLabel.translatesAutoresizingMaskIntoConstraints = false
        slashBadge.addSubview(slashLabel)

        btn.addSubview(label)
        btn.addSubview(slashBadge)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: btn.leadingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: btn.centerYAnchor),

            slashBadge.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
            slashBadge.trailingAnchor.constraint(equalTo: btn.trailingAnchor, constant: -12),
            slashBadge.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
            slashBadge.widthAnchor.constraint(equalToConstant: 22),
            slashBadge.heightAnchor.constraint(equalToConstant: 22),

            slashLabel.centerXAnchor.constraint(equalTo: slashBadge.centerXAnchor),
            slashLabel.centerYAnchor.constraint(equalTo: slashBadge.centerYAnchor),
        ])

        return btn
    }

    private func prettyPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    // MARK: - Show / Hide

    func showPanel() {
        positionPanel()
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
    }

    func forceClose() {
        successTimer?.invalidate()
        successTimer = nil
        closePanel()
    }

    private func positionPanel() {
        guard let screen = NSScreen.main else { return }
        let x = screen.visibleFrame.midX - panel.frame.width / 2
        let y = screen.visibleFrame.midY - panel.frame.height / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func closePanel() {
        removeKeyMonitor()
        panel.orderOut(nil)
    }

    // MARK: - Success state

    /// Moves anchorPoint to center without visually shifting the layer.
    private func centerAnchor(of layer: CALayer) {
        let b = layer.bounds
        guard b.width > 0, b.height > 0 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.position    = CGPoint(x: b.width / 2, y: b.height / 2)
        CATransaction.commit()
    }

    private func transitionToSuccess() {
        isShowingSuccess = true
        guard let outView = panel.contentView else { return }
        outView.wantsLayer = true
        centerAnchor(of: outView.layer!)

        // Picker out: scale down + fade
        let group = CAAnimationGroup()
        let fade  = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1; fade.toValue = 0
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.0; scale.toValue = 0.88
        group.animations       = [fade, scale]
        group.duration         = 0.13
        group.timingFunction   = CAMediaTimingFunction(name: .easeIn)
        group.fillMode         = .forwards
        group.isRemovedOnCompletion = false
        outView.layer?.add(group, forKey: "pickerOut")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) { [weak self] in
            guard let self else { return }

            // Figma: 93 Hug × 36
            let pillW: CGFloat = 93
            let pillH: CGFloat = 36
            let cx = self.panel.frame.midX, cy = self.panel.frame.midY
            self.panel.setFrame(
                NSRect(x: cx - pillW / 2, y: cy - pillH / 2, width: pillW, height: pillH),
                display: false
            )

            let successView = self.makeSuccessView(height: pillH)
            self.panel.contentView = successView

            DispatchQueue.main.async {
                guard let layer = successView.layer else { return }

                // Ensure layer has green bg + pill shape (may not be set yet if layer was lazy)
                layer.backgroundColor = NSColor(red: 45/255, green: 176/255, blue: 43/255, alpha: 1).cgColor
                layer.cornerRadius    = pillH / 2
                layer.masksToBounds   = true

                self.centerAnchor(of: layer)

                CATransaction.begin()
                CATransaction.setDisableActions(true)
                layer.transform = CATransform3DMakeScale(0.88, 0.88, 1)
                CATransaction.commit()

                let spring = CASpringAnimation(keyPath: "transform")
                spring.fromValue      = CATransform3DMakeScale(0.88, 0.88, 1)
                spring.toValue        = CATransform3DIdentity
                spring.stiffness      = 300
                spring.damping        = 22
                spring.mass           = 1
                spring.initialVelocity = 2
                spring.duration       = spring.settlingDuration
                layer.add(spring, forKey: "successIn")

                CATransaction.begin()
                CATransaction.setDisableActions(true)
                layer.transform = CATransform3DIdentity
                CATransaction.commit()

                self.successTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                    self?.dismissSuccess()
                }
            }
        }
    }

    private func dismissSuccess() {
        guard let view = panel.contentView, let layer = view.layer else { closePanel(); return }
        centerAnchor(of: layer)

        let group = CAAnimationGroup()
        let fade  = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1; fade.toValue = 0
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.0; scale.toValue = 0.88
        group.animations       = [fade, scale]
        group.duration         = 0.18
        group.timingFunction   = CAMediaTimingFunction(name: .easeIn)
        group.fillMode         = .forwards
        group.isRemovedOnCompletion = false
        layer.add(group, forKey: "successOut")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in self?.closePanel() }
    }

    private func makeSuccessView(height: CGFloat) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius  = height / 2   // 36/2 = 18, full pill
        view.layer?.masksToBounds = true
        view.layer?.backgroundColor = NSColor(red: 45/255, green: 176/255, blue: 43/255, alpha: 1).cgColor

        // Icon — Figma: lucide/circle-check, 20×20, white
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
        icon.contentTintColor = .white
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: "Saved")
        label.textColor = NSColor(red: 253/255, green: 253/255, blue: 253/255, alpha: 1)
        label.font = .systemFont(ofSize: 14, weight: .medium)

        let stack = NSStackView(views: [icon, label])
        stack.orientation = .horizontal
        stack.spacing = 8   // Figma: gap-[8px]
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 20),    // Figma: size-[20px]
            icon.heightAnchor.constraint(equalToConstant: 20),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        return view
    }

    // MARK: - Keyboard monitor

    private func installKeyMonitor() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleKeyEvent(event)
        }
    }

    private func removeKeyMonitor() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        switch event.keyCode {
        case 53: cancelClicked(); return nil
        case 44: browseClicked(); return nil
        case 18, 19, 20, 21, 23, 22, 26, 28, 25: // 1–9
            let indexMap: [UInt16: Int] = [18:0, 19:1, 20:2, 21:3, 23:4, 22:5, 26:6, 28:7, 25:8]
            if let idx = indexMap[event.keyCode], idx < folders.count { selectFolder(at: idx) }
            return nil
        default: return event
        }
    }

    // MARK: - Actions

    private static func cogSVG() -> NSImage? {
        let svg = """
        <svg width="22" height="22" viewBox="0 0 22 22" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M10.0833 9.41416L6.41668 3.06166M10.0833 12.5858L6.41668 18.9383M11 20.1667V18.3333M11 18.3333C15.0501 18.3333 18.3333 15.0501 18.3333 11C18.3333 6.94991 15.0501 3.66666 11 3.66666M11 18.3333C6.94992 18.3333 3.66668 15.0501 3.66668 11M11 1.83333V3.66666M11 3.66666C6.94992 3.66666 3.66668 6.94991 3.66668 11M12.8333 11H20.1667M12.8333 11C12.8333 12.0125 12.0125 12.8333 11 12.8333C9.98749 12.8333 9.16668 12.0125 9.16668 11C9.16668 9.98747 9.98749 9.16666 11 9.16666C12.0125 9.16666 12.8333 9.98747 12.8333 11ZM15.5833 18.9383L14.6667 17.3525M15.5833 3.06166L14.6667 4.6475M1.83334 11H3.66668M18.9383 15.5833L17.3525 14.6667M18.9383 6.41666L17.3525 7.33333M3.06168 15.5833L4.64751 14.6667M3.06168 6.41666L4.64751 7.33333" stroke="#FDFDFD" stroke-width="1.83333" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
        """
        guard let data = svg.data(using: .utf8) else { return nil }
        return NSImage(data: data)
    }

    @objc private func settingsClicked() { onSettings?() }
    @objc private func browseClicked() { closePanel(); onBrowse?() }

    @objc private func cancelClicked() {
        closePanel()
        try? FileManager.default.removeItem(at: sourceURL)
    }

    private func selectFolder(at index: Int) {
        guard index < folders.count else { return }
        removeKeyMonitor()
        onFolderSelected?(folders[index])
        transitionToSuccess()
    }
}
