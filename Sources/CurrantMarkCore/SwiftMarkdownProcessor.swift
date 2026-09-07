import Foundation
import Markdown

public struct SwiftMarkdownProcessor: MarkdownProcessor {
    public init() {}

    public func render(markdown: String, style: RenderStyle, baseURL: URL?) throws -> RenderedDocument {
        let body = HTMLFormatter.format(markdown)
        let document = """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>\(style.stylesheet)</style>
        </head>
        <body>\(body)</body>
        </html>
        """
        return RenderedDocument(html: document, baseURL: baseURL)
    }
}
