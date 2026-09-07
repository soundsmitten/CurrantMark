import AppKit
import CurrantMarkCore

@MainActor
final class DocumentNavigationBar: NSView {
    var onSelectHistoryItem: ((Int) -> Void)?
    var onSelectLink: ((URL) -> Void)?

    private var segments: [BreadcrumbButton] = []
    private var selectedIndex: Int?
    private var hoveredIndex: Int?
    private var links: [DocumentLink] = []

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

    func update(document: RenderedDocument, fallbackTitle _: String) {
        links = document.index.links
        updateSegmentAppearance()
    }

    func updateHistory(_ history: DocumentNavigationHistory) {
        selectedIndex = history.selectedIndex
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
            addSubview(segment)
            return segment
        }
        updateSegmentAppearance()
        needsLayout = true
    }

    override func layout() {
        super.layout()
        layoutSegments()
    }

    private func updateSegmentAppearance() {
        for (index, segment) in segments.enumerated() {
            let isCurrent = index == selectedIndex
            segment.isCurrent = isCurrent
            segment.showsDisclosure = isCurrent && !links.isEmpty
        }
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
        if sender.index == selectedIndex, !links.isEmpty {
            showLinks(from: sender)
        } else {
            onSelectHistoryItem?(sender.index)
        }
    }

    private func showLinks(from sender: NSButton) {
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
    }

    @objc private func selectLink(_ sender: NSMenuItem) {
        guard links.indices.contains(sender.tag) else { return }
        onSelectLink?(links[sender.tag].url)
    }
}

@MainActor
private final class BreadcrumbButton: NSButton {
    let index: Int
    var onHover: ((Bool) -> Void)?
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

    override func mouseEntered(with event: NSEvent) {
        onHover?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHover?(false)
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
