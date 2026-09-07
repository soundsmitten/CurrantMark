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
    private var didRevealNavigationItems = false
    var onClose: (() -> Void)?
    var onBookmarksChanged: (() -> Void)?

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
        navigationBar.onSelectHistoryItem = { [weak self] index in
            self?.navigateThroughHistory(to: index)
        }

        let toolbar = NSToolbar(identifier: "CurrantMark.DocumentToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
        window.toolbarStyle = .unified
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func open(url: URL) {
        navigate(to: url, recordingHistory: true)
    }

    private func navigate(to url: URL, recordingHistory: Bool) {
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
        if recordingHistory {
            navigationHistory.visit(url)
        }
        navigationBar.updateHistory(navigationHistory)
        revealNavigationItemsIfNeeded()
        window?.toolbar?.validateVisibleItems()
        loadCurrentDocument(preservingScroll: false) { [weak self] in
            self?.showWindow(nil)
            if let anchor = url.fragment {
                self?.previewGroup.scrollToAnchor(anchor)
            }
        }
        newSource.startWatching { [weak self] in self?.loadCurrentDocument(preservingScroll: true) }
    }

    @objc private func goBack(_ sender: Any?) {
        guard let url = navigationHistory.goBack() else { return }
        navigate(to: url, recordingHistory: false)
    }

    @objc private func goForward(_ sender: Any?) {
        guard let url = navigationHistory.goForward() else { return }
        navigate(to: url, recordingHistory: false)
    }

    private func navigateThroughHistory(to index: Int) {
        guard let url = navigationHistory.move(to: index) else { return }
        navigate(to: url, recordingHistory: false)
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
            } else {
                navigate(to: url.standardizedFileURL, recordingHistory: true)
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
            self?.navigate(to: url, recordingHistory: true)
        }
    }

    private func revealNavigationItemsIfNeeded() {
        guard navigationHistory.hasNavigated,
              !didRevealNavigationItems,
              let toolbar = window?.toolbar else {
            return
        }
        didRevealNavigationItems = true
        toolbar.insertItem(withItemIdentifier: ToolbarItemIdentifier.back, at: 0)
        toolbar.insertItem(withItemIdentifier: ToolbarItemIdentifier.forward, at: 1)
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
            recordingHistory: true
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
        []
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
