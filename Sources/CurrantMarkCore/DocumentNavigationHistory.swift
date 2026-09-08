import Foundation

/// Tracks document navigation for a single window using two independent
/// mechanisms that are easy to conflate but answer different questions:
///
/// - A chronological visit stack (`entries`/`currentIndex`) that answers
///   "what should Back and Forward do?" Every real navigation -- following a
///   link, clicking a breadcrumb segment, opening a bookmark, File -> Open --
///   always pushes a new entry (truncating any stale forward branch), never
///   deduplicated. This is what makes Back reliably return to whatever was
///   actually being viewed immediately before, even if you jump around out
///   of order (e.g. clicking an older breadcrumb segment, then a link, then
///   an even older breadcrumb segment).
/// - A parent/child tree (`parents`) that answers "what should the
///   breadcrumb bar show?" Only real link-driven navigation records a new
///   parent edge; navigating to a document already in the current ancestor
///   chain always reuses that existing relationship rather than creating a
///   duplicate or a cycle. This is what keeps the breadcrumb a clean,
///   deduplicated hierarchy instead of a raw, ever-growing visit log.
public struct DocumentNavigationHistory {
    private var entries: [URL] = []
    private var currentIndex: Int?
    private var parents: [URL: URL] = [:]

    public init() {}

    public var canGoBack: Bool {
        guard let currentIndex else { return false }
        return currentIndex > entries.startIndex
    }

    public var canGoForward: Bool {
        guard let currentIndex else { return false }
        return currentIndex < entries.index(before: entries.endIndex)
    }

    public var hasNavigated: Bool {
        entries.count > 1
    }

    /// The full chronological visit log, in the order documents were
    /// actually navigated to. Used only for Back/Forward bookkeeping, not
    /// for display.
    public var items: [URL] {
        entries
    }

    public var selectedIndex: Int? {
        currentIndex
    }

    /// The document currently being viewed, with any anchor fragment
    /// removed, or `nil` if nothing has been visited yet.
    private var currentDocumentURL: URL? {
        currentIndex.map { Self.removingFragment(entries[$0]) }
    }

    /// The ancestor path from the root of the current browsing session down
    /// to the document currently being viewed, computed by walking recorded
    /// parent/child link relationships. Unlike `items`, this never contains
    /// duplicates and never grows when you navigate back to a document you
    /// came from -- it collapses to that ancestor instead. This is what a
    /// hierarchical breadcrumb bar should display.
    public var path: [URL] {
        guard var node = currentDocumentURL else { return [] }
        var result = [node]
        var guardCount = 0
        while let parent = parents[node], guardCount <= parents.count {
            result.append(parent)
            node = parent
            guardCount += 1
        }
        return result.reversed()
    }

    /// Records navigation to `url` as a new chronological step. Back always
    /// returns to whatever was actually being viewed immediately before this
    /// call, regardless of whether `url` had been visited before or the
    /// navigation was triggered out of the usual order (e.g. clicking an
    /// older breadcrumb segment).
    ///
    /// `linkedFromCurrent` distinguishes a real parent -> child edge
    /// (following a link, or picking a file from a folder link's picker)
    /// from navigation with no inherent relationship to the document
    /// currently being viewed (opening a bookmark, File -> Open). When `url`
    /// is already an ancestor of the current document -- for example,
    /// following a link back to where you came from, or clicking an
    /// ancestor breadcrumb segment -- the existing ancestor relationship is
    /// always reused instead of creating a new edge or a cycle, regardless
    /// of this flag. Otherwise, a link-driven visit records `url`'s parent
    /// as the document you navigated from, while an unrelated visit starts a
    /// fresh root, discarding any relationship `url` had from a previous,
    /// unrelated part of the session.
    public mutating func visit(_ url: URL, linkedFromCurrent: Bool) {
        let standardized = url.standardizedFileURL
        let documentURL = Self.removingFragment(standardized)
        let previousDocumentURL = currentDocumentURL

        if let currentIndex {
            entries.removeSubrange(entries.index(after: currentIndex)..<entries.endIndex)
        }
        entries.append(standardized)
        currentIndex = entries.index(before: entries.endIndex)

        guard let previousDocumentURL, previousDocumentURL != documentURL else {
            if !linkedFromCurrent {
                parents[documentURL] = nil
            }
            return
        }
        if isAncestor(documentURL, of: previousDocumentURL) {
            return
        }
        parents[documentURL] = linkedFromCurrent ? previousDocumentURL : nil
    }

    private func isAncestor(_ candidate: URL, of documentURL: URL) -> Bool {
        var node: URL? = documentURL
        var guardCount = 0
        while let current = node, guardCount <= parents.count {
            if current == candidate { return true }
            node = parents[current]
            guardCount += 1
        }
        return false
    }

    private static func removingFragment(_ url: URL) -> URL {
        guard url.fragment != nil,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return url
        }
        components.fragment = nil
        return components.url ?? url
    }

    /// Moves one step back in the chronological visit stack. Does not touch
    /// the ancestor tree, so the breadcrumb bar recomputes to reflect
    /// whatever document you land on.
    public mutating func goBack() -> URL? {
        guard canGoBack, let currentIndex else { return nil }
        let previousIndex = entries.index(before: currentIndex)
        self.currentIndex = previousIndex
        return entries[previousIndex]
    }

    /// Moves one step forward in the chronological visit stack. Does not
    /// touch the ancestor tree, so the breadcrumb bar recomputes to reflect
    /// whatever document you land on.
    public mutating func goForward() -> URL? {
        guard canGoForward, let currentIndex else { return nil }
        let nextIndex = entries.index(after: currentIndex)
        self.currentIndex = nextIndex
        return entries[nextIndex]
    }
}
