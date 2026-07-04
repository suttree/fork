import Foundation

public struct RenderedPage: Equatable, Sendable {
    public enum Source: Equatable, Sendable {
        case live
        case cache(Date)
    }

    public var title: String
    public var markdown: String
    public var authorAddress: ForkAddress
    public var documentAddress: ForkAddress
    public var source: Source

    public init(
        title: String,
        markdown: String,
        authorAddress: ForkAddress,
        documentAddress: ForkAddress,
        source: Source
    ) {
        self.title = title
        self.markdown = markdown
        self.authorAddress = authorAddress
        self.documentAddress = documentAddress
        self.source = source
    }
}

public final class LocalPeer: @unchecked Sendable {
    public let name: String
    public private(set) var authorIdentity: ForkIdentity?
    public private(set) var documentIdentity: ForkIdentity?

    private var manifestsByAuthor: [String: SignedAuthorManifest] = [:]
    private var documentsByAddress: [String: SignedDocumentRecord] = [:]
    private var cachedAtByAddress: [String: Date] = [:]

    public init(name: String) {
        self.name = name
    }

    public func createAuthorIdentity() -> ForkAddress {
        let identity = ForkIdentity(role: .author)
        authorIdentity = identity
        return identity.address
    }

    @discardableResult
    public func publishHomePage(
        title: String,
        markdown: String,
        createdAt: Date = Date()
    ) throws -> (manifest: SignedAuthorManifest, document: SignedDocumentRecord) {
        let authorIdentity = authorIdentity ?? ForkIdentity(role: .author)
        self.authorIdentity = authorIdentity

        let documentIdentity = documentIdentity ?? ForkIdentity(role: .document)
        self.documentIdentity = documentIdentity

        let documentPayload = DocumentRecordPayload(
            documentPublicKey: Base64URL.encode(documentIdentity.publicKeyData),
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            title: title,
            markdown: markdown,
            version: nextDocumentVersion(for: documentIdentity.address),
            previous: nil,
            createdAt: createdAt
        )
        let signedDocument = try ForkRecordSigner.signDocument(
            payload: documentPayload,
            with: documentIdentity
        )

        let manifestPayload = AuthorManifestPayload(
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            version: nextManifestVersion(for: authorIdentity.address),
            previous: nil,
            homeDocument: documentIdentity.address.rawValue,
            documents: [
                AuthorManifestDocument(
                    address: documentIdentity.address.rawValue,
                    role: "home",
                    title: title
                )
            ],
            createdAt: createdAt
        )
        let signedManifest = try ForkRecordSigner.signManifest(
            payload: manifestPayload,
            with: authorIdentity
        )

        try accept(manifest: signedManifest, cachedAt: createdAt)
        try accept(document: signedDocument, cachedAt: createdAt)
        return (signedManifest, signedDocument)
    }

    public func fetchAuthor(_ address: ForkAddress, from peer: LocalPeer, at fetchedAt: Date = Date()) throws {
        guard let manifest = peer.manifestsByAuthor[address.rawValue] else {
            throw ForkError.missingManifest(address)
        }
        try accept(manifest: manifest, cachedAt: fetchedAt)

        let documentAddress = try ForkAddress(manifest.payload.homeDocument)
        guard let document = peer.documentsByAddress[documentAddress.rawValue] else {
            throw ForkError.missingDocument(documentAddress)
        }
        try accept(document: document, cachedAt: fetchedAt)
    }

    public func renderAuthor(
        _ address: ForkAddress,
        preferLivePeer peer: LocalPeer? = nil,
        fetchedAt: Date = Date()
    ) throws -> RenderedPage {
        if let peer {
            do {
                try fetchAuthor(address, from: peer, at: fetchedAt)
                return try renderCachedAuthor(address, source: .live)
            } catch {
                return try renderCachedAuthorFromCache(address)
            }
        }
        return try renderCachedAuthorFromCache(address)
    }

    public func exportDocument(_ address: ForkAddress) throws -> SignedDocumentRecord {
        guard let document = documentsByAddress[address.rawValue] else {
            throw ForkError.missingDocument(address)
        }
        return document
    }

    public func accept(document: SignedDocumentRecord, cachedAt: Date = Date()) throws {
        guard try ForkRecordSigner.verify(document) else {
            throw ForkError.invalidSignature
        }

        let address = ForkAddress(kind: .document, publicKeyData: try Base64URL.decode(document.payload.documentPublicKey))
        let selected = newest(
            current: documentsByAddress[address.rawValue],
            incoming: document
        )
        documentsByAddress[address.rawValue] = selected
        if selected == document {
            cachedAtByAddress[address.rawValue] = cachedAt
        }
    }

    public func accept(manifest: SignedAuthorManifest, cachedAt: Date = Date()) throws {
        guard try ForkRecordSigner.verify(manifest) else {
            throw ForkError.invalidSignature
        }

        let address = ForkAddress(kind: .author, publicKeyData: try Base64URL.decode(manifest.payload.authorPublicKey))
        let selected = newest(
            current: manifestsByAuthor[address.rawValue],
            incoming: manifest
        )
        manifestsByAuthor[address.rawValue] = selected
        if selected == manifest {
            cachedAtByAddress[address.rawValue] = cachedAt
        }
    }

    private func renderCachedAuthorFromCache(_ address: ForkAddress) throws -> RenderedPage {
        let cachedAt = cachedAtByAddress[address.rawValue] ?? Date()
        return try renderCachedAuthor(address, source: .cache(cachedAt))
    }

    private func renderCachedAuthor(_ address: ForkAddress, source: RenderedPage.Source) throws -> RenderedPage {
        guard let manifest = manifestsByAuthor[address.rawValue] else {
            throw ForkError.missingManifest(address)
        }

        guard try ForkRecordSigner.verify(manifest) else {
            throw ForkError.invalidSignature
        }

        let documentAddress = try ForkAddress(manifest.payload.homeDocument)
        guard let document = documentsByAddress[documentAddress.rawValue] else {
            throw ForkError.missingDocument(documentAddress)
        }

        guard try ForkRecordSigner.verify(document) else {
            throw ForkError.invalidSignature
        }

        guard document.payload.documentPublicKey == documentAddress.key,
              document.payload.authorPublicKey == manifest.payload.authorPublicKey else {
            throw ForkError.invalidSignature
        }

        return RenderedPage(
            title: document.payload.title,
            markdown: document.payload.markdown,
            authorAddress: address,
            documentAddress: documentAddress,
            source: source
        )
    }

    private func nextDocumentVersion(for address: ForkAddress) -> Int {
        (documentsByAddress[address.rawValue]?.payload.version ?? 0) + 1
    }

    private func nextManifestVersion(for address: ForkAddress) -> Int {
        (manifestsByAuthor[address.rawValue]?.payload.version ?? 0) + 1
    }

    private func newest<T>(
        current: T?,
        incoming: T
    ) -> T where T: VersionedRecord {
        guard let current else {
            return incoming
        }
        return incoming.recordVersion >= current.recordVersion ? incoming : current
    }
}

private protocol VersionedRecord {
    var recordVersion: Int { get }
}

extension SignedAuthorManifest: VersionedRecord {
    fileprivate var recordVersion: Int {
        payload.version
    }
}

extension SignedDocumentRecord: VersionedRecord {
    fileprivate var recordVersion: Int {
        payload.version
    }
}
