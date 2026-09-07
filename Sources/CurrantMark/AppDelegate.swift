import AppKit
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowControllers: [MainWindowController] = []
    private var pendingDocumentURLs: [URL] = []
    private var openPanel: NSOpenPanel?
    private var didFinishLaunching = false

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
            guard let self, self.windowControllers.isEmpty else { return }
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

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if !flag {
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
        appMenu.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let fileMenu = NSMenu(title: "File")
        mainMenu.addItem(withTitle: "File", action: nil, keyEquivalent: "").submenu = fileMenu
        let openItem = fileMenu.addItem(withTitle: "Open…", action: #selector(openDocument(_:)), keyEquivalent: "o")
        openItem.target = self
        fileMenu.addItem(
            withTitle: "Close Window",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        fileMenu.addItem(.separator())
        let exportItem = fileMenu.addItem(withTitle: "Export PDF…", action: #selector(exportPDF(_:)), keyEquivalent: "e")
        exportItem.target = self

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
            if let existing = windowControllers.first(where: { $0.documentURL == standardizedURL }) {
                existing.window?.makeKeyAndOrderFront(nil)
                continue
            }

            let controller = MainWindowController()
            controller.onClose = { [weak self, weak controller] in
                guard let controller else { return }
                self?.windowControllers.removeAll { $0 === controller }
            }
            windowControllers.append(controller)
            controller.open(url: standardizedURL)
        }
    }
}
