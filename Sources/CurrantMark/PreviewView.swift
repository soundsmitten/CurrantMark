import AppKit
import CurrantMarkCore
import WebKit

@MainActor
public final class PreviewView: NSView {
    public let webView: WKWebView
    private let bookmarkMessageHandler = BookmarkMessageHandler()
    private let codeCopyMessageHandler = CodeCopyMessageHandler()
    private var navigationDelegate: CompletionNavigationDelegate?
    private var headingAnchors: [String] = []
    private var bookmarkedAnchors: Set<String> = []
    // WKWebView's loadHTMLString(_:baseURL:) never grants the web content
    // process read access to local files referenced by relative path (e.g.
    // an image sitting next to the Markdown source), even when baseURL is a
    // file URL. Writing the generated HTML to disk and loading it with
    // loadFileURL(_:allowingReadAccessTo:) is the documented way to let
    // those relative references actually load; the generated HTML's <base>
    // tag (see SwiftMarkdownProcessor) keeps relative-URL resolution
    // pointed at the document's real location rather than this temp file's.
    // The file is reused across reloads of this view and removed in deinit.
    private let temporaryHTMLURL: URL = {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CurrantMarkPreview", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("html")
    }()
    public var onLinkActivated: ((URL) -> Void)?
    public var onBookmarkActivated: ((String) -> Void)?

    public override init(frame frameRect: NSRect) {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(
            bookmarkMessageHandler,
            name: BookmarkMessageHandler.name
        )
        configuration.userContentController.add(
            codeCopyMessageHandler,
            name: CodeCopyMessageHandler.name
        )
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.underPageBackgroundColor = .textBackgroundColor
        webView.isHidden = true
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        bookmarkMessageHandler.onBookmarkActivated = { [weak self] anchor in
            self?.onBookmarkActivated?(anchor)
        }
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

    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        webView.underPageBackgroundColor = .textBackgroundColor
    }

    deinit {
        let url = temporaryHTMLURL
        try? FileManager.default.removeItem(at: url)
    }

    public func load(
        _ document: RenderedDocument,
        preservingScroll: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        headingAnchors = document.index.headings.map(\.anchor)
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

    public func load(
        _ document: RenderedDocument,
        restoringScrollY scrollY: Double,
        completion: (() -> Void)? = nil
    ) {
        headingAnchors = document.index.headings.map(\.anchor)
        loadHTML(document, restoringScrollY: scrollY, completion: completion)
    }

    public func currentScrollOffset(completion: @escaping (Double) -> Void) {
        webView.evaluateJavaScript("window.scrollY") { value, _ in
            completion((value as? NSNumber)?.doubleValue ?? 0)
        }
    }

    public func scrollToAnchor(_ anchor: String) {
        // NSJSONSerialization requires an Array/Dictionary top-level object and
        // raises an uncaught NSException (not a catchable Swift error) for a bare
        // String, so use JSONEncoder here instead, which safely encodes a String
        // as a top-level JSON value.
        guard let data = try? JSONEncoder().encode(anchor),
              let encodedAnchor = String(data: data, encoding: .utf8) else {
            return
        }
        let script = "document.getElementById(\(encodedAnchor))?.scrollIntoView();"
        webView.evaluateJavaScript(script)
    }

    public func setBookmarkedAnchors(_ anchors: Set<String>) {
        bookmarkedAnchors = anchors
        installBookmarkMarkers()
    }

    public func setPageZoom(_ pageZoom: Double) {
        webView.pageZoom = pageZoom
    }

    public func currentHeadingAnchor(completion: @escaping (String?) -> Void) {
        let script = """
        (() => {
          const headings = Array.from(document.querySelectorAll('h1[id], h2[id], h3[id], h4[id], h5[id], h6[id]'));
          const visible = headings.filter(heading => heading.getBoundingClientRect().top <= 96);
          return (visible.at(-1) ?? headings[0])?.id ?? null;
        })();
        """
        webView.evaluateJavaScript(script) { value, _ in
            completion(value as? String)
        }
    }

    public func find(
        _ query: String,
        backwards: Bool,
        completion: @escaping @MainActor @Sendable (Int) -> Void
    ) {
        guard !query.isEmpty else {
            webView.evaluateJavaScript("window.getSelection()?.removeAllRanges();")
            completion(0)
            return
        }
        guard let data = try? JSONEncoder().encode(query),
              let encodedQuery = String(data: data, encoding: .utf8) else {
            completion(0)
            return
        }
        let configuration = WKFindConfiguration()
        configuration.backwards = backwards
        configuration.caseSensitive = false
        configuration.wraps = true
        webView.find(query, configuration: configuration) { [weak self] result in
            guard let self, result.matchFound else {
                completion(0)
                return
            }
            let script = """
            (() => {
              const query = \(encodedQuery).toLocaleLowerCase();
              const text = (document.body?.innerText ?? '').toLocaleLowerCase();
              let count = 0;
              let index = 0;
              while ((index = text.indexOf(query, index)) !== -1) {
                count += 1;
                index += query.length;
              }
              return count;
            })();
            """
            webView.evaluateJavaScript(script) { value, _ in
                completion((value as? NSNumber)?.intValue ?? 0)
            }
        }
    }

    private func loadHTML(
        _ document: RenderedDocument,
        restoringScrollY scrollY: Double?,
        completion: (() -> Void)?
    ) {
        let delegate = CompletionNavigationDelegate(
            completion: { [weak self] in
                guard let self else { return }
                installBookmarkMarkers()
                installCodeCopyButtons()
                guard let scrollY else {
                    webView.isHidden = false
                    completion?()
                    return
                }
                webView.evaluateJavaScript("window.scrollTo(0, \(scrollY));") { _, _ in
                    self.webView.isHidden = false
                    completion?()
                }
            },
            linkHandler: { [weak self] url in
                self?.onLinkActivated?(url)
            }
        )
        navigationDelegate = delegate
        webView.navigationDelegate = delegate
        guard (try? document.html.write(to: temporaryHTMLURL, atomically: true, encoding: .utf8)) != nil else {
            webView.loadHTMLString(document.html, baseURL: document.baseURL)
            return
        }
        webView.loadFileURL(temporaryHTMLURL, allowingReadAccessTo: URL(fileURLWithPath: "/"))
    }

    private func installBookmarkMarkers() {
        guard let headingJSON = Self.jsonString(headingAnchors),
              let bookmarkedJSON = Self.jsonString(Array(bookmarkedAnchors)) else {
            return
        }
        let script = """
        (() => {
          const headingAnchors = \(headingJSON);
          const bookmarkedAnchors = new Set(\(bookmarkedJSON));
          document.querySelectorAll('.currantmark-bookmark-marker').forEach(marker => marker.remove());
          let style = document.getElementById('currantmark-bookmark-style');
          if (!style) {
            style = document.createElement('style');
            style.id = 'currantmark-bookmark-style';
            style.textContent = `
              h1[id], h2[id], h3[id], h4[id], h5[id], h6[id] { position: relative; }
              .currantmark-bookmark-marker {
                appearance: none;
                position: absolute;
                left: -30px;
                top: 50%;
                width: 11px;
                height: 11px;
                padding: 0;
                border: 1.5px solid currentColor;
                border-radius: 50%;
                background: transparent;
                color: #8b8b8b;
                cursor: pointer;
                opacity: 0;
                transform: translateY(-50%);
                transition: opacity 120ms ease, transform 120ms ease, background-color 120ms ease;
              }
              h1:hover > .currantmark-bookmark-marker,
              h2:hover > .currantmark-bookmark-marker,
              h3:hover > .currantmark-bookmark-marker,
              h4:hover > .currantmark-bookmark-marker,
              h5:hover > .currantmark-bookmark-marker,
              h6:hover > .currantmark-bookmark-marker,
              .currantmark-bookmark-marker:focus-visible,
              .currantmark-bookmark-marker.is-bookmarked { opacity: 1; }
              .currantmark-bookmark-marker:hover { transform: translateY(-50%) scale(1.18); }
              .currantmark-bookmark-marker.is-bookmarked {
                color: #a71930;
                background: #a71930;
              }
              @media print { .currantmark-bookmark-marker { display: none !important; } }
            `;
            document.head.appendChild(style);
          }
          for (const anchor of headingAnchors) {
            const heading = document.getElementById(anchor);
            if (!heading) continue;
            const marker = document.createElement('button');
            marker.type = 'button';
            marker.className = 'currantmark-bookmark-marker';
            marker.dataset.anchor = anchor;
            marker.title = bookmarkedAnchors.has(anchor) ? 'Remove bookmark' : 'Add bookmark';
            marker.setAttribute('aria-label', marker.title);
            marker.classList.toggle('is-bookmarked', bookmarkedAnchors.has(anchor));
            marker.addEventListener('click', event => {
              event.preventDefault();
              event.stopPropagation();
              window.webkit.messageHandlers.\(BookmarkMessageHandler.name).postMessage(anchor);
            });
            heading.prepend(marker);
          }
        })();
        """
        webView.evaluateJavaScript(script)
    }

    private func installCodeCopyButtons() {
        let script = """
        (() => {
          const clipboardIcon = `
            <svg viewBox="0 0 18 18" aria-hidden="true">
              <rect x="5" y="4" width="9" height="11" rx="1.5"></rect>
              <path d="M7 4V3.5A1.5 1.5 0 0 1 8.5 2h2A1.5 1.5 0 0 1 12 3.5V4"></path>
              <path d="M5 6H3.5A1.5 1.5 0 0 0 2 7.5v7A1.5 1.5 0 0 0 3.5 16h7A1.5 1.5 0 0 0 12 14.5"></path>
            </svg>`;
          const checkmarkIcon = `
            <svg viewBox="0 0 18 18" aria-hidden="true">
              <path d="m3.5 9.5 3.2 3.2 7.8-8"></path>
            </svg>`;

          for (const block of document.querySelectorAll('pre')) {
            if (block.querySelector(':scope > .currantmark-code-copy')) continue;
            const code = block.querySelector('code');
            if (!code) continue;

            const button = document.createElement('button');
            button.type = 'button';
            button.className = 'currantmark-code-copy';
            button.innerHTML = clipboardIcon;
            button.title = 'Copy code';
            button.setAttribute('aria-label', 'Copy code');
            button.addEventListener('click', event => {
              event.preventDefault();
              event.stopPropagation();
              window.webkit.messageHandlers.\(CodeCopyMessageHandler.name).postMessage(code.textContent ?? '');
              button.innerHTML = checkmarkIcon;
              button.classList.add('is-copied');
              button.title = 'Copied';
              button.setAttribute('aria-label', 'Copied');
              window.setTimeout(() => {
                button.innerHTML = clipboardIcon;
                button.classList.remove('is-copied');
                button.title = 'Copy code';
                button.setAttribute('aria-label', 'Copy code');
              }, 1500);
            });
            block.appendChild(button);
          }
        })();
        """
        webView.evaluateJavaScript(script)
    }

    private static func jsonString(_ value: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
}

private final class BookmarkMessageHandler: NSObject, WKScriptMessageHandler {
    static let name = "currantmarkBookmark"
    var onBookmarkActivated: ((String) -> Void)?

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let anchor = message.body as? String else { return }
        onBookmarkActivated?(anchor)
    }
}

private final class CodeCopyMessageHandler: NSObject, WKScriptMessageHandler {
    static let name = "currantmarkCodeCopy"

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let code = message.body as? String else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(code, forType: .string)
    }
}

private final class CompletionNavigationDelegate: NSObject, WKNavigationDelegate {
    private var completion: (() -> Void)?
    private let linkHandler: (URL) -> Void

    init(completion: @escaping () -> Void, linkHandler: @escaping (URL) -> Void) {
        self.completion = completion
        self.linkHandler = linkHandler
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard navigationAction.navigationType == .linkActivated,
              let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        linkHandler(url)
        decisionHandler(.cancel)
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
