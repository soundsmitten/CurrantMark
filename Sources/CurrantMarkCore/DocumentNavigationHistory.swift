import Foundation

public struct DocumentNavigationHistory {
    private var entries: [URL] = []
    private var currentIndex: Int?

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

    public var items: [URL] {
        entries
    }

    public var selectedIndex: Int? {
        currentIndex
    }

    public mutating func visit(_ url: URL) {
        if let currentIndex {
            entries.removeSubrange(entries.index(after: currentIndex)..<entries.endIndex)
        }
        entries.append(url.standardizedFileURL)
        currentIndex = entries.index(before: entries.endIndex)
    }

    public mutating func goBack() -> URL? {
        guard canGoBack, let currentIndex else { return nil }
        let previousIndex = entries.index(before: currentIndex)
        self.currentIndex = previousIndex
        return entries[previousIndex]
    }

    public mutating func goForward() -> URL? {
        guard canGoForward, let currentIndex else { return nil }
        let nextIndex = entries.index(after: currentIndex)
        self.currentIndex = nextIndex
        return entries[nextIndex]
    }

    public mutating func move(to index: Int) -> URL? {
        guard entries.indices.contains(index) else { return nil }
        currentIndex = index
        return entries[index]
    }
}
