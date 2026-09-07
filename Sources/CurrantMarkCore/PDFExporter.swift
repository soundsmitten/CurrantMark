import AppKit
import WebKit

@MainActor
public protocol PDFExporter {
    func export(document: RenderedDocument, to url: URL, completion: @escaping (Error?) -> Void)
}

@MainActor
public final class WebKitPDFExporter: PDFExporter {
    private var navigationDelegate: PDFNavigationDelegate?
    private var webView: WKWebView?

    public init() {}

    public func export(document: RenderedDocument, to url: URL, completion: @escaping (Error?) -> Void) {
        // WKWebView.loadHTMLString(_:baseURL:) does not grant the WebContent
        // process read access to local files referenced by relative path
        // (e.g. images next to the source document), even when baseURL is a
        // file:// URL. Writing the HTML to a temporary file and loading it
        // via loadFileURL(_:allowingReadAccessTo:) grants that access; the
        // generated HTML's own <base href> (set by SwiftMarkdownProcessor)
        // keeps relative references resolving against the real document
        // location rather than the temporary file's location.
        let temporaryHTMLURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("html")

        func finish(_ error: Error?) {
            try? FileManager.default.removeItem(at: temporaryHTMLURL)
            completion(error)
        }

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 900, height: 1200))
        self.webView = webView
        let delegate = PDFNavigationDelegate { [weak webView] in
            guard let webView else { return }
            let configuration = WKPDFConfiguration()
            webView.createPDF(configuration: configuration) { result in
                switch result {
                case .success(let data):
                    do {
                        try data.write(to: url)
                        finish(nil)
                    } catch {
                        finish(error)
                    }
                case .failure(let error): finish(error)
                }
                self.webView = nil
                self.navigationDelegate = nil
            }
        }
        navigationDelegate = delegate
        webView.navigationDelegate = delegate

        do {
            try document.html.write(to: temporaryHTMLURL, atomically: true, encoding: .utf8)
            webView.loadFileURL(temporaryHTMLURL, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        } catch {
            webView.loadHTMLString(document.html, baseURL: document.baseURL)
        }
    }
}

private final class PDFNavigationDelegate: NSObject, WKNavigationDelegate {
    let finished: () -> Void

    init(finished: @escaping () -> Void) {
        self.finished = finished
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finished()
    }
}
