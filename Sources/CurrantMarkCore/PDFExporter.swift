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
                        completion(nil)
                    } catch {
                        completion(error)
                    }
                case .failure(let error): completion(error)
                }
                self.webView = nil
                self.navigationDelegate = nil
            }
        }
        navigationDelegate = delegate
        webView.navigationDelegate = delegate
        webView.loadHTMLString(document.html, baseURL: document.baseURL)
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
