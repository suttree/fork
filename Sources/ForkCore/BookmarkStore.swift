import Foundation

public struct ForkBookmark: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var address: String
    public var title: String
    public var createdAt: Date

    public init(address: String, title: String, createdAt: Date) {
        self.id = address
        self.address = address
        self.title = title
        self.createdAt = createdAt
    }
}

public protocol BookmarkStore: Sendable {
    func loadBookmarks() throws -> [ForkBookmark]
    func saveBookmarks(_ bookmarks: [ForkBookmark]) throws
}

public final class MemoryBookmarkStore: BookmarkStore, @unchecked Sendable {
    private var bookmarks: [ForkBookmark]

    public init(bookmarks: [ForkBookmark] = []) {
        self.bookmarks = bookmarks
    }

    public func loadBookmarks() throws -> [ForkBookmark] {
        bookmarks
    }

    public func saveBookmarks(_ bookmarks: [ForkBookmark]) throws {
        self.bookmarks = bookmarks
    }
}

public final class FileBookmarkStore: BookmarkStore, @unchecked Sendable {
    private let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public func loadBookmarks() throws -> [ForkBookmark] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([ForkBookmark].self, from: data)
        } catch is DecodingError {
            return []
        }
    }

    public func saveBookmarks(_ bookmarks: [ForkBookmark]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(bookmarks)
        try data.write(to: fileURL, options: [.atomic])
    }
}
