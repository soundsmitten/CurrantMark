import Foundation

public protocol BookmarkStore {
    func load() throws -> BookmarkLibrary
    func save(_ library: BookmarkLibrary) throws
}

public struct JSONBookmarkStore: BookmarkStore {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func applicationSupport(
        fileManager: FileManager = .default
    ) throws -> JSONBookmarkStore {
        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return JSONBookmarkStore(
            fileURL: applicationSupportURL
                .appendingPathComponent("CurrantMark", isDirectory: true)
                .appendingPathComponent("Bookmarks.json", isDirectory: false)
        )
    }

    public func load() throws -> BookmarkLibrary {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return BookmarkLibrary()
        }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BookmarkLibrary.self, from: data)
    }

    public func save(_ library: BookmarkLibrary) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(library)
        try data.write(to: fileURL, options: .atomic)
    }
}
