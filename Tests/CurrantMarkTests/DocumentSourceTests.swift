import Foundation
import XCTest
@testable import CurrantMarkCore

@MainActor
final class DocumentSourceTests: XCTestCase {
    func testLoadsUTF8MarkdownFromFile() throws {
        let url = try makeTemporaryMarkdown(contents: "# Café\n\nHello")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let source = FileDocumentSource(url: url)
        let document = try source.load()

        XCTAssertEqual(document.url, url.standardizedFileURL)
        XCTAssertEqual(document.contents, "# Café\n\nHello")
    }

    func testReportsUnreadableFile() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("missing.md")
        let source = FileDocumentSource(url: url)

        XCTAssertThrowsError(try source.load()) { error in
            guard case .unreadable(let unreadableURL) = error as? DocumentSourceError else {
                return XCTFail("Expected DocumentSourceError.unreadable, got \(error)")
            }
            XCTAssertEqual(unreadableURL, url.standardizedFileURL)
        }
    }

    private func makeTemporaryMarkdown(contents: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("document.md")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
