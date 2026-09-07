import Foundation

@MainActor
public final class BookmarkController {
    private let store: BookmarkStore
    private var library: BookmarkLibrary
    public private(set) var loadingError: Error?

    public var bookmarks: [DocumentBookmark] {
        library.bookmarks
    }

    public init(store: BookmarkStore) {
        self.store = store
        do {
            library = try store.load()
        } catch {
            library = BookmarkLibrary()
            loadingError = error
        }
    }

    @discardableResult
    public func toggle(
        documentURL: URL,
        heading: DocumentHeading
    ) throws -> DocumentBookmark? {
        try ensureLibraryLoaded()
        let standardizedURL = documentURL.standardizedFileURL
        var updatedLibrary = library
        if let existingIndex = updatedLibrary.bookmarks.firstIndex(where: {
            $0.documentURL.standardizedFileURL == standardizedURL
                && $0.anchor == heading.anchor
        }) {
            updatedLibrary.bookmarks.remove(at: existingIndex)
            try store.save(updatedLibrary)
            library = updatedLibrary
            return nil
        }

        let bookmark = DocumentBookmark(
            documentURL: standardizedURL,
            securityScopedBookmarkData: try? standardizedURL.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ),
            anchor: heading.anchor,
            title: heading.title,
            textExcerpt: heading.title
        )
        updatedLibrary.bookmarks.append(bookmark)
        try store.save(updatedLibrary)
        library = updatedLibrary
        return bookmark
    }

    public func remove(id: UUID) throws {
        try ensureLibraryLoaded()
        var updatedLibrary = library
        updatedLibrary.bookmarks.removeAll { $0.id == id }
        try store.save(updatedLibrary)
        library = updatedLibrary
    }

    public func bookmarks(for documentURL: URL) -> [DocumentBookmark] {
        let standardizedURL = documentURL.standardizedFileURL
        return library.bookmarks.filter {
            $0.documentURL.standardizedFileURL == standardizedURL
        }
    }

    public func resolvedURL(for bookmark: DocumentBookmark) -> URL {
        guard let data = bookmark.securityScopedBookmarkData else {
            return bookmark.documentURL
        }
        var isStale = false
        return (try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )) ?? bookmark.documentURL
    }

    private func ensureLibraryLoaded() throws {
        if let loadingError {
            throw loadingError
        }
    }
}
