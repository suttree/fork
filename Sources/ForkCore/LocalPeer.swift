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
    public var version: Int
    public var previous: String?
    public var source: Source

    public init(
        title: String,
        markdown: String,
        authorAddress: ForkAddress,
        documentAddress: ForkAddress,
        version: Int,
        previous: String?,
        source: Source
    ) {
        self.title = title
        self.markdown = markdown
        self.authorAddress = authorAddress
        self.documentAddress = documentAddress
        self.version = version
        self.previous = previous
        self.source = source
    }
}

public struct LocalDocumentPublication: Sendable {
    public var identity: ForkIdentity
    public var title: String
    public var markdown: String

    public init(identity: ForkIdentity, title: String, markdown: String) {
        self.identity = identity
        self.title = title
        self.markdown = markdown
    }
}

public final class LocalPeer: @unchecked Sendable {
    public let name: String
    public private(set) var authorIdentity: ForkIdentity?
    public private(set) var documentIdentity: ForkIdentity?

    private let recordCache: (any RecordCache)?
    private var manifestsByAuthor: [String: SignedAuthorManifest] = [:]
    private var documentsByAddress: [String: SignedDocumentRecord] = [:]
    private var cachedAtByAddress: [String: Date] = [:]

    public init(name: String) {
        self.name = name
        self.recordCache = nil
    }

    public init(name: String, recordCache: any RecordCache) throws {
        self.name = name
        self.recordCache = recordCache
        try loadCachedRecords()
    }

    public func useAuthorIdentity(_ identity: ForkIdentity) {
        authorIdentity = identity
    }

    public func useDocumentIdentity(_ identity: ForkIdentity) {
        documentIdentity = identity
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

        let result = try publishDocuments(
            [
                LocalDocumentPublication(
                    identity: documentIdentity,
                    title: title,
                    markdown: markdown
                )
            ],
            homeDocument: documentIdentity.address,
            createdAt: createdAt
        )

        guard let document = result.documents.first else {
            throw ForkError.missingPublicationDocuments
        }

        return (result.manifest, document)
    }

    @discardableResult
    public func publishDocuments(
        _ documents: [LocalDocumentPublication],
        homeDocument: ForkAddress,
        createdAt: Date = Date()
    ) throws -> (manifest: SignedAuthorManifest, documents: [SignedDocumentRecord]) {
        guard !documents.isEmpty else {
            throw ForkError.missingPublicationDocuments
        }
        guard homeDocument.kind == .document else {
            throw ForkError.invalidAddress(homeDocument.rawValue)
        }
        for document in documents where document.identity.address.kind != .document {
            throw ForkError.invalidAddress(document.identity.address.rawValue)
        }

        let authorIdentity = authorIdentity ?? ForkIdentity(role: .author)
        self.authorIdentity = authorIdentity

        guard let homePublication = documents.first(where: { $0.identity.address == homeDocument }) else {
            throw ForkError.missingDocument(homeDocument)
        }
        self.documentIdentity = homePublication.identity

        let signedDocuments = try documents.map { document in
            let documentIdentity = document.identity
            let previousDocument = documentsByAddress[documentIdentity.address.rawValue]
            let documentPayload = DocumentRecordPayload(
                documentPublicKey: Base64URL.encode(documentIdentity.publicKeyData),
                authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
                title: document.title,
                markdown: document.markdown,
                version: nextDocumentVersion(for: documentIdentity.address),
                previous: try previousDocument.map { try ForkRecordHasher.hash($0) },
                createdAt: createdAt
            )
            return try ForkRecordSigner.signDocument(
                payload: documentPayload,
                with: documentIdentity
            )
        }

        let manifestDocuments = documents.map { document in
            AuthorManifestDocument(
                address: document.identity.address.rawValue,
                role: document.identity.address == homeDocument ? "home" : "page",
                title: document.title
            )
        }

        let previousManifest = manifestsByAuthor[authorIdentity.address.rawValue]
        let manifestPayload = AuthorManifestPayload(
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            version: nextManifestVersion(for: authorIdentity.address),
            previous: try previousManifest.map { try ForkRecordHasher.hash($0) },
            homeDocument: homeDocument.rawValue,
            documents: manifestDocuments,
            createdAt: createdAt
        )
        let signedManifest = try ForkRecordSigner.signManifest(
            payload: manifestPayload,
            with: authorIdentity
        )

        try accept(manifest: signedManifest, cachedAt: createdAt)
        for signedDocument in signedDocuments {
            try accept(document: signedDocument, cachedAt: createdAt)
        }
        return (signedManifest, signedDocuments)
    }

    public func fetchAuthor(_ address: ForkAddress, from peer: LocalPeer, at fetchedAt: Date = Date()) throws {
        try fetchAuthor(address, from: peer as AuthorBundleSource, at: fetchedAt)
    }

    public func fetchAuthor(
        _ address: ForkAddress,
        from source: any AuthorBundleSource,
        at fetchedAt: Date = Date()
    ) throws {
        let data = try source.authorBundleData(for: address)
        try importAuthorBundleData(data, expectedAuthor: address, cachedAt: fetchedAt)
    }

    public func renderAuthor(
        _ address: ForkAddress,
        preferLivePeer peer: LocalPeer? = nil,
        fetchedAt: Date = Date()
    ) throws -> RenderedPage {
        try renderAuthor(
            address,
            preferLiveSource: peer as (any AuthorBundleSource)?,
            fetchedAt: fetchedAt
        )
    }

    public func renderAuthor(
        _ address: ForkAddress,
        preferLiveSource source: (any AuthorBundleSource)?,
        fetchedAt: Date = Date()
    ) throws -> RenderedPage {
        if let source {
            do {
                try fetchAuthor(address, from: source, at: fetchedAt)
                return try renderCachedAuthor(address, source: .live)
            } catch {
                return try renderCachedAuthorFromCache(address)
            }
        }
        return try renderCachedAuthorFromCache(address)
    }

    public func render(_ address: ForkAddress) throws -> RenderedPage {
        switch address.kind {
        case .author:
            try renderCachedAuthorFromCache(address)
        case .document:
            try renderCachedDocument(address)
        }
    }

    public func exportDocument(_ address: ForkAddress) throws -> SignedDocumentRecord {
        guard let document = documentsByAddress[address.rawValue] else {
            throw ForkError.missingDocument(address)
        }
        return document
    }

    public func exportManifest(_ address: ForkAddress) throws -> SignedAuthorManifest {
        guard let manifest = manifestsByAuthor[address.rawValue] else {
            throw ForkError.missingManifest(address)
        }
        return manifest
    }

    public func exportAuthorBundle(_ address: ForkAddress) throws -> AuthorRecordBundle {
        let manifest = try exportManifest(address)
        let documentAddresses = try manifest.payload.documents.map { document in
            try ForkAddress(document.address)
        }

        let documents = try documentAddresses.map { address in
            try exportDocument(address)
        }

        return AuthorRecordBundle(manifest: manifest, documents: documents)
    }

    public func exportAuthorBundleData(_ address: ForkAddress) throws -> Data {
        try AuthorRecordBundleCodec.encode(exportAuthorBundle(address))
    }

    public func importAuthorBundleData(
        _ data: Data,
        expectedAuthor: ForkAddress,
        cachedAt: Date = Date()
    ) throws {
        let bundle = try AuthorRecordBundleCodec.decode(data)
        try importAuthorBundle(bundle, expectedAuthor: expectedAuthor, cachedAt: cachedAt)
    }

    public func importAuthorBundle(
        _ bundle: AuthorRecordBundle,
        expectedAuthor: ForkAddress,
        cachedAt: Date = Date()
    ) throws {
        try importAuthorBundle(
            bundle,
            expectedAuthor: expectedAuthor,
            cachedAt: cachedAt,
            persist: true
        )
    }

    private func importAuthorBundle(
        _ bundle: AuthorRecordBundle,
        expectedAuthor: ForkAddress,
        cachedAt: Date,
        persist: Bool
    ) throws {
        try validateAuthorBundle(bundle, expectedAuthor: expectedAuthor)

        try accept(manifest: bundle.manifest, cachedAt: cachedAt, persist: persist)
        for document in bundle.documents {
            try accept(document: document, cachedAt: cachedAt, persist: persist)
        }
    }

    private func validateAuthorBundle(
        _ bundle: AuthorRecordBundle,
        expectedAuthor: ForkAddress
    ) throws {
        guard expectedAuthor.kind == .author,
              bundle.manifest.payload.authorPublicKey == expectedAuthor.key else {
            throw ForkError.invalidSignature
        }

        guard try ForkRecordSigner.verify(bundle.manifest) else {
            throw ForkError.invalidSignature
        }

        let manifestDocumentAddresses = try validateManifestShape(bundle.manifest)

        let expectedDocumentKeys = manifestDocumentAddresses.map(\.key)
        let expectedDocumentKeySet = Set(expectedDocumentKeys)
        let providedDocumentKeys = bundle.documents.map(\.payload.documentPublicKey)
        let providedDocumentKeySet = Set(providedDocumentKeys)

        guard expectedDocumentKeySet.count == expectedDocumentKeys.count,
              providedDocumentKeySet.count == providedDocumentKeys.count,
              providedDocumentKeySet == expectedDocumentKeySet else {
            throw ForkError.invalidSignature
        }

        for document in bundle.documents {
            guard document.payload.authorPublicKey == bundle.manifest.payload.authorPublicKey,
                  try ForkRecordSigner.verify(document) else {
                throw ForkError.invalidSignature
            }
        }
        guard manifestTitlesMatchDocuments(
            bundle.manifest.payload.documents,
            documents: bundle.documents
        ) else {
            throw ForkError.invalidSignature
        }

        try validateReplacementChain(
            current: manifestsByAuthor[expectedAuthor.rawValue],
            incoming: bundle.manifest
        )
        for document in bundle.documents {
            let documentAddress = ForkAddress(
                kind: .document,
                publicKeyData: try Base64URL.decode(document.payload.documentPublicKey)
            )
            try validateReplacementChain(
                current: documentsByAddress[documentAddress.rawValue],
                incoming: document
            )
        }
    }

    public func accept(document: SignedDocumentRecord, cachedAt: Date = Date()) throws {
        try accept(document: document, cachedAt: cachedAt, persist: true)
    }

    public func accept(manifest: SignedAuthorManifest, cachedAt: Date = Date()) throws {
        try accept(manifest: manifest, cachedAt: cachedAt, persist: true)
    }

    private func accept(document: SignedDocumentRecord, cachedAt: Date, persist: Bool) throws {
        guard try ForkRecordSigner.verify(document) else {
            throw ForkError.invalidSignature
        }

        let address = ForkAddress(kind: .document, publicKeyData: try Base64URL.decode(document.payload.documentPublicKey))
        let selected = try newest(
            current: documentsByAddress[address.rawValue],
            incoming: document
        )
        documentsByAddress[address.rawValue] = selected
        if selected == document {
            cachedAtByAddress[address.rawValue] = cachedAt
            if persist {
                try recordCache?.save(document: document, address: address, cachedAt: cachedAt)
            }
        }
    }

    private func accept(manifest: SignedAuthorManifest, cachedAt: Date, persist: Bool) throws {
        guard try ForkRecordSigner.verify(manifest) else {
            throw ForkError.invalidSignature
        }
        _ = try validateManifestShape(manifest)

        let address = ForkAddress(kind: .author, publicKeyData: try Base64URL.decode(manifest.payload.authorPublicKey))
        let selected = try newest(
            current: manifestsByAuthor[address.rawValue],
            incoming: manifest
        )
        manifestsByAuthor[address.rawValue] = selected
        if selected == manifest {
            cachedAtByAddress[address.rawValue] = cachedAt
            if persist {
                try recordCache?.save(manifest: manifest, address: address, cachedAt: cachedAt)
            }
        }
    }

    private func validateManifestShape(_ manifest: SignedAuthorManifest) throws -> [ForkAddress] {
        let homeDocumentAddress: ForkAddress
        let manifestDocumentAddresses: [ForkAddress]
        do {
            homeDocumentAddress = try ForkAddress(manifest.payload.homeDocument)
            manifestDocumentAddresses = try manifest.payload.documents.map { document in
                try ForkAddress(document.address)
            }
        } catch {
            throw ForkError.invalidSignature
        }

        guard homeDocumentAddress.kind == .document,
              manifestDocumentAddresses.allSatisfy({ $0.kind == .document }),
              manifestDocumentAddresses.contains(homeDocumentAddress) else {
            throw ForkError.invalidSignature
        }
        let documentKeys = manifestDocumentAddresses.map(\.key)
        guard Set(documentKeys).count == documentKeys.count else {
            throw ForkError.invalidSignature
        }
        guard manifestDocumentAddresses.allSatisfy(hasValidAddressPublicKey) else {
            throw ForkError.invalidSignature
        }
        guard hasValidManifestRoles(
            manifest.payload.documents,
            addresses: manifestDocumentAddresses,
            homeDocument: homeDocumentAddress
        ) else {
            throw ForkError.invalidSignature
        }

        return manifestDocumentAddresses
    }

    private func hasValidManifestRoles(
        _ documents: [AuthorManifestDocument],
        addresses: [ForkAddress],
        homeDocument: ForkAddress
    ) -> Bool {
        zip(documents, addresses).allSatisfy { document, address in
            document.role == (address == homeDocument ? "home" : "page")
        }
    }

    private func manifestTitlesMatchDocuments(
        _ manifestDocuments: [AuthorManifestDocument],
        documents: [SignedDocumentRecord]
    ) -> Bool {
        let documentTitlesByKey = Dictionary(
            uniqueKeysWithValues: documents.map { document in
                (document.payload.documentPublicKey, document.payload.title)
            }
        )

        return manifestDocuments.allSatisfy { document in
            guard let address = try? ForkAddress(document.address) else {
                return false
            }
            return documentTitlesByKey[address.key] == document.title
        }
    }

    private func hasValidAddressPublicKey(_ address: ForkAddress) -> Bool {
        guard let publicKeyData = try? address.publicKeyData else {
            return false
        }
        return (try? ForkIdentity.validatePublicKey(publicKeyData)) != nil
    }

    private func loadCachedRecords() throws {
        guard let recordCache else {
            return
        }

        let cachedDocumentsByKey = try loadVerifiedCachedDocuments(from: recordCache)

        for cachedManifest in try recordCache.loadManifests() {
            do {
                guard try ForkRecordSigner.verify(cachedManifest.record) else {
                    continue
                }

                let authorAddress = ForkAddress(
                    kind: .author,
                    publicKeyData: try Base64URL.decode(cachedManifest.record.payload.authorPublicKey)
                )
                let documentAddresses = try cachedManifest.record.payload.documents.map { document in
                    try ForkAddress(document.address)
                }
                let documents = documentAddresses.compactMap { documentAddress in
                    cachedDocumentsByKey[documentAddress.key]?.record
                }
                let bundle = AuthorRecordBundle(
                    manifest: cachedManifest.record,
                    documents: documents
                )

                try validateAuthorBundle(bundle, expectedAuthor: authorAddress)
                try accept(
                    manifest: cachedManifest.record,
                    cachedAt: cachedManifest.cachedAt,
                    persist: false
                )
                for documentAddress in documentAddresses {
                    guard let cachedDocument = cachedDocumentsByKey[documentAddress.key] else {
                        throw ForkError.invalidSignature
                    }
                    try accept(
                        document: cachedDocument.record,
                        cachedAt: cachedDocument.cachedAt,
                        persist: false
                    )
                }
            } catch {
                continue
            }
        }
    }

    private func loadVerifiedCachedDocuments(
        from recordCache: any RecordCache
    ) throws -> [String: CachedDocumentRecord] {
        var cachedDocumentsByKey: [String: CachedDocumentRecord] = [:]
        for cachedDocument in try recordCache.loadDocuments() {
            do {
                guard try ForkRecordSigner.verify(cachedDocument.record) else {
                    continue
                }
                let address = ForkAddress(
                    kind: .document,
                    publicKeyData: try Base64URL.decode(cachedDocument.record.payload.documentPublicKey)
                )
                cachedDocumentsByKey[address.key] = cachedDocument
            } catch {
                continue
            }
        }
        return cachedDocumentsByKey
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
            version: document.payload.version,
            previous: document.payload.previous,
            source: source
        )
    }

    private func renderCachedDocument(_ address: ForkAddress) throws -> RenderedPage {
        guard let document = documentsByAddress[address.rawValue] else {
            throw ForkError.missingDocument(address)
        }

        guard try ForkRecordSigner.verify(document),
              document.payload.documentPublicKey == address.key else {
            throw ForkError.invalidSignature
        }

        let authorAddress = ForkAddress(
            kind: .author,
            publicKeyData: try Base64URL.decode(document.payload.authorPublicKey)
        )
        let cachedAt = cachedAtByAddress[address.rawValue] ?? Date()

        return RenderedPage(
            title: document.payload.title,
            markdown: document.payload.markdown,
            authorAddress: authorAddress,
            documentAddress: address,
            version: document.payload.version,
            previous: document.payload.previous,
            source: .cache(cachedAt)
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
    ) throws -> T where T: VersionedRecord {
        try validateReplacementChain(current: current, incoming: incoming)
        guard let current else {
            return incoming
        }
        guard incoming.recordVersion > current.recordVersion else {
            return current
        }
        return incoming
    }

    private func validateReplacementChain<T>(
        current: T?,
        incoming: T
    ) throws where T: VersionedRecord {
        guard let current else {
            return
        }
        guard incoming.recordVersion > current.recordVersion else {
            return
        }
        guard incoming.previousRecordHash == (try ForkRecordHasher.hash(current)) else {
            throw ForkError.invalidSignature
        }
    }
}

extension LocalPeer: AuthorBundleSource {
    public func authorBundleData(for address: ForkAddress) throws -> Data {
        try exportAuthorBundleData(address)
    }
}

private protocol VersionedRecord: Encodable {
    var recordVersion: Int { get }
    var previousRecordHash: String? { get }
}

extension SignedAuthorManifest: VersionedRecord {
    fileprivate var recordVersion: Int {
        payload.version
    }

    fileprivate var previousRecordHash: String? {
        payload.previous
    }
}

extension SignedDocumentRecord: VersionedRecord {
    fileprivate var recordVersion: Int {
        payload.version
    }

    fileprivate var previousRecordHash: String? {
        payload.previous
    }
}
