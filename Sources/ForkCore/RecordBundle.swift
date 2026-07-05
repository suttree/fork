import Foundation

public struct AuthorRecordBundle: Codable, Equatable, Sendable {
    public var manifest: SignedAuthorManifest
    public var documents: [SignedDocumentRecord]

    public init(manifest: SignedAuthorManifest, documents: [SignedDocumentRecord]) {
        self.manifest = manifest
        self.documents = documents
    }
}
