import Darwin
import Foundation

public struct SourceDocument {
    public let url: URL
    public let contents: String

    public init(url: URL, contents: String) {
        self.url = url
        self.contents = contents
    }
}

public protocol DocumentSource: AnyObject {
    var documentURL: URL { get }
    func load() throws -> SourceDocument
    func startWatching(onChange: @escaping () -> Void)
    func stopWatching()
}

public enum DocumentSourceError: LocalizedError {
    case unreadable(URL)

    public var errorDescription: String? {
        switch self {
        case .unreadable(let url): return "Could not read “\(url.lastPathComponent)”."
        }
    }
}

public final class FileDocumentSource: DocumentSource {
    public let documentURL: URL
    private var fileDescriptor: Int32 = -1
    private var source: DispatchSourceFileSystemObject?

    public init(url: URL) {
        documentURL = url.standardizedFileURL
    }

    deinit { stopWatching() }

    public func load() throws -> SourceDocument {
        guard let contents = try? String(contentsOf: documentURL, encoding: .utf8) else {
            throw DocumentSourceError.unreadable(documentURL)
        }
        return SourceDocument(url: documentURL, contents: contents)
    }

    public func startWatching(onChange: @escaping () -> Void) {
        stopWatching()
        fileDescriptor = open(documentURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            if source.data.contains(.rename) || source.data.contains(.delete) {
                self.stopWatching()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    guard FileManager.default.fileExists(atPath: self.documentURL.path) else { return }
                    self.startWatching(onChange: onChange)
                    onChange()
                }
            } else {
                onChange()
            }
        }
        source.setCancelHandler { [fileDescriptor] in close(fileDescriptor) }
        self.source = source
        source.resume()
    }

    public func stopWatching() {
        source?.cancel()
        source = nil
        fileDescriptor = -1
    }
}
