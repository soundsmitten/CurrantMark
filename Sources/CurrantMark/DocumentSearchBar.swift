import AppKit

@MainActor
final class DocumentSearchBar: NSView, NSSearchFieldDelegate {
    var onSearch: ((String, Bool) -> Void)?
    var onClose: (() -> Void)?

    private let searchField = FindSearchField()
    private let navigationControl = NSSegmentedControl(
        labels: ["", ""],
        trackingMode: .momentary,
        target: nil,
        action: nil
    )
    private let resultLabel = NSTextField(labelWithString: "")
    private var matchCount = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        searchField.placeholderString = "Find"
        searchField.sendsSearchStringImmediately = true
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(findNext(_:))
        searchField.onCancel = { [weak self] in self?.onClose?() }

        navigationControl.segmentStyle = .rounded
        navigationControl.target = self
        navigationControl.action = #selector(navigateMatches(_:))
        navigationControl.setImage(
            NSImage(
                systemSymbolName: "chevron.left",
                accessibilityDescription: "Previous Match"
            ),
            forSegment: 0
        )
        navigationControl.setImage(
            NSImage(
                systemSymbolName: "chevron.right",
                accessibilityDescription: "Next Match"
            ),
            forSegment: 1
        )
        navigationControl.setToolTip("Previous Match", forSegment: 0)
        navigationControl.setToolTip("Next Match", forSegment: 1)
        navigationControl.setWidth(32, forSegment: 0)
        navigationControl.setWidth(32, forSegment: 1)

        let doneButton = NSButton(title: "Done", target: self, action: #selector(close(_:)))
        doneButton.bezelStyle = .rounded

        resultLabel.textColor = .secondaryLabelColor
        resultLabel.alignment = .right
        resultLabel.drawsBackground = true
        resultLabel.backgroundColor = .controlBackgroundColor
        resultLabel.translatesAutoresizingMaskIntoConstraints = false
        searchField.addSubview(resultLabel)

        let stack = NSStackView(views: [searchField, navigationControl, doneButton])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        searchField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        searchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 240).isActive = true
        NSLayoutConstraint.activate([
            resultLabel.trailingAnchor.constraint(equalTo: searchField.trailingAnchor, constant: -28),
            resultLabel.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            resultLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 72),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        updateControls()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func focus() {
        window?.makeFirstResponder(searchField)
        searchField.selectText(nil)
    }

    func update(matchCount: Int, for query: String) {
        guard query == searchField.stringValue else { return }
        self.matchCount = matchCount
        if matchCount > 0 {
            resultLabel.stringValue = matchCount == 1
                ? "1 match"
                : "\(matchCount) matches"
        } else {
            resultLabel.stringValue = ""
        }
        updateControls()
    }

    func controlTextDidChange(_ notification: Notification) {
        matchCount = 0
        resultLabel.stringValue = ""
        updateControls()
        onSearch?(searchField.stringValue, false)
    }

    private func updateControls() {
        navigationControl.isEnabled = matchCount > 0
    }

    @objc private func findNext(_ sender: Any?) {
        onSearch?(searchField.stringValue, false)
    }

    @objc private func navigateMatches(_ sender: NSSegmentedControl) {
        onSearch?(searchField.stringValue, sender.selectedSegment == 0)
    }

    @objc private func close(_ sender: Any?) {
        onClose?()
    }
}

@MainActor
private final class FindSearchField: NSSearchField {
    var onCancel: (() -> Void)?

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
