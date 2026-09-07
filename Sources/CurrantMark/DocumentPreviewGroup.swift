import AppKit
import CurrantMarkCore

@MainActor
final class DocumentPreviewGroup: NSView {
    var onBookmarkActivated: ((String) -> Void)?
    var onLinkActivated: ((URL) -> Void)?

    var isSplit: Bool {
        previewViews.count > 1
    }

    private let splitView = NSSplitView()
    private var previewViews: [PreviewView] = []
    private weak var lastActivePreviewView: PreviewView?
    private var currentDocument: RenderedDocument?
    private var bookmarkedAnchors: Set<String> = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(splitView)
        NSLayoutConstraint.activate([
            splitView.leadingAnchor.constraint(equalTo: leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: trailingAnchor),
            splitView.topAnchor.constraint(equalTo: topAnchor),
            splitView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        appendPreviewView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func load(
        _ document: RenderedDocument,
        preservingScroll: Bool,
        completion: (() -> Void)? = nil
    ) {
        currentDocument = document
        for (index, previewView) in previewViews.enumerated() {
            previewView.load(
                document,
                preservingScroll: preservingScroll,
                completion: index == 0 ? completion : nil
            )
        }
    }

    func toggleSplit() {
        if isSplit {
            removeSecondaryPreviewView()
        } else {
            addSecondaryPreviewView()
        }
    }

    private func addSecondaryPreviewView() {
        let sourcePreviewView = activePreviewView
        let previewView = appendPreviewView()
        evenlySplitPanes()
        guard let currentDocument else { return }

        sourcePreviewView.currentHeadingAnchor { [weak previewView] anchor in
            previewView?.load(currentDocument, preservingScroll: false) {
                if let anchor {
                    previewView?.scrollToAnchor(anchor)
                }
                previewView?.window?.makeFirstResponder(previewView?.webView)
            }
        }
    }

    /// Adding a second arranged subview to a split view whose first subview
    /// already fills the available space does not by itself give the new
    /// pane a visible width, so explicitly move the divider to the midpoint
    /// once both panes exist.
    private func evenlySplitPanes() {
        guard previewViews.count == 2 else { return }
        splitView.layoutSubtreeIfNeeded()
        let axisLength = splitView.isVertical ? splitView.bounds.width : splitView.bounds.height
        guard axisLength > 0 else { return }
        let midpoint = (axisLength - splitView.dividerThickness) / 2
        splitView.setPosition(midpoint, ofDividerAt: 0)
    }

    private func removeSecondaryPreviewView() {
        guard let previewView = previewViews.last, isSplit else { return }
        splitView.removeArrangedSubview(previewView)
        previewView.removeFromSuperview()
        previewViews.removeAll { $0 === previewView }
        lastActivePreviewView = previewViews.first
        splitView.adjustSubviews()
        if let lastActivePreviewView {
            window?.makeFirstResponder(lastActivePreviewView.webView)
        }
    }

    func scrollToAnchor(_ anchor: String) {
        activePreviewView.scrollToAnchor(anchor)
    }

    func setBookmarkedAnchors(_ anchors: Set<String>) {
        bookmarkedAnchors = anchors
        previewViews.forEach { $0.setBookmarkedAnchors(anchors) }
    }

    func currentHeadingAnchor(completion: @escaping (String?) -> Void) {
        activePreviewView.currentHeadingAnchor(completion: completion)
    }

    /// Moves keyboard focus to whichever pane is currently considered
    /// active, without changing which pane that is (unlike cycleFocus()).
    /// Used to hand focus back to the document content after a breadcrumb
    /// interaction (Escape, Return, or a link-dropdown selection) ends.
    func focusActivePane() {
        window?.makeFirstResponder(activePreviewView.webView)
    }

    /// Moves keyboard focus to the next preview pane. With a single pane
    /// this simply (re)focuses it; with two panes it toggles between them.
    func cycleFocus() {
        guard previewViews.count > 1 else {
            window?.makeFirstResponder(previewViews.first?.webView)
            return
        }
        let current = activePreviewView
        let currentIndex = previewViews.firstIndex(where: { $0 === current }) ?? 0
        let nextIndex = (currentIndex + 1) % previewViews.count
        let nextView = previewViews[nextIndex]
        lastActivePreviewView = nextView
        window?.makeFirstResponder(nextView.webView)
    }

    @discardableResult
    private func appendPreviewView() -> PreviewView {
        let previewView = PreviewView(frame: .zero)
        previewView.onLinkActivated = { [weak self, weak previewView] url in
            self?.lastActivePreviewView = previewView
            self?.onLinkActivated?(url)
        }
        previewView.onBookmarkActivated = { [weak self, weak previewView] anchor in
            self?.lastActivePreviewView = previewView
            self?.onBookmarkActivated?(anchor)
        }
        previewView.setBookmarkedAnchors(bookmarkedAnchors)
        previewViews.append(previewView)
        splitView.addArrangedSubview(previewView)
        lastActivePreviewView = previewView
        return previewView
    }

    private var activePreviewView: PreviewView {
        if let firstResponder = window?.firstResponder as? NSView,
           let focusedPreviewView = previewViews.first(where: {
               firstResponder === $0.webView || firstResponder.isDescendant(of: $0.webView)
           }) {
            return focusedPreviewView
        }
        return lastActivePreviewView ?? previewViews[0]
    }
}
