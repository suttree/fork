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

    @Test("draft provider lists home first then recent drafts")
    func draftProviderListsHomeFirstThenRecentDrafts() throws {
        let store = MemoryDraftStore()
        let provider = StoredDraftProvider(store: store)
        try provider.saveDraft(
            DraftDocument(
                id: "later",
                title: "Later",
                markdown: "# Later",
                updatedAt: Date(timeIntervalSince1970: 1_783_078_500)
            )
        )
        try provider.saveDraft(
            DraftDocument(
                id: "home",
                title: "Home",
                markdown: "# Home",
                updatedAt: Date(timeIntervalSince1970: 1_783_078_300)
            )
        )
        try provider.saveDraft(
            DraftDocument(
                id: "middle",
                title: "Middle",
                markdown: "# Middle",
                updatedAt: Date(timeIntervalSince1970: 1_783_078_400)
            )
        )

        let drafts = try provider.loadDrafts()

        #expect(drafts.map(\.id) == ["home", "later", "middle"])
    }

    @Test("draft provider creates a new draft")
    func draftProviderCreatesNewDraft() throws {
        let provider = StoredDraftProvider(store: MemoryDraftStore())
        let draft = try provider.createDraft(now: Date(timeIntervalSince1970: 1_783_078_400))

        let loaded = try provider.loadDraft(id: draft.id)

        #expect(loaded == draft)
        #expect(draft.title == "Untitled Page")
    }

    @Test("file bookmark store survives restart")
    func fileBookmarkStoreSurvivesRestart() throws {
        let rootURL = temporaryDirectory()
        let fileURL = rootURL.appendingPathComponent("bookmarks.json")
        let firstStore = FileBookmarkStore(fileURL: fileURL)
        let bookmarks = [
            ForkBookmark(
                address: "fork://author/example",
                title: "Example",
                nickname: "Local Example",
                createdAt: Date(timeIntervalSince1970: 1_783_078_400)
            ),
            ForkBookmark(
                address: "fork://doc/example-document",
                title: "Example Document",
                nickname: "Local Document",
                createdAt: Date(timeIntervalSince1970: 1_783_078_401)
            )
        ]
        try firstStore.saveBookmarks(bookmarks)

        let secondStore = FileBookmarkStore(fileURL: fileURL)
        let loaded = try secondStore.loadBookmarks()

        #expect(loaded == bookmarks)
        #expect(loaded.first?.displayTitle == "Local Example")
        #expect(loaded.last?.address.hasPrefix("fork://doc/") == true)
    }

    @Test("bookmark display title falls back to page title")
    func bookmarkDisplayTitleFallsBackToPageTitle() {
        let bookmark = ForkBookmark(
            address: "fork://author/example",
            title: "Original Title",
            nickname: " ",
            createdAt: Date(timeIntervalSince1970: 1_783_078_400)
        )

        #expect(bookmark.displayTitle == "Original Title")
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

    @Test("document address renders verified cached document")
    func documentAddressRendersCachedDocument() throws {
        let now = Date(timeIntervalSince1970: 1_783_078_400)
        let authorPeer = LocalPeer(name: "Author")
        let readerPeer = LocalPeer(name: "Reader")
        let authorAddress = authorPeer.createAuthorIdentity()
        try authorPeer.publishHomePage(
            title: "Deep Link",
            markdown: "# Deep Link\n\nDocument address works.",
            createdAt: now
        )

        try readerPeer.fetchAuthor(authorAddress, from: authorPeer, at: now)
        let manifest = try readerPeer.exportManifest(authorAddress)
        let documentAddress = try ForkAddress(manifest.payload.homeDocument)
        let page = try readerPeer.render(documentAddress)

        #expect(page.authorAddress == authorAddress)
        #expect(page.documentAddress == documentAddress)
        #expect(page.source == .cache(now))
        #expect(page.markdown.contains("Document address works."))
    }

    @Test("author bundles exchange signed records without shared peer state")
    func authorBundleExchange() throws {
        let now = Date(timeIntervalSince1970: 1_783_078_400)
        let authorPeer = LocalPeer(name: "Author")
        let readerPeer = LocalPeer(name: "Reader")
        let authorAddress = authorPeer.createAuthorIdentity()
        try authorPeer.publishHomePage(
            title: "Bundled Place",
            markdown: "# Bundled Place\n\nCarried as signed records.",
            createdAt: now
        )

        let bundle = try authorPeer.exportAuthorBundle(authorAddress)
        try readerPeer.importAuthorBundle(
            bundle,
            expectedAuthor: authorAddress,
            cachedAt: now
        )
        let cachedPage = try readerPeer.renderAuthor(authorAddress)

        #expect(bundle.documents.count == 1)
        #expect(cachedPage.source == .cache(now))
        #expect(cachedPage.markdown.contains("Carried as signed records."))
    }

    @Test("author manifest can publish multiple documents")
    func authorManifestPublishesMultipleDocuments() throws {
        let now = Date(timeIntervalSince1970: 1_783_078_400)
        let authorPeer = LocalPeer(name: "Author")
        let readerPeer = LocalPeer(name: "Reader")
        let authorAddress = authorPeer.createAuthorIdentity()
        let homeIdentity = ForkIdentity(role: .document)
        let aboutIdentity = ForkIdentity(role: .document)

        try authorPeer.publishDocuments(
            [
                LocalDocumentPublication(
                    identity: homeIdentity,
                    title: "Home",
                    markdown: "# Home\n\nWelcome."
                ),
                LocalDocumentPublication(
                    identity: aboutIdentity,
                    title: "About",
                    markdown: "# About\n\nA second page."
                )
            ],
            homeDocument: homeIdentity.address,
            createdAt: now
        )

        let bundle = try authorPeer.exportAuthorBundle(authorAddress)
        try readerPeer.importAuthorBundle(
            bundle,
            expectedAuthor: authorAddress,
            cachedAt: now
        )
        let homePage = try readerPeer.renderAuthor(authorAddress)
        let aboutPage = try readerPeer.render(aboutIdentity.address)

        #expect(bundle.manifest.payload.homeDocument == homeIdentity.address.rawValue)
        #expect(bundle.manifest.payload.documents.map(\.address) == [
            homeIdentity.address.rawValue,
            aboutIdentity.address.rawValue
        ])
        #expect(bundle.documents.count == 2)
        #expect(homePage.documentAddress == homeIdentity.address)
        #expect(aboutPage.documentAddress == aboutIdentity.address)
        #expect(aboutPage.source == .cache(now))
        #expect(aboutPage.markdown.contains("A second page."))
    }

    @Test("publishing an empty document list is refused")
    func publishingEmptyDocumentListIsRefused() throws {
        let authorPeer = LocalPeer(name: "Author")
        _ = authorPeer.createAuthorIdentity()

        #expect(throws: ForkError.missingPublicationDocuments) {
            try authorPeer.publishDocuments(
                [],
                homeDocument: ForkIdentity(role: .document).address
            )
        }
    }

    @Test("author bundle wire data round trips")
    func authorBundleWireDataRoundTrips() throws {
        let now = Date(timeIntervalSince1970: 1_783_078_400)
        let authorPeer = LocalPeer(name: "Author")
        let readerPeer = LocalPeer(name: "Reader")
        let authorAddress = authorPeer.createAuthorIdentity()
        try authorPeer.publishHomePage(
            title: "Wire Place",
            markdown: "# Wire Place\n\nMoved as bytes.",
            createdAt: now
        )

        let data = try authorPeer.exportAuthorBundleData(authorAddress)
        try readerPeer.importAuthorBundleData(
            data,
            expectedAuthor: authorAddress,
            cachedAt: now
        )
        let cachedPage = try readerPeer.renderAuthor(authorAddress)

        #expect(!data.isEmpty)
        #expect(cachedPage.markdown.contains("Moved as bytes."))
    }

    @Test("fetching author uses byte bundle source")
    func fetchAuthorUsesByteBundleSource() throws {
        let now = Date(timeIntervalSince1970: 1_783_078_400)
        let authorPeer = LocalPeer(name: "Author")
        let readerPeer = LocalPeer(name: "Reader")
        let authorAddress = authorPeer.createAuthorIdentity()
        try authorPeer.publishHomePage(
            title: "Source Place",
            markdown: "# Source Place\n\nFetched through source bytes.",
            createdAt: now
        )

        let source = MemoryAuthorBundleSource(dataByAddress: [
            authorAddress.rawValue: try authorPeer.exportAuthorBundleData(authorAddress)
        ])
        try readerPeer.fetchAuthor(authorAddress, from: source, at: now)
        let cachedPage = try readerPeer.renderAuthor(authorAddress)

        #expect(cachedPage.source == .cache(now))
        #expect(cachedPage.markdown.contains("Fetched through source bytes."))
    }

    @Test("rendering through live bundle source marks page live")
    func renderingThroughLiveBundleSourceMarksPageLive() throws {
        let now = Date(timeIntervalSince1970: 1_783_078_400)
        let authorPeer = LocalPeer(name: "Author")
        let readerPeer = LocalPeer(name: "Reader")
        let authorAddress = authorPeer.createAuthorIdentity()
        try authorPeer.publishHomePage(
            title: "Live Source Place",
            markdown: "# Live Source Place",
            createdAt: now
        )

        let source = MemoryAuthorBundleSource(dataByAddress: [
            authorAddress.rawValue: try authorPeer.exportAuthorBundleData(authorAddress)
        ])
        let livePage = try readerPeer.renderAuthor(
            authorAddress,
            preferLiveSource: source,
            fetchedAt: now
        )

        #expect(livePage.source == .live)
    }

    @Test("loopback transport fetches author bundle over localhost")
    func loopbackTransportFetchesAuthorBundle() throws {
        let now = Date(timeIntervalSince1970: 1_783_078_400)
        let authorPeer = LocalPeer(name: "Author")
        let readerPeer = LocalPeer(name: "Reader")
        let authorAddress = authorPeer.createAuthorIdentity()
        try authorPeer.publishHomePage(
            title: "Loopback Place",
            markdown: "# Loopback Place\n\nFetched over localhost.",
            createdAt: now
        )

        let server = try LoopbackAuthorBundleServer(peer: authorPeer)
        try server.start()
        defer {
            server.stop()
        }

        let client = try LoopbackAuthorBundleClient(baseURL: server.baseURL)
        try readerPeer.fetchAuthor(authorAddress, from: client, at: now)
        let cachedPage = try readerPeer.renderAuthor(authorAddress)

        #expect(cachedPage.source == .cache(now))
        #expect(cachedPage.markdown.contains("Fetched over localhost."))
    }

    @Test("author bundles reject records for the wrong author")
    func authorBundleRejectsWrongAuthor() throws {
        let now = Date(timeIntervalSince1970: 1_783_078_400)
        let authorPeer = LocalPeer(name: "Author")
        let wrongAuthor = ForkIdentity(role: .author)
        let authorAddress = authorPeer.createAuthorIdentity()
        try authorPeer.publishHomePage(
            title: "Bundled Place",
            markdown: "# Bundled Place",
            createdAt: now
        )

        let bundle = try authorPeer.exportAuthorBundle(authorAddress)
        let readerPeer = LocalPeer(name: "Reader")

        #expect(throws: ForkError.invalidSignature) {
            try readerPeer.importAuthorBundle(
                bundle,
                expectedAuthor: wrongAuthor.address,
                cachedAt: now
            )
        }
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

private struct MemoryAuthorBundleSource: AuthorBundleSource {
    var dataByAddress: [String: Data]

    func authorBundleData(for address: ForkAddress) throws -> Data {
        guard let data = dataByAddress[address.rawValue] else {
            throw ForkError.missingManifest(address)
        }
        return data
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
