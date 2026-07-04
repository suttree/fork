import Foundation

public struct DraftDocument: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var markdown: String
    public var updatedAt: Date

    public init(id: String, title: String, markdown: String, updatedAt: Date) {
        self.id = id
        self.title = title
        self.markdown = markdown
        self.updatedAt = updatedAt
    }
}

public protocol DraftStore: Sendable {
    func loadDraft(id: String) throws -> DraftDocument?
    func saveDraft(_ draft: DraftDocument) throws
}

public struct StoredDraftProvider: Sendable {
    private let store: any DraftStore

    public init(store: any DraftStore) {
        self.store = store
    }

    public func loadOrCreateHomeDraft(now: Date = Date()) throws -> DraftDocument {
        if let draft = try store.loadDraft(id: "home") {
            return draft
        }

        let draft = DraftDocument(
            id: "home",
            title: "A Small Fork Place",
            markdown: """
            # A Small Fork Place

            This page was written as Markdown, signed by its document key, exchanged with another local peer, and rendered after the author peer went offline.
            """,
            updatedAt: now
        )
        try store.saveDraft(draft)
        return draft
    }
}

public final class MemoryDraftStore: DraftStore, @unchecked Sendable {
    private var draftsByID: [String: DraftDocument] = [:]

    public init() {}

    public func loadDraft(id: String) throws -> DraftDocument? {
        draftsByID[id]
    }

    public func saveDraft(_ draft: DraftDocument) throws {
        draftsByID[draft.id] = draft
    }
}

public final class FileDraftStore: DraftStore, @unchecked Sendable {
    private let rootDirectory: URL
    private let fileManager: FileManager

    public init(rootDirectory: URL, fileManager: FileManager = .default) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
    }

    public func loadDraft(id: String) throws -> DraftDocument? {
        let url = fileURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(DraftDocument.self, from: data)
        } catch is DecodingError {
            return nil
        }
    }

    public func saveDraft(_ draft: DraftDocument) throws {
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        let data = try encoder.encode(draft)
        try data.write(to: fileURL(for: draft.id), options: [.atomic])
    }

    private func fileURL(for id: String) -> URL {
        rootDirectory.appendingPathComponent("\(safeFileName(for: id)).json")
    }

    private func safeFileName(for id: String) -> String {
        id
            .unicodeScalars
            .map { scalar in
                CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_"
                    ? String(scalar)
                    : "-"
            }
            .joined()
    }
}
