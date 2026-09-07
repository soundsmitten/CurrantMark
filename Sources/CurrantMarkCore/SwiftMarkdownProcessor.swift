import Foundation
import Markdown

public struct SwiftMarkdownProcessor: MarkdownProcessor {
    public init() {}

    public func render(markdown: String, style: RenderStyle, baseURL: URL?) throws -> RenderedDocument {
        let parsedDocument = Document(parsing: markdown)
        var indexCollector = DocumentIndexCollector(baseURL: baseURL)
        indexCollector.visit(parsedDocument)
        let body = addHeadingAnchors(
            indexCollector.index.headings,
            to: HTMLFormatter.format(parsedDocument)
        )
        // A <base> tag lets relative references (e.g. an image sitting next
        // to the Markdown file) resolve against the document's real location
        // even though the HTML is ultimately loaded from a temporary file by
        // the web view (see PreviewView/PDFExporter for why).
        let baseTag = baseURL.map { "<base href=\"\(Self.htmlAttributeEscaped($0.absoluteString))\">" } ?? ""
        let document = """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          \(baseTag)
          <style>\(style.stylesheet)</style>
        </head>
        <body>\(body)</body>
        </html>
        """
        return RenderedDocument(
            html: document,
            baseURL: baseURL,
            index: indexCollector.index
        )
    }

    private static func htmlAttributeEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func addHeadingAnchors(_ headings: [DocumentHeading], to html: String) -> String {
        var result = html
        var searchStart = result.startIndex

        for heading in headings {
            let openingTag = "<h\(heading.level)>"
            guard let range = result.range(
                of: openingTag,
                range: searchStart..<result.endIndex
            ) else {
                continue
            }
            let replacement = "<h\(heading.level) id=\"\(heading.anchor)\">"
            result.replaceSubrange(range, with: replacement)
            searchStart = result.index(range.lowerBound, offsetBy: replacement.count)
        }
        return result
    }
}

private struct DocumentIndexCollector: MarkupWalker {
    private let baseURL: URL?
    private var usedAnchors: [String: Int] = [:]
    private(set) var headings: [DocumentHeading] = []
    private(set) var links: [DocumentLink] = []

    init(baseURL: URL?) {
        self.baseURL = baseURL
    }

    var index: DocumentIndex {
        DocumentIndex(title: headings.first?.title, headings: headings, links: links)
    }

    mutating func visitHeading(_ heading: Heading) {
        let title = plainText(from: heading)
        let baseAnchor = makeAnchor(from: title)
        let duplicateCount = usedAnchors[baseAnchor, default: 0]
        usedAnchors[baseAnchor] = duplicateCount + 1
        let anchor = duplicateCount == 0 ? baseAnchor : "\(baseAnchor)-\(duplicateCount)"
        headings.append(DocumentHeading(title: title, level: heading.level, anchor: anchor))
        descendInto(heading)
    }

    mutating func visitLink(_ link: Link) {
        defer { descendInto(link) }
        guard let destination = link.destination,
              let url = URL(string: destination, relativeTo: baseURL)?.absoluteURL else {
            return
        }
        let title = plainText(from: link)
        links.append(DocumentLink(title: title.isEmpty ? destination : title, url: url))
    }

    private func plainText(from markup: Markup) -> String {
        var collector = PlainTextCollector()
        collector.visit(markup)
        return collector.result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func makeAnchor(from title: String) -> String {
        let lowercased = title.lowercased()
        var result = ""
        var needsSeparator = false

        for scalar in lowercased.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) || scalar == "_" || scalar == "-" {
                if needsSeparator, !result.isEmpty, !result.hasSuffix("-") {
                    result.append("-")
                }
                result.unicodeScalars.append(scalar)
                needsSeparator = false
            } else if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                needsSeparator = true
            }
        }
        return result.isEmpty ? "section" : result
    }
}

private struct PlainTextCollector: MarkupWalker {
    private(set) var result = ""

    mutating func visitText(_ text: Text) {
        result.append(text.string)
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) {
        result.append(inlineCode.code)
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) {
        result.append(" ")
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) {
        result.append(" ")
    }
}
