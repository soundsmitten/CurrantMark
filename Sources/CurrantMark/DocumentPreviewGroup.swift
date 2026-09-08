import AppKit
import CurrantMarkCore

@MainActor
final class DocumentPreviewGroup: NSView {
    var onBookmarkActivated: ((String) -> Void)?
    var onLinkActivated: ((URL) -> Void)?

    var isSplit: Bool {
        previewViews.count > 1 || pendingSplitID != nil
    }

    private let splitView = NSSplitView()
    private let searchBar = DocumentSearchBar(frame: .zero)
    private var searchBarHeightConstraint: NSLayoutConstraint?
    private var previewViews: [PreviewView] = []
    private weak var lastActivePreviewView: PreviewView?
    private var currentDocument: RenderedDocument?
    private var bookmarkedAnchors: Set<String> = []
    private var pendingSplitID: UUID?
    private var pendingPreviewView: PreviewView?
    private var pageZoom = 1.0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        splitView.isVertical = true
        splitView.dividerStyle = .thin
        searchBar.isHidden = true
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        splitView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(searchBar)
        addSubview(splitView)
        let searchBarHeightConstraint = searchBar.heightAnchor.constraint(equalToConstant: 0)
        self.searchBarHeightConstraint = searchBarHeightConstraint
        NSLayoutConstraint.activate([
            searchBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            searchBar.topAnchor.constraint(equalTo: topAnchor),
            searchBarHeightConstraint,
            splitView.leadingAnchor.constraint(equalTo: leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: trailingAnchor),
            splitView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            splitView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        searchBar.onSearch = { [weak self] query, backwards in
            self?.find(query, backwards: backwards)
        }
        searchBar.onClose = { [weak self] in
            guard let self else { return }
            self.searchBar.isHidden = true
            self.searchBarHeightConstraint?.constant = 0
            focusActivePane()
        }
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
        cancelPendingSplit()
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
        if previewViews.count > 1 {
            removeSecondaryPreviewView()
        } else if pendingSplitID != nil {
            cancelPendingSplit()
        } else {
            addSecondaryPreviewView()
        }
    }

    private func addSecondaryPreviewView() {
        guard let currentDocument else { return }
        let sourcePreviewView = activePreviewView
        let splitID = UUID()
        pendingSplitID = splitID

        sourcePreviewView.currentScrollOffset { [weak self] scrollY in
            guard let self, pendingSplitID == splitID else { return }
            let previewView = makePreviewView()
            let width = max(1, (splitView.bounds.width - splitView.dividerThickness) / 2)
            previewView.frame = NSRect(
                x: 0,
                y: 0,
                width: width,
                height: splitView.bounds.height
            )
            previewView.layoutSubtreeIfNeeded()
            pendingPreviewView = previewView
            previewView.load(currentDocument, restoringScrollY: scrollY) { [weak self, weak previewView] in
                guard let self,
                      let previewView,
                      pendingPreviewView === previewView,
                      pendingSplitID == splitID else {
                    return
                }
                pendingSplitID = nil
                pendingPreviewView = nil
                previewViews.append(previewView)
                splitView.addArrangedSubview(previewView)
                evenlySplitPanes()
                lastActivePreviewView = previewView
                window?.makeFirstResponder(previewView.webView)
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
        splitView.layoutSubtreeIfNeeded()
    }

    private func removeSecondaryPreviewView() {
        guard let previewView = previewViews.last, previewViews.count > 1 else { return }
        splitView.removeArrangedSubview(previewView)
        previewView.removeFromSuperview()
        previewViews.removeAll { $0 === previewView }
        lastActivePreviewView = previewViews.first
        splitView.adjustSubviews()
        if let lastActivePreviewView {
            window?.makeFirstResponder(lastActivePreviewView.webView)
        }
    }

    private func cancelPendingSplit() {
        pendingSplitID = nil
        pendingPreviewView = nil
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

    func showFindInterface() {
        searchBar.isHidden = false
        searchBarHeightConstraint?.constant = 40
        searchBar.focus()
    }

    func makeContentLarger() {
        setPageZoom(pageZoom + 0.1)
    }

    func makeContentSmaller() {
        setPageZoom(pageZoom - 0.1)
    }

    func resetContentSize() {
        setPageZoom(1)
    }

    private func setPageZoom(_ proposedZoom: Double) {
        pageZoom = min(3, max(0.5, (proposedZoom * 10).rounded() / 10))
        previewViews.forEach { $0.setPageZoom(pageZoom) }
    }

    private func find(_ query: String, backwards: Bool) {
        activePreviewView.find(query, backwards: backwards) { [weak self] matchCount in
            self?.searchBar.update(matchCount: matchCount, for: query)
        }
    }

    @discardableResult
    private func appendPreviewView() -> PreviewView {
        let previewView = makePreviewView()
        previewViews.append(previewView)
        splitView.addArrangedSubview(previewView)
        lastActivePreviewView = previewView
        return previewView
    }

    private func makePreviewView() -> PreviewView {
        let previewView = PreviewView(frame: .zero)
        previewView.onLinkActivated = { [weak self, weak previewView] url in
            self?.lastActivePreviewView = previewView
            self?.onLinkActivated?(url)
        }
        previewView.onBookmarkActivated = { [weak self, weak previewView] anchor in
            self?.lastActivePreviewView = previewView
            self?.onBookmarkActivated?(anchor)
        }
        previewView.setPageZoom(pageZoom)
        previewView.setBookmarkedAnchors(bookmarkedAnchors)
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
