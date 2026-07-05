import Foundation

public struct DraftDocument: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var markdown: String
    public var updatedAt: Date
    public var pageOrder: Int

    public init(id: String, title: String, markdown: String, updatedAt: Date, pageOrder: Int = 0) {
        self.id = id
        self.title = Self.normalizedTitle(title)
        self.markdown = markdown
        self.updatedAt = updatedAt
        self.pageOrder = pageOrder
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case markdown
        case updatedAt
        case pageOrder
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = Self.normalizedTitle(try container.decode(String.self, forKey: .title))
        markdown = try container.decode(String.self, forKey: .markdown)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        pageOrder = try container.decodeIfPresent(Int.self, forKey: .pageOrder) ?? 0
    }

    private static func normalizedTitle(_ title: String) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "Untitled Page" : trimmedTitle
    }
}

public enum DraftMoveDirection: Sendable {
    case up
    case down
}

public protocol DraftStore: Sendable {
    func loadDrafts() throws -> [DraftDocument]
    func loadDraft(id: String) throws -> DraftDocument?
    func saveDraft(_ draft: DraftDocument) throws
    func deleteDraft(id: String) throws
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
        Self.orderedDrafts(try store.loadDrafts())
    }

    public func loadDraft(id: String) throws -> DraftDocument? {
        try store.loadDraft(id: id)
    }

    public func createDraft(now: Date = Date()) throws -> DraftDocument {
        try normalizePageOrderIfNeeded()
        let draft = DraftDocument(
            id: UUID().uuidString,
            title: "Untitled Page",
            markdown: "# Untitled Page\n\n",
            updatedAt: now,
            pageOrder: try nextPageOrder()
        )
        try store.saveDraft(draft)
        return draft
    }

    public func saveDraft(_ draft: DraftDocument) throws {
        try store.saveDraft(draft)
    }

    public func deleteDraft(id: String) throws {
        guard id != "home" else {
            throw ForkError.protectedDraft(id)
        }
        try store.deleteDraft(id: id)
    }

    public func moveDraft(id: String, direction: DraftMoveDirection) throws {
        guard id != "home" else {
            throw ForkError.protectedDraft(id)
        }

        var pageDrafts = try loadDrafts().filter { $0.id != "home" }
        guard let currentIndex = pageDrafts.firstIndex(where: { $0.id == id }) else {
            return
        }

        let targetIndex: Int
        switch direction {
        case .up:
            targetIndex = currentIndex - 1
        case .down:
            targetIndex = currentIndex + 1
        }

        guard pageDrafts.indices.contains(targetIndex) else {
            return
        }

        pageDrafts.swapAt(currentIndex, targetIndex)
        try saveOrderedPageDrafts(pageDrafts)
    }

    public static func sortDrafts(_ lhs: DraftDocument, _ rhs: DraftDocument) -> Bool {
        if lhs.id == "home" {
            return true
        }
        if rhs.id == "home" {
            return false
        }
        if lhs.pageOrder != rhs.pageOrder {
            return lhs.pageOrder < rhs.pageOrder
        }
        return lhs.updatedAt > rhs.updatedAt
    }

    private func nextPageOrder() throws -> Int {
        let maxPageOrder = try store.loadDrafts()
            .filter { $0.id != "home" }
            .map(\.pageOrder)
            .max() ?? 0
        return maxPageOrder + 1
    }

    private func saveOrderedPageDrafts(_ drafts: [DraftDocument]) throws {
        for (offset, draft) in drafts.enumerated() {
            var orderedDraft = draft
            orderedDraft.pageOrder = offset + 1
            try store.saveDraft(orderedDraft)
        }
    }

    private func normalizePageOrderIfNeeded() throws {
        let rawDrafts = try store.loadDrafts()
        let rawOrdersByID = Dictionary(uniqueKeysWithValues: rawDrafts.map { ($0.id, $0.pageOrder) })
        let orderedDrafts = Self.orderedDrafts(rawDrafts)

        for draft in orderedDrafts where draft.id != "home" {
            guard rawOrdersByID[draft.id] != draft.pageOrder else {
                continue
            }
            try store.saveDraft(draft)
        }
    }

    private static func orderedDrafts(_ drafts: [DraftDocument]) -> [DraftDocument] {
        let homeDrafts = drafts.filter { $0.id == "home" }
            .sorted { $0.updatedAt > $1.updatedAt }
        let pageDrafts = drafts.filter { $0.id != "home" }
        let orderedPages: [DraftDocument]

        if pageDrafts.allSatisfy({ $0.pageOrder > 0 }) {
            orderedPages = pageDrafts.sorted(by: sortDrafts)
        } else if pageDrafts.allSatisfy({ $0.pageOrder <= 0 }) {
            orderedPages = pageDrafts.sorted { $0.updatedAt > $1.updatedAt }
        } else {
            let legacyPages = pageDrafts
                .filter { $0.pageOrder <= 0 }
                .sorted { $0.updatedAt > $1.updatedAt }
            let explicitPages = pageDrafts
                .filter { $0.pageOrder > 0 }
                .sorted(by: sortDrafts)
            orderedPages = legacyPages + explicitPages
        }

        return homeDrafts + orderedPages.enumerated().map { offset, draft in
            var orderedDraft = draft
            orderedDraft.pageOrder = offset + 1
            return orderedDraft
        }
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

    public func deleteDraft(id: String) throws {
        draftsByID[id] = nil
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

    public func deleteDraft(id: String) throws {
        let url = fileURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }
        try fileManager.removeItem(at: url)
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
