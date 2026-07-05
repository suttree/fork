import Foundation

public struct AuthorRecordBundle: Codable, Equatable, Sendable {
    public var manifest: SignedAuthorManifest
    public var documents: [SignedDocumentRecord]

    public init(manifest: SignedAuthorManifest, documents: [SignedDocumentRecord]) {
        self.manifest = manifest
        self.documents = documents
    }
}

public protocol AuthorBundleSource: Sendable {
    func authorBundleData(for address: ForkAddress) throws -> Data
}

public enum AuthorRecordBundleCodec {
    public static func encode(_ bundle: AuthorRecordBundle) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(bundle)
    }

    public static func decode(_ data: Data) throws -> AuthorRecordBundle {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AuthorRecordBundle.self, from: data)
    }
}
