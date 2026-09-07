import Foundation

public struct RenderStyle: Sendable {
    public let stylesheet: String

    public init(stylesheet: String) {
        self.stylesheet = stylesheet
    }

    public static var bundled: RenderStyle {
        let stylesheet = Bundle.module.url(forResource: "Style", withExtension: "css")
            .flatMap { try? String(contentsOf: $0) } ?? ""
        return RenderStyle(stylesheet: stylesheet)
    }
}

public struct RenderedDocument: Sendable {
    public let html: String
    public let baseURL: URL?
    public let index: DocumentIndex

    public init(
        html: String,
        baseURL: URL? = nil,
        index: DocumentIndex = DocumentIndex()
    ) {
        self.html = html
        self.baseURL = baseURL
        self.index = index
    }
}

public struct DocumentIndex: Sendable {
    public let title: String?
    public let headings: [DocumentHeading]
    public let links: [DocumentLink]

    public init(
        title: String? = nil,
        headings: [DocumentHeading] = [],
        links: [DocumentLink] = []
    ) {
        self.title = title
        self.headings = headings
        self.links = links
    }
}

public struct DocumentHeading: Sendable, Equatable {
    public let title: String
    public let level: Int
    public let anchor: String

    public init(title: String, level: Int, anchor: String) {
        self.title = title
        self.level = level
        self.anchor = anchor
    }
}

public struct DocumentLink: Sendable, Equatable {
    public let title: String
    public let url: URL

    public init(title: String, url: URL) {
        self.title = title
        self.url = url
    }
}

public protocol MarkdownProcessor {
    func render(markdown: String, style: RenderStyle, baseURL: URL?) throws -> RenderedDocument
}

public enum MarkdownProcessingError: LocalizedError {
    case invalidStyle

    public var errorDescription: String? {
        switch self {
        case .invalidStyle: return "The render style could not be loaded."
        }
    }
}
