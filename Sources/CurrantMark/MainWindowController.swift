import AppKit
import CurrantMarkCore
import UniformTypeIdentifiers

@MainActor
final class MainWindowController: NSWindowController, NSWindowDelegate {
    private let previewView = PreviewView(frame: .zero)
    private let processor: MarkdownProcessor
    private let pdfExporter: PDFExporter
    private var source: DocumentSource?
    private var style: RenderStyle
    private var currentDocument: RenderedDocument?
    var onClose: (() -> Void)?

    var documentURL: URL? {
        source?.documentURL
    }

    init(processor: MarkdownProcessor? = nil, pdfExporter: PDFExporter? = nil) {
        self.processor = processor ?? SwiftMarkdownProcessor()
        self.pdfExporter = pdfExporter ?? WebKitPDFExporter()
        let stylesheet = Bundle.main.url(forResource: "Style", withExtension: "css")
            .flatMap { try? String(contentsOf: $0) }
        style = stylesheet.map(RenderStyle.init(stylesheet:)) ?? .bundled
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.titleVisibility = .hidden
        window.center()
        super.init(window: window)
        window.contentView = previewView
        window.backgroundColor = .textBackgroundColor
        window.minSize = NSSize(width: 480, height: 320)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func open(url: URL) {
        source?.stopWatching()
        let newSource = FileDocumentSource(url: url)
        source = newSource
        window?.title = url.lastPathComponent
        loadCurrentDocument(preservingScroll: false) { [weak self] in
            self?.showWindow(nil)
        }
        newSource.startWatching { [weak self] in self?.loadCurrentDocument(preservingScroll: true) }
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
            let document = try processor.render(markdown: input.contents, style: style, baseURL: input.url.deletingLastPathComponent())
            currentDocument = document
            previewView.load(
                document,
                preservingScroll: preservingScroll,
                completion: completion
            )
        } catch { present(error: error) }
    }

    func windowWillClose(_ notification: Notification) {
        source?.stopWatching()
        onClose?()
    }

    private func present(error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
    }
}
