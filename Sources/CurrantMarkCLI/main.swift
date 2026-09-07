import AppKit
import CurrantMarkCore
import Foundation

@main
@MainActor
struct CurrantMarkCLI {
    static func main() {
        do {
            try run(arguments: Array(CommandLine.arguments.dropFirst()))
        } catch {
            FileHandle.standardError.write(Data("Error: \(error.localizedDescription)\n".utf8))
            exit(EXIT_FAILURE)
        }
    }

    private static func run(arguments: [String]) throws {
        guard let first = arguments.first else {
            printUsage()
            return
        }

        if first == "export" {
            try exportPDF(arguments: Array(arguments.dropFirst()))
            return
        }

        guard arguments.count == 1 else {
            throw CLIError.usage
        }
        let sourceURL = URL(fileURLWithPath: first).standardizedFileURL
        let document = try render(sourceURL: sourceURL)
        print(document.html)
    }

    private static func render(sourceURL: URL) throws -> RenderedDocument {
        let source = FileDocumentSource(url: sourceURL)
        let input = try source.load()
        return try SwiftMarkdownProcessor().render(
            markdown: input.contents,
            style: .bundled,
            baseURL: input.url.deletingLastPathComponent()
        )
    }

    private static func exportPDF(arguments: [String]) throws {
        guard arguments.count == 3, arguments[1] == "--pdf" else {
            throw CLIError.usage
        }
        let sourceURL = URL(fileURLWithPath: arguments[0]).standardizedFileURL
        let outputURL = URL(fileURLWithPath: arguments[2]).standardizedFileURL
        let document = try render(sourceURL: sourceURL)

        let application = NSApplication.shared
        application.setActivationPolicy(.prohibited)
        var exportError: Error?
        var completed = false
        WebKitPDFExporter().export(document: document, to: outputURL) { error in
            exportError = error
            completed = true
        }
        while !completed {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        if let exportError { throw exportError }
    }

    private static func printUsage() {
        print("""
        Usage:
          currantmark FILE.md
          currantmark export FILE.md --pdf OUTPUT.pdf
        """)
    }
}

private enum CLIError: LocalizedError {
    case usage

    var errorDescription: String? {
        switch self {
        case .usage: return "Invalid arguments. Run currantmark without arguments for usage."
        }
    }
}
