import AppKit
import CurrantMarkCore
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate,
    NSMenuItemValidation {
    private let preferences = AppPreferences()
    private let bookmarkController: BookmarkController
    private var windowControllers: [MainWindowController] = []
    private var pendingDocumentURLs: [URL] = []
    private var openPanel: NSOpenPanel?
    private var settingsWindowController: SettingsWindowController?
    private var bookmarksWindowController: BookmarksWindowController?
    private weak var bookmarksMenu: NSMenu?
    private var didFinishLaunching = false

    override init() {
        let store: BookmarkStore
        do {
            store = try JSONBookmarkStore.applicationSupport()
        } catch {
            store = UnavailableBookmarkStore(error: error)
        }
        bookmarkController = BookmarkController(store: store)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        didFinishLaunching = true
        NSApp.activate(ignoringOtherApps: true)

        if !pendingDocumentURLs.isEmpty {
            let urls = pendingDocumentURLs
            pendingDocumentURLs.removeAll()
            openDocuments(at: urls)
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.windowControllers.isEmpty,
                  self.preferences.automaticallyShowsOpenPanelWhenNoDocumentsAreOpen else {
                return
            }
            self.openDocument(nil)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard didFinishLaunching else {
            pendingDocumentURLs.append(contentsOf: urls)
            return
        }
        openDocuments(at: urls)
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if !flag, preferences.automaticallyShowsOpenPanelWhenNoDocumentsAreOpen {
            openDocument(nil)
        }
        return true
    }

    func makeMainMenu() -> NSMenu {
        let appName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? ProcessInfo.processInfo.processName
        let mainMenu = NSMenu(title: "Main Menu")

        let appMenu = NSMenu(title: appName)
        mainMenu.addItem(withTitle: appName, action: nil, keyEquivalent: "").submenu = appMenu
        appMenu.addItem(
            withTitle: "About \(appName)",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())
        let settingsItem = appMenu.addItem(
            withTitle: "Settings…",
            action: #selector(showSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let fileMenu = NSMenu(title: "File")
        mainMenu.addItem(withTitle: "File", action: nil, keyEquivalent: "").submenu = fileMenu
        let openItem = fileMenu.addItem(withTitle: "Open…", action: #selector(openDocument(_:)), keyEquivalent: "o")
        openItem.target = self
        let duplicateWindowItem = fileMenu.addItem(
            withTitle: "Duplicate Window",
            action: #selector(duplicateDocumentWindow(_:)),
            keyEquivalent: ""
        )
        duplicateWindowItem.target = self
        fileMenu.addItem(
            withTitle: "Close Window",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        fileMenu.addItem(.separator())
        let exportItem = fileMenu.addItem(withTitle: "Export PDF…", action: #selector(exportPDF(_:)), keyEquivalent: "e")
        exportItem.target = self

        let editMenu = NSMenu(title: "Edit")
        mainMenu.addItem(withTitle: "Edit", action: nil, keyEquivalent: "").submenu = editMenu
        let findItem = editMenu.addItem(
            withTitle: "Find…",
            action: #selector(showFind(_:)),
            keyEquivalent: "f"
        )
        findItem.target = self

        let viewMenu = NSMenu(title: "View")
        mainMenu.addItem(withTitle: "View", action: nil, keyEquivalent: "").submenu = viewMenu
        let makeLargerItem = viewMenu.addItem(
            withTitle: "Bigger",
            action: #selector(makeContentLarger(_:)),
            keyEquivalent: "="
        )
        makeLargerItem.target = self
        let makeSmallerItem = viewMenu.addItem(
            withTitle: "Smaller",
            action: #selector(makeContentSmaller(_:)),
            keyEquivalent: "-"
        )
        makeSmallerItem.target = self
        let actualSizeItem = viewMenu.addItem(
            withTitle: "Actual Size",
            action: #selector(resetContentSize(_:)),
            keyEquivalent: "0"
        )
        actualSizeItem.target = self
        viewMenu.addItem(.separator())
        let splitItem = viewMenu.addItem(
            withTitle: "Show Split",
            action: #selector(toggleSplit(_:)),
            keyEquivalent: "/"
        )
        splitItem.target = self
        let cyclePaneFocusItem = viewMenu.addItem(
            withTitle: "Cycle Pane Focus",
            action: #selector(cyclePaneFocus(_:)),
            keyEquivalent: "\r"
        )
        // Control-Tab is reserved system-wide (window-tab switching / Full
        // Keyboard Access), so it never reaches the app's menu key
        // equivalents. Control-Return does not collide with anything.
        cyclePaneFocusItem.keyEquivalentModifierMask = [.control]
        cyclePaneFocusItem.target = self
        let focusNavigationBarItem = viewMenu.addItem(
            withTitle: "Focus Breadcrumb Bar",
            action: #selector(focusNavigationBar(_:)),
            keyEquivalent: "l"
        )
        focusNavigationBarItem.target = self

        let bookmarksMenu = NSMenu(title: "Bookmarks")
        bookmarksMenu.delegate = self
        self.bookmarksMenu = bookmarksMenu
        mainMenu.addItem(
            withTitle: "Bookmarks",
            action: nil,
            keyEquivalent: ""
        ).submenu = bookmarksMenu

        let windowMenu = NSMenu(title: "Window")
        mainMenu.addItem(withTitle: "Window", action: nil, keyEquivalent: "").submenu = windowMenu
        windowMenu.addItem(
            withTitle: "Minimize",
            action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: "m"
        )
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(
            withTitle: "Bring All to Front",
            action: #selector(NSApplication.arrangeInFront(_:)),
            keyEquivalent: ""
        )
        NSApp.windowsMenu = windowMenu

        return mainMenu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === bookmarksMenu else { return }
        rebuildBookmarksMenu(menu)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(toggleSplit(_:)):
            menuItem.title = activeWindowController?.isSplit == true
                ? "Hide Split"
                : "Show Split"
            return activeWindowController != nil
        case #selector(cyclePaneFocus(_:)),
             #selector(focusNavigationBar(_:)),
             #selector(makeContentLarger(_:)),
             #selector(makeContentSmaller(_:)),
             #selector(resetContentSize(_:)),
             #selector(duplicateDocumentWindow(_:)):
            return activeWindowController != nil
        case #selector(showFind(_:)):
            return activeWindowController != nil
        default:
            return true
        }
    }

    @MainActor @objc private func openDocument(_ sender: Any?) {
        if let openPanel {
            openPanel.makeKeyAndOrderFront(nil)
            return
        }

        let panel = NSOpenPanel()
        panel.allowedContentTypes = ["md", "markdown", "mdown", "mkdn"]
            .compactMap { UTType(filenameExtension: $0) }
        panel.allowsMultipleSelection = true
        openPanel = panel
        panel.begin { [weak self, weak panel] response in
            guard let self, let panel else { return }
            if self.openPanel === panel {
                self.openPanel = nil
            }
            guard response == .OK else { return }
            self.openDocuments(at: panel.urls)
        }
    }

    @MainActor @objc private func exportPDF(_ sender: Any?) {
        activeWindowController?.exportPDF(sender)
    }

    @MainActor @objc private func duplicateDocumentWindow(_ sender: Any?) {
        activeWindowController?.duplicateDocumentWindow()
    }

    @MainActor @objc private func showFind(_ sender: Any?) {
        activeWindowController?.showFind()
    }

    @MainActor @objc private func makeContentLarger(_ sender: Any?) {
        activeWindowController?.makeContentLarger()
    }

    @MainActor @objc private func makeContentSmaller(_ sender: Any?) {
        activeWindowController?.makeContentSmaller()
    }

    @MainActor @objc private func resetContentSize(_ sender: Any?) {
        activeWindowController?.resetContentSize()
    }

    @MainActor @objc private func toggleSplit(_ sender: Any?) {
        activeWindowController?.toggleSplit()
    }

    @MainActor @objc private func cyclePaneFocus(_ sender: Any?) {
        activeWindowController?.cyclePaneFocus()
    }

    @MainActor @objc private func focusNavigationBar(_ sender: Any?) {
        activeWindowController?.focusNavigationBar()
    }

    @MainActor @objc private func showSettings(_ sender: Any?) {
        let controller = settingsWindowController ?? SettingsWindowController(preferences: preferences)
        settingsWindowController = controller
        controller.showWindow(sender)
        controller.window?.makeKeyAndOrderFront(sender)
    }

    @MainActor @objc private func toggleBookmarkAtReadingPosition(_ sender: Any?) {
        activeWindowController?.toggleBookmarkAtReadingPosition()
    }

    @MainActor @objc private func showBookmarks(_ sender: Any?) {
        if let error = bookmarkController.loadingError {
            present(error: error)
            return
        }
        let controller = bookmarksWindowController ?? makeBookmarksWindowController()
        bookmarksWindowController = controller
        controller.update(bookmarks: bookmarkController.bookmarks)
        controller.showWindow(sender)
        controller.window?.makeKeyAndOrderFront(sender)
    }

    @MainActor @objc private func openBookmark(_ sender: NSMenuItem) {
        guard let idString = sender.representedObject as? String,
              let id = UUID(uuidString: idString),
              let bookmark = bookmarkController.bookmarks.first(where: { $0.id == id }) else {
            return
        }
        open(bookmark: bookmark)
    }

    @MainActor
    private var activeWindowController: MainWindowController? {
        NSApp.keyWindow?.windowController as? MainWindowController
            ?? windowControllers.last(where: { $0.window?.isVisible == true })
    }

    @MainActor
    private func openDocuments(at urls: [URL]) {
        guard !urls.isEmpty else { return }
        openPanel?.cancel(nil)
        openPanel = nil

        for url in urls {
            let standardizedURL = url.standardizedFileURL
            let documentURL = standardizedURL.removingFragment
            if let existing = windowControllers.first(where: { $0.documentURL == documentURL }) {
                existing.window?.makeKeyAndOrderFront(nil)
                continue
            }

            let controller = makeDocumentWindowController()
            windowControllers.append(controller)
            controller.open(url: standardizedURL)
        }
    }

    @MainActor
    private func makeDocumentWindowController() -> MainWindowController {
        let controller = MainWindowController(bookmarkController: bookmarkController)
        controller.onClose = { [weak self, weak controller] in
            guard let controller else { return }
            self?.windowControllers.removeAll { $0 === controller }
        }
        controller.onBookmarksChanged = { [weak self] in
            self?.refreshBookmarkSurfaces()
        }
        controller.onDuplicate = { [weak self] url in
            guard let self else { return }
            let duplicate = self.makeDocumentWindowController()
            self.windowControllers.append(duplicate)
            duplicate.open(url: url)
        }
        return controller
    }

    @MainActor
    private func makeBookmarksWindowController() -> BookmarksWindowController {
        let controller = BookmarksWindowController()
        controller.onOpen = { [weak self] bookmark in
            self?.open(bookmark: bookmark)
        }
        controller.onRemove = { [weak self] bookmark in
            guard let self else { return }
            do {
                try self.bookmarkController.remove(id: bookmark.id)
                self.refreshBookmarkSurfaces()
            } catch {
                self.present(error: error)
            }
        }
        return controller
    }

    @MainActor
    private func open(bookmark: DocumentBookmark) {
        let resolvedURL = bookmarkController.resolvedURL(for: bookmark).standardizedFileURL
        // If the bookmarked document is already open in some window, reuse
        // that window rather than opening a duplicate.
        if let existing = windowControllers.first(where: {
            $0.documentURL == resolvedURL.removingFragment
        }) {
            existing.open(bookmark: bookmark)
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }

        // Otherwise, navigate the active window to the bookmark instead of
        // opening a new one -- MainWindowController.open(bookmark:) already
        // handles navigating to a different document. Only fall back to
        // creating a new window if there isn't one to reuse.
        if let active = activeWindowController {
            active.open(bookmark: bookmark)
            active.window?.makeKeyAndOrderFront(nil)
            return
        }

        let controller = makeDocumentWindowController()
        windowControllers.append(controller)
        controller.open(bookmark: bookmark)
    }

    @MainActor
    private func refreshBookmarkSurfaces() {
        windowControllers.forEach { $0.refreshBookmarks() }
        bookmarksWindowController?.update(bookmarks: bookmarkController.bookmarks)
    }

    @MainActor
    private func rebuildBookmarksMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        let toggleItem = menu.addItem(
            withTitle: "Toggle Bookmark at Reading Position",
            action: #selector(toggleBookmarkAtReadingPosition(_:)),
            keyEquivalent: "d"
        )
        toggleItem.target = self
        toggleItem.isEnabled = activeWindowController != nil

        if let documentURL = activeWindowController?.documentURL {
            let currentBookmarks = bookmarkController.bookmarks(for: documentURL)
            if !currentBookmarks.isEmpty {
                menu.addItem(.separator())
                let currentDocumentItem = NSMenuItem(
                    title: "Current Document",
                    action: nil,
                    keyEquivalent: ""
                )
                let currentDocumentMenu = NSMenu(title: "Current Document")
                for bookmark in currentBookmarks {
                    currentDocumentMenu.addItem(makeMenuItem(for: bookmark, includesFilename: false))
                }
                currentDocumentItem.submenu = currentDocumentMenu
                menu.addItem(currentDocumentItem)
            }
        }

        if !bookmarkController.bookmarks.isEmpty {
            let recentItem = NSMenuItem(title: "Recent Bookmarks", action: nil, keyEquivalent: "")
            let recentMenu = NSMenu(title: "Recent Bookmarks")
            for bookmark in bookmarkController.bookmarks
                .sorted(by: { $0.createdAt > $1.createdAt })
                .prefix(10) {
                recentMenu.addItem(makeMenuItem(for: bookmark, includesFilename: true))
            }
            recentItem.submenu = recentMenu
            menu.addItem(recentItem)
        }

        menu.addItem(.separator())
        let showAllItem = menu.addItem(
            withTitle: "Show All Bookmarks…",
            action: #selector(showBookmarks(_:)),
            keyEquivalent: "b"
        )
        showAllItem.keyEquivalentModifierMask = [.command, .shift]
        showAllItem.target = self
    }

    private func makeMenuItem(
        for bookmark: DocumentBookmark,
        includesFilename: Bool
    ) -> NSMenuItem {
        let title = includesFilename
            ? "\(bookmark.title) — \(bookmark.documentURL.lastPathComponent)"
            : bookmark.title
        let item = NSMenuItem(
            title: title,
            action: #selector(openBookmark(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = bookmark.id.uuidString
        return item
    }

    @MainActor
    private func present(error: Error) {
        NSAlert(error: error).runModal()
    }
}

private struct UnavailableBookmarkStore: BookmarkStore {
    let error: Error

    func load() throws -> BookmarkLibrary {
        throw error
    }

    func save(_ library: BookmarkLibrary) throws {
        throw error
    }
}

private extension URL {
    var removingFragment: URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            return self
        }
        components.fragment = nil
        return components.url ?? self
    }
}
