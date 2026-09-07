import XCTest
@testable import CurrantMarkCore

final class MarkdownProcessorTests: XCTestCase {
    func testGFMIsRenderedAsHTML() throws {
        let processor = SwiftMarkdownProcessor()
        let document = try processor.render(
            markdown: "# Hello\n\n- [x] Done\n\n| A | B |\n|---|---|\n| 1 | 2 |",
            style: RenderStyle(stylesheet: "body { color: red; }"),
            baseURL: nil
        )

        XCTAssertTrue(document.html.contains("<h1>Hello</h1>"))
        XCTAssertTrue(document.html.contains("type=\"checkbox\""))
        XCTAssertTrue(document.html.contains("<table>"))
        XCTAssertTrue(document.html.contains("body { color: red; }"))
    }

    func testEscapesCodeAndPreservesLinksAndImages() throws {
        let baseURL = URL(fileURLWithPath: "/tmp/markdown-document")
        let markdown = """
        A [link](https://example.com) and ![image](assets/image.png).

        ```swift
        let value = "<unsafe>"
        ```
        """
        let document = try SwiftMarkdownProcessor().render(
            markdown: markdown,
            style: RenderStyle(stylesheet: ""),
            baseURL: baseURL
        )

        XCTAssertTrue(document.html.contains("href=\"https://example.com\""))
        XCTAssertTrue(document.html.contains("src=\"assets/image.png\""))
        XCTAssertTrue(document.html.contains("class=\"language-swift\""))
        XCTAssertTrue(document.html.contains("&lt;unsafe&gt;"), document.html)
        XCTAssertEqual(document.baseURL, baseURL)
    }

    func testWrapsRenderedBodyInACompleteDocument() throws {
        let document = try SwiftMarkdownProcessor().render(
            markdown: "Hello",
            style: RenderStyle(stylesheet: "body { font-size: 17px; }"),
            baseURL: nil
        )

        XCTAssertTrue(document.html.hasPrefix("<!doctype html>"))
        XCTAssertTrue(document.html.contains("<meta charset=\"utf-8\">"))
        XCTAssertTrue(document.html.contains("<body><p>Hello</p>"))
        XCTAssertTrue(document.html.contains("body { font-size: 17px; }"))
    }
}
