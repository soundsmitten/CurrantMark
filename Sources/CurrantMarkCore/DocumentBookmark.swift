import Foundation

public struct DocumentBookmark: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let documentURL: URL
    public let securityScopedBookmarkData: Data?
    public let anchor: String
    public let title: String
    public let textExcerpt: String
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        documentURL: URL,
        securityScopedBookmarkData: Data? = nil,
        anchor: String,
        title: String,
        textExcerpt: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.documentURL = documentURL
        self.securityScopedBookmarkData = securityScopedBookmarkData
        self.anchor = anchor
        self.title = title
        self.textExcerpt = textExcerpt
        self.createdAt = createdAt
    }
}

public struct BookmarkLibrary: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public var bookmarks: [DocumentBookmark]

    public init(schemaVersion: Int = 1, bookmarks: [DocumentBookmark] = []) {
        self.schemaVersion = schemaVersion
        self.bookmarks = bookmarks
    }
}
