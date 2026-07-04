import CryptoKit
import Foundation
import Testing
@testable import ForkCore

@Suite("Fork vertical slice")
struct ForkCoreTests {
    @Test("local peer fetches, verifies, caches, and renders while author is offline")
    func localPeerLoop() throws {
        let now = Date(timeIntervalSince1970: 1_783_078_400)
        let result = try VerticalSliceDemo.run(now: now)

        #expect(result.authorAddress.kind == .author)
        #expect(result.documentAddress.kind == .document)
        #expect(result.livePage.source == .live)
        #expect(result.cachedPage.source == .cache(now))
        #expect(result.cachedPage.markdown.contains("signed by its document key"))
    }

    @Test("tampered document records are refused")
    func tamperedRecordFailsVerification() throws {
        let author = ForkIdentity(role: .author)
        let document = ForkIdentity(role: .document)
        let payload = DocumentRecordPayload(
            documentPublicKey: Base64URL.encode(document.publicKeyData),
            authorPublicKey: Base64URL.encode(author.publicKeyData),
            title: "Original",
            markdown: "# Original",
            version: 1,
            previous: nil,
            createdAt: Date(timeIntervalSince1970: 1_783_078_400)
        )

        var record = try ForkRecordSigner.signDocument(payload: payload, with: document)
        record.payload.markdown = "# Forged"

        #expect(try ForkRecordSigner.verify(record) == false)
        let peer = LocalPeer(name: "Reader")
        #expect(throws: ForkError.invalidSignature) {
            try peer.accept(document: record)
        }
    }

    @Test("author and document addresses are key-derived")
    func addressesAreKeyDerived() throws {
        let author = ForkIdentity(role: .author)
        let document = ForkIdentity(role: .document)

        #expect(author.address.rawValue.hasPrefix("fork://author/"))
        #expect(document.address.rawValue.hasPrefix("fork://doc/"))
        #expect(try author.address.publicKeyData == author.publicKeyData)
        #expect(try document.address.publicKeyData == document.publicKeyData)
    }

    @Test("stored author identity is stable across loads")
    func storedAuthorIdentityIsStable() throws {
        let store = MemoryIdentityStore()
        let provider = StoredIdentityProvider(store: store)

        let first = try provider.loadOrCreateAuthorIdentity()
        let second = try provider.loadOrCreateAuthorIdentity()

        #expect(first.address == second.address)
        #expect(first.rawPrivateKey == second.rawPrivateKey)
    }

    @Test("stored document identity is stable across loads")
    func storedDocumentIdentityIsStable() throws {
        let store = MemoryIdentityStore()
        let provider = StoredIdentityProvider(store: store)

        let first = try provider.loadOrCreateDocumentIdentity(account: "home")
        let second = try provider.loadOrCreateDocumentIdentity(account: "home")

        #expect(first.address == second.address)
        #expect(first.rawPrivateKey == second.rawPrivateKey)
    }

    @Test("vertical slice can use a stored author identity")
    func verticalSliceUsesStoredIdentity() throws {
        let store = MemoryIdentityStore()
        let provider = StoredIdentityProvider(store: store)
        let identity = try provider.loadOrCreateAuthorIdentity()

        let result = try VerticalSliceDemo.run(
            now: Date(timeIntervalSince1970: 1_783_078_400),
            identityProvider: provider
        )

        #expect(result.authorAddress == identity.address)
    }

    @Test("vertical slice can use a stored document identity")
    func verticalSliceUsesStoredDocumentIdentity() throws {
        let store = MemoryIdentityStore()
        let provider = StoredIdentityProvider(store: store)
        let identity = try provider.loadOrCreateDocumentIdentity(account: "home")

        let result = try VerticalSliceDemo.run(
            now: Date(timeIntervalSince1970: 1_783_078_400),
            identityProvider: provider
        )

        #expect(result.documentAddress == identity.address)
    }

    @Test("home draft is loaded from draft storage")
    func homeDraftIsLoadedFromDraftStorage() throws {
        let draftStore = MemoryDraftStore()
        let draftProvider = StoredDraftProvider(store: draftStore)
        try draftStore.saveDraft(
            DraftDocument(
                id: "home",
                title: "Stored Draft",
                markdown: "# Stored Draft\n\nThis came from disk-shaped state.",
                updatedAt: Date(timeIntervalSince1970: 1_783_078_400)
            )
        )

        let result = try VerticalSliceDemo.run(
            now: Date(timeIntervalSince1970: 1_783_078_401),
            draftProvider: draftProvider
        )

        #expect(result.livePage.title == "Stored Draft")
        #expect(result.livePage.markdown.contains("disk-shaped state"))
    }

    @Test("file draft store survives restart")
    func fileDraftStoreSurvivesRestart() throws {
        let rootURL = temporaryDirectory()
        let firstStore = FileDraftStore(rootDirectory: rootURL)
        let draft = DraftDocument(
            id: "home",
            title: "Restarted Draft",
            markdown: "# Restarted Draft",
            updatedAt: Date(timeIntervalSince1970: 1_783_078_400)
        )
        try firstStore.saveDraft(draft)

        let secondStore = FileDraftStore(rootDirectory: rootURL)
        let loaded = try secondStore.loadDraft(id: "home")

        #expect(loaded == draft)
    }

    @Test("verified records survive a cache-backed peer restart")
    func verifiedRecordsSurviveRestart() throws {
        let rootURL = temporaryDirectory()
        let cache = FileRecordCache(rootDirectory: rootURL)
        let now = Date(timeIntervalSince1970: 1_783_078_400)

        let authorPeer = LocalPeer(name: "Author")
        let authorAddress = authorPeer.createAuthorIdentity()
        try authorPeer.publishHomePage(
            title: "Cached Place",
            markdown: "# Cached Place\n\nStill here offline.",
            createdAt: now
        )

        let readerPeer = try LocalPeer(name: "Reader", recordCache: cache)
        let livePage = try readerPeer.renderAuthor(
            authorAddress,
            preferLivePeer: authorPeer,
            fetchedAt: now
        )
        #expect(livePage.source == .live)

        let restartedReader = try LocalPeer(
            name: "Restarted Reader",
            recordCache: FileRecordCache(rootDirectory: rootURL)
        )
        let cachedPage = try restartedReader.renderAuthor(authorAddress)

        #expect(cachedPage.source == .cache(now))
        #expect(cachedPage.markdown.contains("Still here offline."))
    }

    @Test("tampered cache files are not rendered after restart")
    func tamperedCacheFilesAreNotRendered() throws {
        let rootURL = temporaryDirectory()
        let cache = FileRecordCache(rootDirectory: rootURL)
        let now = Date(timeIntervalSince1970: 1_783_078_400)

        let authorPeer = LocalPeer(name: "Author")
        let authorAddress = authorPeer.createAuthorIdentity()
        try authorPeer.publishHomePage(
            title: "Cached Place",
            markdown: "# Cached Place\n\nOriginal.",
            createdAt: now
        )

        let readerPeer = try LocalPeer(name: "Reader", recordCache: cache)
        _ = try readerPeer.renderAuthor(
            authorAddress,
            preferLivePeer: authorPeer,
            fetchedAt: now
        )

        let manifest = try readerPeer.exportManifest(authorAddress)
        let documentAddress = try ForkAddress(manifest.payload.homeDocument)
        let documentURL = rootURL
            .appendingPathComponent("documents", isDirectory: true)
            .appendingPathComponent("\(documentAddress.key).json")
        var cachedDocument = try JSONDecoder.fork.decode(
            CachedDocumentRecord.self,
            from: Data(contentsOf: documentURL)
        )
        cachedDocument.record.payload.markdown = "# Forged"
        try JSONEncoder.fork.encode(cachedDocument).write(to: documentURL, options: [.atomic])

        let restartedReader = try LocalPeer(
            name: "Restarted Reader",
            recordCache: FileRecordCache(rootDirectory: rootURL)
        )

        #expect(throws: ForkError.missingDocument(documentAddress)) {
            try restartedReader.renderAuthor(authorAddress)
        }
    }

    @Test("malformed cache files are ignored on restart")
    func malformedCacheFilesAreIgnored() throws {
        let rootURL = temporaryDirectory()
        let manifestsURL = rootURL.appendingPathComponent("manifests", isDirectory: true)
        try FileManager.default.createDirectory(
            at: manifestsURL,
            withIntermediateDirectories: true
        )
        try Data("not json".utf8).write(
            to: manifestsURL.appendingPathComponent("broken.json")
        )

        _ = try LocalPeer(
            name: "Restarted Reader",
            recordCache: FileRecordCache(rootDirectory: rootURL)
        )
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ForkCoreTests-\(UUID().uuidString)", isDirectory: true)
    }
}

private extension JSONDecoder {
    static var fork: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension JSONEncoder {
    static var fork: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
