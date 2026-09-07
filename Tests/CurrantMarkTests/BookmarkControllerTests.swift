import CurrantMarkCore
import Foundation
import XCTest

@MainActor
final class BookmarkControllerTests: XCTestCase {
    func testToggleAddsAndRemovesSameHeading() throws {
        let store = RecordingBookmarkStore()
        let controller = BookmarkController(store: store)
        let documentURL = URL(fileURLWithPath: "/tmp/README.md")
        let heading = DocumentHeading(title: "Architecture", level: 2, anchor: "architecture")

        let addedBookmark = try controller.toggle(documentURL: documentURL, heading: heading)

        XCTAssertEqual(addedBookmark?.anchor, "architecture")
        XCTAssertEqual(controller.bookmarks.count, 1)
        XCTAssertEqual(store.savedLibraries.count, 1)

        let removedBookmark = try controller.toggle(documentURL: documentURL, heading: heading)

        XCTAssertNil(removedBookmark)
        XCTAssertTrue(controller.bookmarks.isEmpty)
        XCTAssertEqual(store.savedLibraries.count, 2)
    }

    func testFailedSaveDoesNotChangeInMemoryLibrary() {
        let controller = BookmarkController(store: FailingSaveBookmarkStore())
        let heading = DocumentHeading(title: "Architecture", level: 2, anchor: "architecture")

        XCTAssertThrowsError(try controller.toggle(
            documentURL: URL(fileURLWithPath: "/tmp/README.md"),
            heading: heading
        ))
        XCTAssertTrue(controller.bookmarks.isEmpty)
    }
}

private final class RecordingBookmarkStore: BookmarkStore {
    var savedLibraries: [BookmarkLibrary] = []

    func load() throws -> BookmarkLibrary {
        BookmarkLibrary()
    }

    func save(_ library: BookmarkLibrary) throws {
        savedLibraries.append(library)
    }
}

private struct FailingSaveBookmarkStore: BookmarkStore {
    func load() throws -> BookmarkLibrary {
        BookmarkLibrary()
    }

    func save(_ library: BookmarkLibrary) throws {
        throw CocoaError(.fileWriteUnknown)
    }
}
