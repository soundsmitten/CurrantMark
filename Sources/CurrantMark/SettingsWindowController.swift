import AppKit
import CurrantMarkCore

@MainActor
final class SettingsWindowController: NSWindowController {
    private let preferences: AppPreferences
    private let openPanelCheckbox: NSButton

    init(preferences: AppPreferences) {
        self.preferences = preferences
        openPanelCheckbox = NSButton(
            checkboxWithTitle: "Automatically show Open dialog when no documents are open",
            target: nil,
            action: nil
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 150),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()
        window.isReleasedWhenClosed = false
        // This is a small utility window with no state worth restoring
        // across launches; state restoration is also the likely cause of
        // the checkbox appearing pre-focused on first display.
        window.isRestorable = false
        super.init(window: window)

        openPanelCheckbox.state = preferences.automaticallyShowsOpenPanelWhenNoDocumentsAreOpen
            ? .on
            : .off
        openPanelCheckbox.target = self
        openPanelCheckbox.action = #selector(openPanelPreferenceChanged(_:))

        let explanation = NSTextField(
            wrappingLabelWithString: "When disabled, use File > Open or Command-O to choose a document."
        )
        explanation.textColor = .secondaryLabelColor

        let stackView = NSStackView(views: [openPanelCheckbox, explanation])
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView()
        contentView.addSubview(stackView)
        window.contentView = contentView
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -24),
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])

        // When initialFirstResponder is left nil, AppKit auto-generates a
        // key view loop the first time the window is shown and assigns
        // initial first-responder status to the first control in that loop
        // (here, the checkbox), independent of any makeFirstResponder call
        // made here during init on the still-offscreen window. Pointing
        // initialFirstResponder at the inert contentView prevents the
        // checkbox from picking up a focus ring merely by being first (and
        // only) in the auto-computed loop.
        window.initialFirstResponder = contentView
        // Guarantee no control appears pre-focused when the window is first
        // shown, regardless of window state restoration.
        window.makeFirstResponder(nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func openPanelPreferenceChanged(_ sender: NSButton) {
        preferences.automaticallyShowsOpenPanelWhenNoDocumentsAreOpen = sender.state == .on
    }
}
