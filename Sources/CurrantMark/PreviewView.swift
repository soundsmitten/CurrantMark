import AppKit
import CurrantMarkCore
import WebKit

@MainActor
public final class PreviewView: NSView {
    public let webView: WKWebView
    private var navigationDelegate: CompletionNavigationDelegate?

    public override init(frame frameRect: NSRect) {
        let configuration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.underPageBackgroundColor = .textBackgroundColor
        super.init(frame: frameRect)
        addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func load(
        _ document: RenderedDocument,
        preservingScroll: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        if preservingScroll {
            webView.evaluateJavaScript("window.scrollY") { [weak self] value, _ in
                self?.loadHTML(
                    document,
                    restoringScrollY: (value as? NSNumber)?.doubleValue ?? 0,
                    completion: completion
                )
            }
        } else {
            loadHTML(document, restoringScrollY: nil, completion: completion)
        }
    }

    private func loadHTML(
        _ document: RenderedDocument,
        restoringScrollY scrollY: Double?,
        completion: (() -> Void)?
    ) {
        let delegate = CompletionNavigationDelegate { [weak self] in
            guard let self else { return }
            guard let scrollY else {
                completion?()
                return
            }
            webView.evaluateJavaScript("window.scrollTo(0, \(scrollY));") { _, _ in
                completion?()
            }
        }
        navigationDelegate = delegate
        webView.navigationDelegate = delegate
        webView.loadHTMLString(document.html, baseURL: document.baseURL)
    }
}

private final class CompletionNavigationDelegate: NSObject, WKNavigationDelegate {
    private var completion: (() -> Void)?

    init(completion: @escaping () -> Void) {
        self.completion = completion
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finish()
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        finish()
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        finish()
    }

    private func finish() {
        let pendingCompletion = completion
        completion = nil
        pendingCompletion?()
    }
}
