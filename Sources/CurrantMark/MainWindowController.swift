import AppKit
import CurrantMarkCore
import UniformTypeIdentifiers

@MainActor
final class MainWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate,
    NSToolbarItemValidation {
    private enum ToolbarItemIdentifier {
        static let back = NSToolbarItem.Identifier("CurrantMark.Back")
        static let forward = NSToolbarItem.Identifier("CurrantMark.Forward")
    }

    private let previewGroup = DocumentPreviewGroup(frame: .zero)
    private let navigationBar = DocumentNavigationBar(frame: .zero)
    private let bookmarkController: BookmarkController
    private let processor: MarkdownProcessor
    private let pdfExporter: PDFExporter
    private var navigationHistory = DocumentNavigationHistory()
    private var source: DocumentSource?
    private var style: RenderStyle
    private var currentDocument: RenderedDocument?
    private var securityScopedURL: URL?
    var onClose: (() -> Void)?
    var onBookmarksChanged: (() -> Void)?
    var onDuplicate: ((URL) -> Void)?

    var documentURL: URL? {
        source?.documentURL
    }

    init(
        bookmarkController: BookmarkController,
        processor: MarkdownProcessor? = nil,
        pdfExporter: PDFExporter? = nil
    ) {
        self.bookmarkController = bookmarkController
        self.processor = processor ?? SwiftMarkdownProcessor()
        self.pdfExporter = pdfExporter ?? WebKitPDFExporter()
        let stylesheet = Bundle.main.url(forResource: "Style", withExtension: "css")
            .flatMap { try? String(contentsOf: $0) }
        style = stylesheet.map(RenderStyle.init(stylesheet:)) ?? .bundled
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.titleVisibility = .visible
        window.center()
        super.init(window: window)
        let contentView = NSView()
        navigationBar.translatesAutoresizingMaskIntoConstraints = false
        previewGroup.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(navigationBar)
        contentView.addSubview(previewGroup)
        window.contentView = contentView
        NSLayoutConstraint.activate([
            navigationBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            navigationBar.topAnchor.constraint(equalTo: contentView.topAnchor),
            previewGroup.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            previewGroup.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            previewGroup.topAnchor.constraint(equalTo: navigationBar.bottomAnchor),
            previewGroup.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        window.backgroundColor = .textBackgroundColor
        window.minSize = NSSize(width: 480, height: 320)
        window.delegate = self
        previewGroup.onLinkActivated = { [weak self] url in
            self?.followLink(to: url)
        }
        previewGroup.onBookmarkActivated = { [weak self] anchor in
            self?.toggleBookmark(at: anchor)
        }
        navigationBar.onSelectLink = { [weak self] url in
            self?.followLink(to: url)
        }
        navigationBar.onSelectHistoryItem = { [weak self] url in
            self?.navigate(to: url, recording: .unrelated)
        }
        navigationBar.onRequestMainPaneFocus = { [weak self] in
            self?.previewGroup.focusActivePane()
        }

        let toolbar = NSToolbar(identifier: "CurrantMark.DocumentToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
        window.toolbarStyle = .unified

        // When initialFirstResponder is left nil, AppKit auto-generates a
        // key view loop the first time the window is shown and assigns
        // initial first-responder status to the first control in that loop
        // (e.g. a breadcrumb segment), independent of any makeFirstResponder
        // call made here during init on the still-offscreen window. Pointing
        // initialFirstResponder at the inert contentView prevents any real
        // control from picking up a focus ring merely by being first in the
        // auto-computed loop.
        window.initialFirstResponder = contentView
        // Guarantee no control (e.g. the breadcrumb bar) appears
        // pre-focused/hovered when the window is first shown, regardless
        // of window state restoration.
        window.makeFirstResponder(nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// How a navigation should be recorded in the window's chronological
    /// history and ancestor tree. See `DocumentNavigationHistory` for why
    /// these are two separate concerns.
    private enum HistoryRecording {
        /// The chronological pointer was already moved by the caller
        /// (Back or Forward); don't record a new visit.
        case none
        /// A genuine parent -> child step, such as following a link or
        /// picking a file from a folder link's picker.
        case link
        /// Navigation with no inherent relationship to the document
        /// currently being viewed, such as opening a bookmark, a
        /// breadcrumb-segment click, or a file from File -> Open.
        case unrelated
    }

    func open(url: URL) {
        navigate(to: url, recording: .unrelated)
    }

    private func navigate(to url: URL, recording: HistoryRecording) {
        let documentURL = url.removingFragment
        source?.stopWatching()
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = documentURL.startAccessingSecurityScopedResource()
            ? documentURL
            : nil
        let newSource = FileDocumentSource(url: documentURL)
        source = newSource
        window?.title = documentURL.lastPathComponent
        window?.representedURL = documentURL
        switch recording {
        case .none:
            break
        case .link:
            navigationHistory.visit(url, linkedFromCurrent: true)
        case .unrelated:
            navigationHistory.visit(url, linkedFromCurrent: false)
        }
        navigationBar.updateHistory(navigationHistory)
        window?.toolbar?.validateVisibleItems()
        loadCurrentDocument(preservingScroll: false) { [weak self] in
            self?.showWindow(nil)
            if let anchor = url.fragment {
                self?.previewGroup.scrollToAnchor(anchor)
            }
            self?.previewGroup.focusActivePane()
        }
        newSource.startWatching { [weak self] in self?.loadCurrentDocument(preservingScroll: true) }
    }

    @objc private func goBack(_ sender: Any?) {
        guard let url = navigationHistory.goBack() else { return }
        navigate(to: url, recording: .none)
    }

    @objc private func goForward(_ sender: Any?) {
        guard let url = navigationHistory.goForward() else { return }
        navigate(to: url, recording: .none)
    }

    private func followLink(to url: URL) {
        guard url.isFileURL else {
            NSWorkspace.shared.open(url)
            return
        }

        if url.isDirectory {
            openMarkdownFile(in: url)
        } else if Self.markdownExtensions.contains(url.pathExtension.lowercased()) {
            if url.removingFragment == documentURL, let anchor = url.fragment {
                previewGroup.scrollToAnchor(anchor)
                previewGroup.focusActivePane()
            } else {
                navigate(to: url.standardizedFileURL, recording: .link)
            }
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    private func openMarkdownFile(in directoryURL: URL) {
        guard let window else { return }
        let panel = NSOpenPanel()
        panel.directoryURL = directoryURL
        panel.allowedContentTypes = ["md", "markdown", "mdown", "mkdn"]
            .compactMap { UTType(filenameExtension: $0) }
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.navigate(to: url, recording: .link)
        }
    }

    func toggleBookmarkAtReadingPosition() {
        previewGroup.currentHeadingAnchor { [weak self] anchor in
            guard let anchor else {
                NSSound.beep()
                return
            }
            self?.toggleBookmark(at: anchor)
        }
    }

    func open(bookmark: DocumentBookmark) {
        let resolvedURL = bookmarkController.resolvedURL(for: bookmark)
        if resolvedURL.standardizedFileURL == documentURL {
            previewGroup.scrollToAnchor(bookmark.anchor)
            return
        }
        var components = URLComponents(
            url: resolvedURL,
            resolvingAgainstBaseURL: false
        )
        components?.fragment = bookmark.anchor
        navigate(
            to: components?.url ?? bookmark.documentURL,
            recording: .unrelated
        )
    }

    func refreshBookmarks() {
        guard let documentURL else {
            previewGroup.setBookmarkedAnchors([])
            return
        }
        let anchors = bookmarkController.bookmarks(for: documentURL).map(\.anchor)
        previewGroup.setBookmarkedAnchors(Set(anchors))
    }

    func toggleSplit() {
        previewGroup.toggleSplit()
    }

    var isSplit: Bool {
        previewGroup.isSplit
    }

    func focusNavigationBar() {
        navigationBar.focusCurrentSegment()
    }

    func cyclePaneFocus() {
        previewGroup.cycleFocus()
    }

    func showFind() {
        previewGroup.showFindInterface()
    }

    func makeContentLarger() {
        previewGroup.makeContentLarger()
    }

    func makeContentSmaller() {
        previewGroup.makeContentSmaller()
    }

    func resetContentSize() {
        previewGroup.resetContentSize()
    }

    func duplicateDocumentWindow() {
        guard let documentURL else { return }
        onDuplicate?(documentURL)
    }

    private func toggleBookmark(at anchor: String) {
        guard let documentURL,
              let heading = currentDocument?.index.headings.first(where: {
                  $0.anchor == anchor
              }) else {
            return
        }
        do {
            try bookmarkController.toggle(documentURL: documentURL, heading: heading)
            onBookmarksChanged?()
        } catch {
            present(error: error)
        }
    }

    @objc func exportPDF(_ sender: Any?) {
        guard let documentURL = source?.documentURL, let document = currentDocument else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = documentURL.deletingPathExtension().lastPathComponent + ".pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        pdfExporter.export(document: document, to: url) { [weak self] error in
            if let error { self?.present(error: error) }
        }
    }

    private func loadCurrentDocument(
        preservingScroll: Bool,
        completion: (() -> Void)? = nil
    ) {
        guard let source else { return }
        do {
            let input = try source.load()
            let document = try processor.render(
                markdown: input.contents,
                style: style,
                baseURL: input.url
            )
            currentDocument = document
            navigationBar.update(
                document: document,
                documentURL: input.url,
                fallbackTitle: input.url.lastPathComponent
            )
            refreshBookmarks()
            previewGroup.load(
                document,
                preservingScroll: preservingScroll,
                completion: completion
            )
        } catch { present(error: error) }
    }

    func windowWillClose(_ notification: Notification) {
        source?.stopWatching()
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
        onClose?()
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [ToolbarItemIdentifier.back, ToolbarItemIdentifier.forward]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [ToolbarItemIdentifier.back, ToolbarItemIdentifier.forward]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case ToolbarItemIdentifier.back:
            return makeToolbarItem(
                identifier: itemIdentifier,
                label: "Back",
                symbolName: "chevron.left",
                action: #selector(goBack(_:))
            )
        case ToolbarItemIdentifier.forward:
            return makeToolbarItem(
                identifier: itemIdentifier,
                label: "Forward",
                symbolName: "chevron.right",
                action: #selector(goForward(_:))
            )
        default:
            return nil
        }
    }

    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        switch item.itemIdentifier {
        case ToolbarItemIdentifier.back:
            return navigationHistory.canGoBack
        case ToolbarItemIdentifier.forward:
            return navigationHistory.canGoForward
        default:
            return true
        }
    }

    private func makeToolbarItem(
        identifier: NSToolbarItem.Identifier,
        label: String,
        symbolName: String,
        action: Selector
    ) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = label
        item.paletteLabel = label
        item.toolTip = label
        item.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: label)
        item.target = self
        item.action = action
        return item
    }

    private func present(error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
    }

    private static let markdownExtensions = Set(["md", "markdown", "mdown", "mkdn"])
}

private extension URL {
    var removingFragment: URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            return self
        }
        components.fragment = nil
        return components.url ?? self
    }

    var isDirectory: Bool {
        guard isFileURL else { return false }
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }
}
