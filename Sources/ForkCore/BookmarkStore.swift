import Foundation

public struct ForkBookmark: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var address: String
    public var title: String
    public var nickname: String?
    public var createdAt: Date

    public init(address: String, title: String, nickname: String? = nil, createdAt: Date) {
        self.id = address
        self.address = address
        self.title = title
        self.nickname = Self.normalizedNickname(nickname)
        self.createdAt = createdAt
    }

    public var displayTitle: String {
        nickname ?? title
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case address
        case title
        case nickname
        case createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let address = try container.decode(String.self, forKey: .address)
        self.id = address
        self.address = address
        self.title = try container.decode(String.self, forKey: .title)
        self.nickname = Self.normalizedNickname(try container.decodeIfPresent(String.self, forKey: .nickname))
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(address, forKey: .address)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(nickname, forKey: .nickname)
        try container.encode(createdAt, forKey: .createdAt)
    }

    private static func normalizedNickname(_ nickname: String?) -> String? {
        let trimmedNickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedNickname.isEmpty ? nil : trimmedNickname
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
