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

    public init(html: String, baseURL: URL? = nil) {
        self.html = html
        self.baseURL = baseURL
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
