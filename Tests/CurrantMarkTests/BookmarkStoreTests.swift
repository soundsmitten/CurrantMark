import CurrantMarkCore
import Foundation
import XCTest

final class BookmarkStoreTests: XCTestCase {
    private var directoryURL: URL!

    override func setUp() {
        super.setUp()
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookmarkStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directoryURL)
        directoryURL = nil
        super.tearDown()
    }

    func testMissingFileLoadsEmptyLibrary() throws {
        let store = JSONBookmarkStore(
            fileURL: directoryURL.appendingPathComponent("Bookmarks.json")
        )

        XCTAssertEqual(try store.load(), BookmarkLibrary())
    }

    func testSavesAndLoadsBookmarkLibrary() throws {
        let store = JSONBookmarkStore(
            fileURL: directoryURL.appendingPathComponent("Bookmarks.json")
        )
        let bookmarkID = try XCTUnwrap(
            UUID(uuidString: "C7AB6486-E0C8-49C8-AD58-1B9814763BB1")
        )
        let bookmark = DocumentBookmark(
            id: bookmarkID,
            documentURL: URL(fileURLWithPath: "/tmp/README.md"),
            securityScopedBookmarkData: Data([1, 2, 3]),
            anchor: "architecture",
            title: "Architecture",
            textExcerpt: "Architecture",
            createdAt: Date(timeIntervalSince1970: 1_789_000_000)
        )
        let library = BookmarkLibrary(bookmarks: [bookmark])

        try store.save(library)

        XCTAssertEqual(try store.load(), library)
    }
}
