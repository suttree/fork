import Foundation

public struct CachedAuthorManifest: Codable, Equatable, Sendable {
    public var record: SignedAuthorManifest
    public var cachedAt: Date

    public init(record: SignedAuthorManifest, cachedAt: Date) {
        self.record = record
        self.cachedAt = cachedAt
    }
}

public struct CachedDocumentRecord: Codable, Equatable, Sendable {
    public var record: SignedDocumentRecord
    public var cachedAt: Date

    public init(record: SignedDocumentRecord, cachedAt: Date) {
        self.record = record
        self.cachedAt = cachedAt
    }
}

public protocol RecordCache: Sendable {
    func loadManifests() throws -> [CachedAuthorManifest]
    func loadDocuments() throws -> [CachedDocumentRecord]
    func save(manifest: SignedAuthorManifest, address: ForkAddress, cachedAt: Date) throws
    func save(document: SignedDocumentRecord, address: ForkAddress, cachedAt: Date) throws
}

public final class FileRecordCache: RecordCache, @unchecked Sendable {
    private let rootDirectory: URL
    private let fileManager: FileManager

    private var manifestsDirectory: URL {
        rootDirectory.appendingPathComponent("manifests", isDirectory: true)
    }

    private var documentsDirectory: URL {
        rootDirectory.appendingPathComponent("documents", isDirectory: true)
    }

    public init(rootDirectory: URL, fileManager: FileManager = .default) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
    }

    public func loadManifests() throws -> [CachedAuthorManifest] {
        try loadRecords(from: manifestsDirectory, as: CachedAuthorManifest.self)
    }

    public func loadDocuments() throws -> [CachedDocumentRecord] {
        try loadRecords(from: documentsDirectory, as: CachedDocumentRecord.self)
    }

    public func save(manifest: SignedAuthorManifest, address: ForkAddress, cachedAt: Date) throws {
        try save(
            CachedAuthorManifest(record: manifest, cachedAt: cachedAt),
            address: address,
            directory: manifestsDirectory
        )
    }

    public func save(document: SignedDocumentRecord, address: ForkAddress, cachedAt: Date) throws {
        try save(
            CachedDocumentRecord(record: document, cachedAt: cachedAt),
            address: address,
            directory: documentsDirectory
        )
    }

    private func loadRecords<T: Decodable>(from directory: URL, as type: T.Type) throws -> [T] {
        guard fileManager.fileExists(atPath: directory.path) else {
            return []
        }

        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "json" }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try urls.compactMap { url in
            do {
                let data = try Data(contentsOf: url)
                return try decoder.decode(T.self, from: data)
            } catch is DecodingError {
                return nil
            }
        }
    }

    private func save<T: Encodable>(_ value: T, address: ForkAddress, directory: URL) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        let data = try encoder.encode(value)
        let url = directory.appendingPathComponent(fileName(for: address))
        try data.write(to: url, options: [.atomic])
    }

    private func fileName(for address: ForkAddress) -> String {
        "\(address.key).json"
    }
}
