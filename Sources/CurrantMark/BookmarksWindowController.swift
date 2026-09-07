import AppKit
import CurrantMarkCore

@MainActor
final class BookmarksWindowController: NSWindowController, NSTableViewDataSource,
    NSTableViewDelegate {
    private enum CellIdentifier {
        static let bookmark = NSUserInterfaceItemIdentifier("BookmarkCell")
    }

    private let tableView = NSTableView()
    private let removeButton = NSButton()
    private var bookmarks: [DocumentBookmark] = []

    var onOpen: ((DocumentBookmark) -> Void)?
    var onRemove: ((DocumentBookmark) -> Void)?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Bookmarks"
        window.minSize = NSSize(width: 360, height: 240)
        window.setFrameAutosaveName("CurrantMark.BookmarksWindow")
        // Frame position/size is already persisted via the autosave name
        // above; disabling restoration avoids the table view appearing
        // pre-focused on first display.
        window.isRestorable = false
        super.init(window: window)

        let column = NSTableColumn(identifier: CellIdentifier.bookmark)
        column.title = "Bookmark"
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 30
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(openSelection(_:))

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        removeButton.title = "Remove"
        removeButton.bezelStyle = .rounded
        removeButton.target = self
        removeButton.action = #selector(removeSelection(_:))
        removeButton.isEnabled = false
        removeButton.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView()
        contentView.addSubview(scrollView)
        contentView.addSubview(removeButton)
        window.contentView = contentView

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: removeButton.topAnchor, constant: -8),
            removeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            removeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])

        // When initialFirstResponder is left nil, AppKit auto-generates a
        // key view loop the first time the window is shown and assigns
        // initial first-responder status to the first control in that loop
        // (here, the table view), independent of any makeFirstResponder call
        // made here during init on the still-offscreen window. Pointing
        // initialFirstResponder at the inert contentView prevents the table
        // view from picking up a focus ring merely by being first in the
        // auto-computed loop.
        window.initialFirstResponder = contentView
        // Guarantee no control appears pre-focused when the window is first
        // shown, regardless of window state restoration.
        window.makeFirstResponder(nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(bookmarks: [DocumentBookmark]) {
        self.bookmarks = bookmarks.sorted { $0.createdAt > $1.createdAt }
        tableView.reloadData()
        updateRemoveButton()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        bookmarks.count
    }

    func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        let cell = tableView.makeView(
            withIdentifier: CellIdentifier.bookmark,
            owner: self
        ) as? NSTableCellView ?? makeCell()
        let bookmark = bookmarks[row]
        cell.textField?.stringValue = "\(bookmark.title) — \(bookmark.documentURL.lastPathComponent)"
        cell.toolTip = bookmark.textExcerpt
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateRemoveButton()
    }

    private func makeCell() -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = CellIdentifier.bookmark
        let label = NSTextField(labelWithString: "")
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.textField = label
        cell.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }

    private func updateRemoveButton() {
        removeButton.isEnabled = bookmarks.indices.contains(tableView.selectedRow)
    }

    @objc private func openSelection(_ sender: Any?) {
        guard bookmarks.indices.contains(tableView.selectedRow) else { return }
        onOpen?(bookmarks[tableView.selectedRow])
    }

    @objc private func removeSelection(_ sender: Any?) {
        guard bookmarks.indices.contains(tableView.selectedRow) else { return }
        onRemove?(bookmarks[tableView.selectedRow])
    }
}
