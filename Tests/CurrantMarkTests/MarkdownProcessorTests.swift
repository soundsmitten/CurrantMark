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

        XCTAssertTrue(document.html.contains("<h1 id=\"hello\">Hello</h1>"))
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

    func testBuildsDocumentIndexAndHeadingAnchors() throws {
        let baseURL = URL(fileURLWithPath: "/tmp/README.md")
        let document = try SwiftMarkdownProcessor().render(
            markdown: "# Project Title\n\n## Build & Run\n\n[Guide](docs/guide.md)",
            style: RenderStyle(stylesheet: ""),
            baseURL: baseURL
        )

        XCTAssertEqual(document.index.title, "Project Title")
        XCTAssertEqual(
            document.index.headings,
            [
                DocumentHeading(title: "Project Title", level: 1, anchor: "project-title"),
                DocumentHeading(title: "Build & Run", level: 2, anchor: "build-run")
            ]
        )
        XCTAssertEqual(
            document.index.links,
            [
                DocumentLink(
                    title: "Guide",
                    url: URL(fileURLWithPath: "/tmp/docs/guide.md")
                )
            ]
        )
        XCTAssertTrue(document.html.contains("<h1 id=\"project-title\">"))
        XCTAssertTrue(document.html.contains("<h2 id=\"build-run\">"))
    }

    func testMakesDuplicateHeadingAnchorsUnique() throws {
        let document = try SwiftMarkdownProcessor().render(
            markdown: "## Notes\n\n## Notes",
            style: RenderStyle(stylesheet: ""),
            baseURL: nil
        )

        XCTAssertEqual(document.index.headings.map(\.anchor), ["notes", "notes-1"])
    }

    func testEmitsBaseTagPointingAtTheDocumentURL() throws {
        let baseURL = URL(fileURLWithPath: "/tmp/README.md")
        let document = try SwiftMarkdownProcessor().render(
            markdown: "Hello",
            style: RenderStyle(stylesheet: ""),
            baseURL: baseURL
        )

        XCTAssertTrue(document.html.contains("<base href=\"file:///tmp/README.md\">"), document.html)
    }

    func testOmitsBaseTagWhenBaseURLIsNil() throws {
        let document = try SwiftMarkdownProcessor().render(
            markdown: "Hello",
            style: RenderStyle(stylesheet: ""),
            baseURL: nil
        )

        XCTAssertFalse(document.html.contains("<base"), document.html)
    }

    func testEscapesSpecialCharactersInTheBaseHrefAttribute() throws {
        // "&" is a valid, unencoded path character that URL does not
        // percent-encode, so it is the realistic case that requires the
        // base href to be HTML-escaped to keep the generated markup
        // well-formed.
        let baseURL = URL(fileURLWithPath: "/tmp/Q&A/README.md")
        let document = try SwiftMarkdownProcessor().render(
            markdown: "Hello",
            style: RenderStyle(stylesheet: ""),
            baseURL: baseURL
        )

        XCTAssertTrue(document.html.contains("<base href=\"file:///tmp/Q&amp;A/README.md\">"), document.html)
    }
}
