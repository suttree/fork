import CryptoKit
import Foundation

public struct AuthorManifestDocument: Codable, Equatable, Sendable {
    public var address: String
    public var role: String
    public var title: String

    public init(address: String, role: String, title: String) {
        self.address = address
        self.role = role
        self.title = title
    }
}

public struct AuthorManifestPayload: Codable, Equatable, Sendable {
    public var type: String
    public var authorPublicKey: String
    public var version: Int
    public var previous: String?
    public var homeDocument: String
    public var documents: [AuthorManifestDocument]
    public var theme: String
    public var createdAt: Date

    public init(
        authorPublicKey: String,
        version: Int,
        previous: String?,
        homeDocument: String,
        documents: [AuthorManifestDocument],
        theme: String = "plain",
        createdAt: Date
    ) {
        self.type = "fork.authorManifest"
        self.authorPublicKey = authorPublicKey
        self.version = version
        self.previous = previous
        self.homeDocument = homeDocument
        self.documents = documents
        self.theme = theme
        self.createdAt = createdAt
    }
}

public struct SignedAuthorManifest: Codable, Equatable, Sendable {
    public var payload: AuthorManifestPayload
    public var signature: String

    public init(payload: AuthorManifestPayload, signature: String) {
        self.payload = payload
        self.signature = signature
    }
}

public struct DocumentRecordPayload: Codable, Equatable, Sendable {
    public var type: String
    public var documentPublicKey: String
    public var authorPublicKey: String
    public var title: String
    public var markdown: String
    public var version: Int
    public var previous: String?
    public var createdAt: Date

    public init(
        documentPublicKey: String,
        authorPublicKey: String,
        title: String,
        markdown: String,
        version: Int,
        previous: String?,
        createdAt: Date
    ) {
        self.type = "fork.documentRecord"
        self.documentPublicKey = documentPublicKey
        self.authorPublicKey = authorPublicKey
        self.title = title
        self.markdown = markdown
        self.version = version
        self.previous = previous
        self.createdAt = createdAt
    }
}

public struct SignedDocumentRecord: Codable, Equatable, Sendable {
    public var payload: DocumentRecordPayload
    public var signature: String

    public init(payload: DocumentRecordPayload, signature: String) {
        self.payload = payload
        self.signature = signature
    }
}

public enum ForkRecordSigner {
    private static let authorManifestType = "fork.authorManifest"
    private static let documentRecordType = "fork.documentRecord"

    public static func signDocument(
        payload: DocumentRecordPayload,
        with identity: ForkIdentity
    ) throws -> SignedDocumentRecord {
        let signature = try identity.sign(canonicalData(payload))
        return SignedDocumentRecord(payload: payload, signature: Base64URL.encode(signature))
    }

    public static func signManifest(
        payload: AuthorManifestPayload,
        with identity: ForkIdentity
    ) throws -> SignedAuthorManifest {
        let signature = try identity.sign(canonicalData(payload))
        return SignedAuthorManifest(payload: payload, signature: Base64URL.encode(signature))
    }

    public static func verify(_ record: SignedDocumentRecord) throws -> Bool {
        guard record.payload.type == documentRecordType else {
            return false
        }
        let publicKeyData = try Base64URL.decode(record.payload.documentPublicKey)
        let signature = try Base64URL.decode(record.signature)
        return try ForkIdentity.verify(
            signature: signature,
            for: canonicalData(record.payload),
            publicKeyData: publicKeyData
        )
    }

    public static func verify(_ manifest: SignedAuthorManifest) throws -> Bool {
        guard manifest.payload.type == authorManifestType else {
            return false
        }
        let publicKeyData = try Base64URL.decode(manifest.payload.authorPublicKey)
        let signature = try Base64URL.decode(manifest.signature)
        return try ForkIdentity.verify(
            signature: signature,
            for: canonicalData(manifest.payload),
            publicKeyData: publicKeyData
        )
    }

    public static func canonicalData<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
}

public enum ForkRecordHasher {
    public static func hash<T: Encodable>(_ value: T) throws -> String {
        let digest = SHA256.hash(data: try ForkRecordSigner.canonicalData(value))
        return Base64URL.encode(Data(digest))
    }
}
