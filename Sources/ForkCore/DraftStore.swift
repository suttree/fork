import Foundation

public struct DraftDocument: Codable, Equatable, Identifiable, Sendable {
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
    func loadDrafts() throws -> [DraftDocument]
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

    public func loadDrafts() throws -> [DraftDocument] {
        try store.loadDrafts()
            .sorted { lhs, rhs in
                if lhs.id == "home" {
                    return true
                }
                if rhs.id == "home" {
                    return false
                }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    public func loadDraft(id: String) throws -> DraftDocument? {
        try store.loadDraft(id: id)
    }

    public func createDraft(now: Date = Date()) throws -> DraftDocument {
        let draft = DraftDocument(
            id: UUID().uuidString,
            title: "Untitled Page",
            markdown: "# Untitled Page\n\n",
            updatedAt: now
        )
        try store.saveDraft(draft)
        return draft
    }

    public func saveDraft(_ draft: DraftDocument) throws {
        try store.saveDraft(draft)
    }
}

public final class MemoryDraftStore: DraftStore, @unchecked Sendable {
    private var draftsByID: [String: DraftDocument] = [:]

    public init() {}

    public func loadDrafts() throws -> [DraftDocument] {
        Array(draftsByID.values)
    }

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

    public func loadDrafts() throws -> [DraftDocument] {
        guard fileManager.fileExists(atPath: rootDirectory.path) else {
            return []
        }

        let urls = try fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "json" }

        return try urls.compactMap { url in
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(DraftDocument.self, from: data)
            } catch is DecodingError {
                return nil
            }
        }
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
