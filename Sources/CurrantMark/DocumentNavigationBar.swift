import AppKit
import CurrantMarkCore

/// Direction to move keyboard focus between breadcrumb segments.
private enum BreadcrumbFocusDirection {
    case previous
    case next
}

@MainActor
final class DocumentNavigationBar: NSView {
    var onSelectHistoryItem: ((Int) -> Void)?
    var onSelectLink: ((URL) -> Void)?
    /// Called whenever a breadcrumb interaction ends (Escape, a link
    /// dropdown closing, or Return navigating) so the caller can hand
    /// keyboard focus back to the document content.
    var onRequestMainPaneFocus: (() -> Void)?

    private var segments: [BreadcrumbButton] = []
    private var selectedIndex: Int?
    private var hoveredIndex: Int?
    /// The URL each segment represents, in the same order as `segments`.
    private var historyItems: [URL] = []
    /// Links discovered the last time each URL was rendered. Populated
    /// incrementally as documents are visited, so a segment for a document
    /// that isn't currently loaded can still show the links it had the last
    /// time it was open.
    private var linksByURL: [URL: [DocumentLink]] = [:]
    /// The links currently shown in the link-dropdown menu, so
    /// `selectLink(_:)` can resolve the tapped item back to a URL. Only
    /// meaningful while a menu popped up by `showLinks(_:from:)` is open.
    private var activeMenuLinks: [DocumentLink] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        heightAnchor.constraint(equalToConstant: 30).isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(document: RenderedDocument, documentURL: URL, fallbackTitle _: String) {
        linksByURL[documentURL] = document.index.links
        updateSegmentAppearance()
    }

    /// Moves keyboard focus to the current-document segment (or the last
    /// segment if none is marked current), so a shortcut can bring the
    /// breadcrumb bar into keyboard focus without the user needing to Tab
    /// through the whole window.
    func focusCurrentSegment() {
        guard !segments.isEmpty else { return }
        let index = selectedIndex ?? segments.count - 1
        window?.makeFirstResponder(segments[index])
    }

    func updateHistory(_ history: DocumentNavigationHistory) {
        selectedIndex = history.selectedIndex
        historyItems = history.items
        segments.forEach { $0.removeFromSuperview() }
        segments = history.items.enumerated().map { index, url in
            let segment = BreadcrumbButton(
                title: url.deletingPathExtension().lastPathComponent,
                index: index
            )
            segment.target = self
            segment.action = #selector(selectSegment(_:))
            segment.onHover = { [weak self] isHovered in
                self?.setHovered(isHovered ? index : nil)
            }
            segment.onMoveFocus = { [weak self] direction in
                self?.moveFocus(from: index, direction: direction)
            }
            segment.onToggleExpand = { [weak self, weak segment] in
                guard let self, let segment else { return }
                self.toggleExpand(atSegment: index, sender: segment)
            }
            segment.onCommandClick = { [weak self, weak segment] in
                guard let self, let segment else { return }
                self.toggleExpand(atSegment: index, sender: segment)
            }
            segment.onActivate = { [weak self] in
                self?.onSelectHistoryItem?(index)
            }
            segment.onEscape = { [weak self] in
                self?.onRequestMainPaneFocus?()
            }
            addSubview(segment)
            return segment
        }
        updateSegmentAppearance()
        needsLayout = true
    }

    /// The links known for the document at the given segment index, if any
    /// have been recorded (via `update(document:documentURL:fallbackTitle:)`).
    private func links(atSegment index: Int) -> [DocumentLink]? {
        guard historyItems.indices.contains(index) else { return nil }
        return linksByURL[historyItems[index]]
    }

    /// Shows the link dropdown for the segment at `index`, if it has any
    /// links. Never navigates and never changes keyboard focus -- shared by
    /// Space (`onToggleExpand`) and Command-click (`onCommandClick`).
    private func toggleExpand(atSegment index: Int, sender: BreadcrumbButton) {
        guard let links = links(atSegment: index), !links.isEmpty else { return }
        showLinks(links, from: sender)
    }

    override func layout() {
        super.layout()
        layoutSegments()
    }

    private func updateSegmentAppearance() {
        for (index, segment) in segments.enumerated() {
            segment.isCurrent = index == selectedIndex
            segment.showsDisclosure = !(links(atSegment: index) ?? []).isEmpty
        }
    }

    /// Moves keyboard focus from the segment at `index` to its previous or
    /// next neighbor, clamped to the segment range.
    private func moveFocus(from index: Int, direction: BreadcrumbFocusDirection) {
        guard !segments.isEmpty else { return }
        let nextIndex = direction == .previous ? index - 1 : index + 1
        guard segments.indices.contains(nextIndex) else { return }
        window?.makeFirstResponder(segments[nextIndex])
    }

    private func setHovered(_ index: Int?) {
        guard hoveredIndex != index else { return }
        hoveredIndex = index
        if let index {
            addSubview(segments[index], positioned: .above, relativeTo: nil)
        }
        animateHoverExpansion()
    }

    private func layoutSegments() {
        guard !segments.isEmpty else { return }

        for (segment, frame) in zip(segments, stableFrames()) {
            segment.layer?.zPosition = 0
            segment.frame = frame
        }
    }

    private func stableFrames() -> [NSRect] {
        let spacing: CGFloat = -8
        let horizontalInset: CGFloat = 10
        let overlap = spacing * CGFloat(segments.count - 1)
        let availableWidth = max(0, bounds.width - (horizontalInset * 2) - overlap)
        let widths = fittedWidths(
            preferredWidths: segments.map(\.idealWidth),
            availableWidth: availableWidth
        )
        var x = horizontalInset
        return widths.map { width in
            defer { x += width + spacing }
            return NSRect(x: x, y: 3, width: width, height: 24)
        }
    }

    private func fittedWidths(
        preferredWidths: [CGFloat],
        availableWidth: CGFloat
    ) -> [CGFloat] {
        guard preferredWidths.reduce(0, +) > availableWidth else {
            return preferredWidths
        }

        var widths = Array(repeating: CGFloat.zero, count: preferredWidths.count)
        var remainingIndices = Array(preferredWidths.indices)
        var remainingWidth = availableWidth

        while !remainingIndices.isEmpty {
            let equalShare = remainingWidth / CGFloat(remainingIndices.count)
            let fittingIndices = remainingIndices.filter { preferredWidths[$0] <= equalShare }
            guard !fittingIndices.isEmpty else {
                for index in remainingIndices {
                    widths[index] = max(1, equalShare)
                }
                break
            }
            for index in fittingIndices {
                widths[index] = preferredWidths[index]
                remainingWidth -= preferredWidths[index]
            }
            remainingIndices.removeAll { fittingIndices.contains($0) }
        }
        return widths
    }

    private func animateHoverExpansion() {
        let frames = stableFrames()
        guard frames.count == segments.count else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            for (index, segment) in segments.enumerated() {
                segment.layer?.zPosition = index == hoveredIndex ? 1 : 0
                var frame = frames[index]
                if index == hoveredIndex, frame.width < segment.idealWidth {
                    let expandedWidth = min(segment.idealWidth, bounds.width - 20)
                    frame.origin.x = max(10, min(frame.minX, bounds.width - 10 - expandedWidth))
                    frame.size.width = expandedWidth
                }
                segment.animator().frame = frame
            }
        }
    }

    @objc private func selectSegment(_ sender: BreadcrumbButton) {
        // Clicking the current segment can't navigate anywhere new, so it
        // shows that document's links instead, if any exist. Clicking any
        // other segment navigates to it directly, matching the primary
        // breadcrumb behavior. To view an older document's links without
        // navigating away, keyboard-focus its segment and press Space.
        if sender.index == selectedIndex, let links = links(atSegment: sender.index), !links.isEmpty {
            showLinks(links, from: sender)
        } else {
            onSelectHistoryItem?(sender.index)
        }
    }

    private func showLinks(_ links: [DocumentLink], from sender: NSButton) {
        activeMenuLinks = links
        let menu = NSMenu(title: "Document Links")
        for (index, link) in links.enumerated() {
            let item = NSMenuItem(
                title: link.title,
                action: #selector(selectLink(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = index
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.minY), in: sender)
        // popUp(...) blocks until the menu closes, whether a link was
        // picked or the menu was dismissed. Keyboard focus intentionally
        // stays on the breadcrumb segment either way: if a link was picked,
        // selectLink(_:) already kicked off navigation, and that navigation
        // path (see MainWindowController.navigate/followLink) moves focus
        // to the main pane once the new content finishes loading; if the
        // menu was just dismissed, the user is still browsing the
        // breadcrumb and shouldn't be knocked out of it.
    }

    @objc private func selectLink(_ sender: NSMenuItem) {
        guard activeMenuLinks.indices.contains(sender.tag) else { return }
        onSelectLink?(activeMenuLinks[sender.tag].url)
    }
}

@MainActor
private final class BreadcrumbButton: NSButton {
    /// Raw virtual key codes for the arrow keys this button handles
    /// specially. AppKit has no symbolic constants for these; the values
    /// are the standard ANSI keyboard virtual key codes widely relied upon
    /// for NSEvent.keyCode checks.
    private enum KeyCode {
        static let leftArrow: UInt16 = 123
        static let rightArrow: UInt16 = 124
        static let space: UInt16 = 49
        static let returnKey: UInt16 = 36
        static let escape: UInt16 = 53
    }

    let index: Int
    var onHover: ((Bool) -> Void)?
    var onMoveFocus: ((BreadcrumbFocusDirection) -> Void)?
    /// Called when Space is pressed while this segment has keyboard focus.
    /// Unlike the button's normal click action, this never navigates away:
    /// it only opens the link dropdown when one is available, otherwise it
    /// does nothing so focus stays on the segment.
    var onToggleExpand: (() -> Void)?
    /// Called when this segment is Command-clicked. Behaves like
    /// `onToggleExpand`: opens the link dropdown if one is available,
    /// without navigating and without changing keyboard focus. A plain
    /// click still navigates (or, for the current segment, opens the
    /// dropdown via the button's normal action).
    var onCommandClick: (() -> Void)?
    /// Called when Return is pressed while this segment has keyboard
    /// focus. Always selects/navigates to this segment, regardless of
    /// whether it has a link dropdown -- Return never opens or closes the
    /// dropdown, only Space does that.
    var onActivate: (() -> Void)?
    /// Called when Escape is pressed while this segment has keyboard
    /// focus, so focus can move back to the document content.
    var onEscape: (() -> Void)?
    var isCurrent = false {
        didSet { needsDisplay = true }
    }
    var showsDisclosure = false {
        didSet { needsDisplay = true }
    }

    var idealWidth: CGFloat {
        let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        let titleWidth = (title as NSString).size(withAttributes: [.font: font]).width
        return ceil(titleWidth) + 42
    }

    init(title: String, index: Int) {
        self.index = index
        super.init(frame: .zero)
        self.title = title
        isBordered = false
        wantsLayer = true
        font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        lineBreakMode = .byTruncatingMiddle
        toolTip = title
        setAccessibilityLabel(title)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        // .assumeInside makes the first synthesized event (posted whenever a
        // tracking area is installed while the cursor happens to already be
        // inside its rect, e.g. at launch) an exit rather than an enter, so
        // installing this tracking area never spuriously triggers the
        // hover-expand animation with no real mouse movement.
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .assumeInside],
            owner: self
        ))
    }

    override func mouseDown(with event: NSEvent) {
        guard event.modifierFlags.contains(.command) else {
            super.mouseDown(with: event)
            return
        }
        // Intercept Command-click entirely instead of letting it fall
        // through to the normal button tracking (which would send the
        // click action on mouse-up and could navigate away).
        onCommandClick?()
    }

    override func mouseEntered(with event: NSEvent) {
        onHover?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHover?(false)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case KeyCode.leftArrow:
            onMoveFocus?(.previous)
        case KeyCode.rightArrow:
            onMoveFocus?(.next)
        case KeyCode.space:
            // Handle Space directly instead of falling through to the
            // default NSButton behavior, which would send the click action
            // and navigate away (rebuilding the segments and losing
            // focus) for a non-current segment. Space should only ever
            // toggle the link dropdown, never navigate.
            onToggleExpand?()
        case KeyCode.returnKey:
            // Return always selects/navigates to this segment. It never
            // opens or closes the link dropdown -- that is Space's job.
            onActivate?()
        case KeyCode.escape:
            onEscape?()
        default:
            super.keyDown(with: event)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath()
        let pointWidth: CGFloat = 10
        path.move(to: NSPoint(x: 0, y: 0))
        path.line(to: NSPoint(x: bounds.maxX - pointWidth, y: 0))
        path.line(to: NSPoint(x: bounds.maxX, y: bounds.midY))
        path.line(to: NSPoint(x: bounds.maxX - pointWidth, y: bounds.maxY))
        path.line(to: NSPoint(x: 0, y: bounds.maxY))
        path.line(to: NSPoint(x: pointWidth, y: bounds.midY))
        path.close()

        (isCurrent ? NSColor.controlAccentColor.withAlphaComponent(0.18) : .controlBackgroundColor)
            .setFill()
        path.fill()
        NSColor.separatorColor.setStroke()
        path.stroke()
        super.draw(dirtyRect)

        if showsDisclosure {
            let chevron = NSImage(
                systemSymbolName: "chevron.down",
                accessibilityDescription: "Show document links"
            )
            chevron?.draw(in: NSRect(
                x: bounds.maxX - 24,
                y: bounds.midY - 5,
                width: 10,
                height: 10
            ))
        }
    }
}
