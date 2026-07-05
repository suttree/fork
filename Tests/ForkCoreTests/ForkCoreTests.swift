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

    @Test("document records with the wrong type are refused")
    func documentRecordsWithWrongTypeAreRefused() throws {
        let author = ForkIdentity(role: .author)
        let document = ForkIdentity(role: .document)
        var payload = DocumentRecordPayload(
            documentPublicKey: Base64URL.encode(document.publicKeyData),
            authorPublicKey: Base64URL.encode(author.publicKeyData),
            title: "Wrong Type",
            markdown: "# Wrong Type",
            version: 1,
            previous: nil,
            createdAt: Date(timeIntervalSince1970: 1_783_078_400)
        )
        payload.type = "fork.authorManifest"

        let record = try ForkRecordSigner.signDocument(payload: payload, with: document)
        let peer = LocalPeer(name: "Reader")

        #expect(try ForkRecordSigner.verify(record) == false)
        #expect(throws: ForkError.invalidSignature) {
            try peer.accept(document: record)
        }
    }

    @Test("document records with malformed author keys are refused")
    func documentRecordsWithMalformedAuthorKeysAreRefused() throws {
        let document = ForkIdentity(role: .document)
        let malformedAuthorKey = Base64URL.encode(Data(repeating: 0, count: 31))
        let payload = DocumentRecordPayload(
            documentPublicKey: Base64URL.encode(document.publicKeyData),
            authorPublicKey: malformedAuthorKey,
            title: "Malformed Author",
            markdown: "# Malformed Author",
            version: 1,
            previous: nil,
            createdAt: Date(timeIntervalSince1970: 1_783_078_400)
        )

        let record = try ForkRecordSigner.signDocument(payload: payload, with: document)
        let peer = LocalPeer(name: "Reader")

        #expect(try ForkRecordSigner.verify(record) == false)
        #expect(throws: ForkError.invalidSignature) {
            try peer.accept(document: record)
        }
    }

    @Test("document records with malformed document keys are refused")
    func documentRecordsWithMalformedDocumentKeysAreRefused() throws {
        let author = ForkIdentity(role: .author)
        let document = ForkIdentity(role: .document)
        let malformedDocumentKey = Base64URL.encode(Data(repeating: 0, count: 31))
        let payload = DocumentRecordPayload(
            documentPublicKey: malformedDocumentKey,
            authorPublicKey: Base64URL.encode(author.publicKeyData),
            title: "Malformed Document",
            markdown: "# Malformed Document",
            version: 1,
            previous: nil,
            createdAt: Date(timeIntervalSince1970: 1_783_078_400)
        )

        let record = try ForkRecordSigner.signDocument(payload: payload, with: document)
        let peer = LocalPeer(name: "Reader")

        #expect(try ForkRecordSigner.verify(record) == false)
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

    @Test("named author identities are stable and separate")
    func namedAuthorIdentitiesAreStableAndSeparate() throws {
        let store = MemoryIdentityStore()
        let provider = StoredIdentityProvider(store: store)

        let firstSample = try provider.loadOrCreateAuthorIdentity(account: "sample")
        let secondSample = try provider.loadOrCreateAuthorIdentity(account: "sample")
        let primary = try provider.loadOrCreateAuthorIdentity()

        #expect(firstSample.address == secondSample.address)
        #expect(firstSample.rawPrivateKey == secondSample.rawPrivateKey)
        #expect(firstSample.address != primary.address)
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
        #expect(drafts.map(\.pageOrder) == [0, 1, 2])
    }

    @Test("draft provider keeps explicit page order")
    func draftProviderKeepsExplicitPageOrder() throws {
        let store = MemoryDraftStore()
        let provider = StoredDraftProvider(store: store)
        try provider.saveDraft(
            DraftDocument(
                id: "later",
                title: "Later",
                markdown: "# Later",
                updatedAt: Date(timeIntervalSince1970: 1_783_078_500),
                pageOrder: 2
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
                updatedAt: Date(timeIntervalSince1970: 1_783_078_400),
                pageOrder: 1
            )
        )

        let drafts = try provider.loadDrafts()

        #expect(drafts.map(\.id) == ["home", "middle", "later"])
    }

    @Test("draft provider appends new drafts after legacy drafts")
    func draftProviderAppendsNewDraftsAfterLegacyDrafts() throws {
        let store = MemoryDraftStore()
        let provider = StoredDraftProvider(store: store)
        try provider.saveDraft(
            DraftDocument(
                id: "older",
                title: "Older",
                markdown: "# Older",
                updatedAt: Date(timeIntervalSince1970: 1_783_078_400)
            )
        )
        try provider.saveDraft(
            DraftDocument(
                id: "newer",
                title: "Newer",
                markdown: "# Newer",
                updatedAt: Date(timeIntervalSince1970: 1_783_078_500)
            )
        )

        let created = try provider.createDraft(now: Date(timeIntervalSince1970: 1_783_078_600))
        let drafts = try provider.loadDrafts()

        #expect(created.pageOrder == 3)
        #expect(drafts.map(\.id) == ["newer", "older", created.id])
        #expect(drafts.map(\.pageOrder) == [1, 2, 3])
        #expect(try store.loadDraft(id: "newer")?.pageOrder == 1)
        #expect(try store.loadDraft(id: "older")?.pageOrder == 2)
    }

    @Test("draft provider creates a new draft")
    func draftProviderCreatesNewDraft() throws {
        let provider = StoredDraftProvider(store: MemoryDraftStore())
        let draft = try provider.createDraft(now: Date(timeIntervalSince1970: 1_783_078_400))

        let loaded = try provider.loadDraft(id: draft.id)

        #expect(loaded == draft)
        #expect(draft.title == "Untitled Page")
        #expect(draft.pageOrder == 1)
    }

    @Test("draft provider moves non-home pages")
    func draftProviderMovesNonHomePages() throws {
        let store = MemoryDraftStore()
        let provider = StoredDraftProvider(store: store)
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
                id: "first",
                title: "First",
                markdown: "# First",
                updatedAt: Date(timeIntervalSince1970: 1_783_078_400),
                pageOrder: 1
            )
        )
        try provider.saveDraft(
            DraftDocument(
                id: "second",
                title: "Second",
                markdown: "# Second",
                updatedAt: Date(timeIntervalSince1970: 1_783_078_500),
                pageOrder: 2
            )
        )

        try provider.moveDraft(id: "second", direction: .up)
        var drafts = try provider.loadDrafts()

        #expect(drafts.map(\.id) == ["home", "second", "first"])
        #expect(drafts.first { $0.id == "second" }?.pageOrder == 1)
        #expect(drafts.first { $0.id == "first" }?.pageOrder == 2)

        try provider.moveDraft(id: "second", direction: .down)
        drafts = try provider.loadDrafts()

        #expect(drafts.map(\.id) == ["home", "first", "second"])
    }

    @Test("draft provider deletes non-home drafts")
    func draftProviderDeletesNonHomeDrafts() throws {
        let provider = StoredDraftProvider(store: MemoryDraftStore())
        let draft = try provider.createDraft(now: Date(timeIntervalSince1970: 1_783_078_400))

        try provider.deleteDraft(id: draft.id)

        #expect(try provider.loadDraft(id: draft.id) == nil)
    }

    @Test("draft provider refuses to delete home draft")
    func draftProviderRefusesToDeleteHomeDraft() throws {
        let provider = StoredDraftProvider(store: MemoryDraftStore())

        #expect(throws: ForkError.protectedDraft("home")) {
            try provider.deleteDraft(id: "home")
        }
    }

    @Test("file draft store deletes persisted draft")
    func fileDraftStoreDeletesPersistedDraft() throws {
        let rootURL = temporaryDirectory()
        let firstStore = FileDraftStore(rootDirectory: rootURL)
        let draft = DraftDocument(
            id: "about",
            title: "About",
            markdown: "# About",
            updatedAt: Date(timeIntervalSince1970: 1_783_078_400)
        )
        try firstStore.saveDraft(draft)
        try firstStore.deleteDraft(id: draft.id)

        let secondStore = FileDraftStore(rootDirectory: rootURL)

        #expect(try secondStore.loadDraft(id: draft.id) == nil)
    }

    @Test("draft titles are normalized")
    func draftTitlesAreNormalized() throws {
        let paddedDraft = DraftDocument(
            id: "padded",
            title: "  A Tidy Page  ",
            markdown: "# A Tidy Page",
            updatedAt: Date(timeIntervalSince1970: 1_783_078_400)
        )
        let blankDraft = DraftDocument(
            id: "blank",
            title: "\n\t ",
            markdown: "# Untitled Page",
            updatedAt: Date(timeIntervalSince1970: 1_783_078_401)
        )

        #expect(paddedDraft.title == "A Tidy Page")
        #expect(blankDraft.title == "Untitled Page")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DraftDocument.self, from: encoder.encode(paddedDraft))

        #expect(decoded.title == "A Tidy Page")
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

    @Test("bookmark nicknames are normalized")
    func bookmarkNicknamesAreNormalized() throws {
        let paddedBookmark = ForkBookmark(
            address: "fork://author/example",
            title: "Original Title",
            nickname: "  Local Example  ",
            createdAt: Date(timeIntervalSince1970: 1_783_078_400)
        )
        let blankBookmark = ForkBookmark(
            address: "fork://doc/example",
            title: "Document Title",
            nickname: "\n\t ",
            createdAt: Date(timeIntervalSince1970: 1_783_078_401)
        )

        #expect(paddedBookmark.nickname == "Local Example")
        #expect(paddedBookmark.displayTitle == "Local Example")
        #expect(blankBookmark.nickname == nil)
        #expect(blankBookmark.displayTitle == "Document Title")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ForkBookmark.self, from: encoder.encode(paddedBookmark))

        #expect(decoded.nickname == "Local Example")
        #expect(decoded.displayTitle == "Local Example")
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
        let manifest = try restartedReader.exportManifest(authorAddress)
        let documentAddress = try ForkAddress(manifest.payload.homeDocument)
        let cachedDocumentPage = try restartedReader.render(documentAddress)

        #expect(cachedPage.source == .cache(now))
        #expect(cachedDocumentPage.source == .cache(now))
        #expect(cachedPage.markdown.contains("Still here offline."))
        #expect(cachedDocumentPage.markdown.contains("Still here offline."))
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

    @Test("cached peer can re-serve verified author bundle")
    func cachedPeerCanReServeVerifiedAuthorBundle() throws {
        let firstFetch = Date(timeIntervalSince1970: 1_783_078_400)
        let secondFetch = Date(timeIntervalSince1970: 1_783_078_500)
        let authorPeer = LocalPeer(name: "Author")
        let firstReader = LocalPeer(name: "First Reader")
        let secondReader = LocalPeer(name: "Second Reader")
        let authorAddress = authorPeer.createAuthorIdentity()
        try authorPeer.publishHomePage(
            title: "Shared Cache",
            markdown: "# Shared Cache\n\nOne reader can help another.",
            createdAt: firstFetch
        )

        try firstReader.fetchAuthor(authorAddress, from: authorPeer, at: firstFetch)
        try secondReader.fetchAuthor(authorAddress, from: firstReader, at: secondFetch)
        let cachedPage = try secondReader.renderAuthor(authorAddress)

        #expect(cachedPage.source == .cache(secondFetch))
        #expect(cachedPage.title == "Shared Cache")
        #expect(cachedPage.markdown.contains("One reader can help another."))
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

    @Test("author bundle drops documents removed from latest manifest")
    func authorBundleDropsDocumentsRemovedFromLatestManifest() throws {
        let firstDate = Date(timeIntervalSince1970: 1_783_078_400)
        let secondDate = Date(timeIntervalSince1970: 1_783_078_500)
        let authorPeer = LocalPeer(name: "Author")
        let authorAddress = authorPeer.createAuthorIdentity()
        let homeIdentity = ForkIdentity(role: .document)
        let removedIdentity = ForkIdentity(role: .document)
        try authorPeer.publishDocuments(
            [
                LocalDocumentPublication(
                    identity: homeIdentity,
                    title: "Home",
                    markdown: "# Home"
                ),
                LocalDocumentPublication(
                    identity: removedIdentity,
                    title: "Removed",
                    markdown: "# Removed"
                )
            ],
            homeDocument: homeIdentity.address,
            createdAt: firstDate
        )

        try authorPeer.publishDocuments(
            [
                LocalDocumentPublication(
                    identity: homeIdentity,
                    title: "Home",
                    markdown: "# Home\n\nStill here."
                )
            ],
            homeDocument: homeIdentity.address,
            createdAt: secondDate
        )

        let bundle = try authorPeer.exportAuthorBundle(authorAddress)

        #expect(bundle.manifest.payload.documents.map(\.address) == [
            homeIdentity.address.rawValue
        ])
        #expect(bundle.documents.map(\.payload.documentPublicKey) == [
            homeIdentity.address.key
        ])
        #expect(!bundle.documents.map(\.payload.documentPublicKey).contains(removedIdentity.address.key))
    }

    @Test("incomplete author bundles are rejected without caching")
    func incompleteAuthorBundlesAreRejectedWithoutCaching() throws {
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
                    markdown: "# Home"
                ),
                LocalDocumentPublication(
                    identity: aboutIdentity,
                    title: "About",
                    markdown: "# About"
                )
            ],
            homeDocument: homeIdentity.address,
            createdAt: now
        )
        let completeBundle = try authorPeer.exportAuthorBundle(authorAddress)
        let incompleteBundle = AuthorRecordBundle(
            manifest: completeBundle.manifest,
            documents: [completeBundle.documents[0]]
        )

        #expect(throws: ForkError.invalidSignature) {
            try readerPeer.importAuthorBundle(
                incompleteBundle,
                expectedAuthor: authorAddress,
                cachedAt: now
            )
        }
        #expect(throws: ForkError.missingManifest(authorAddress)) {
            try readerPeer.renderAuthor(authorAddress)
        }
    }

    @Test("author bundles reject duplicate document records")
    func authorBundlesRejectDuplicateDocumentRecords() throws {
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
                    markdown: "# Home"
                ),
                LocalDocumentPublication(
                    identity: aboutIdentity,
                    title: "About",
                    markdown: "# About"
                )
            ],
            homeDocument: homeIdentity.address,
            createdAt: now
        )
        let completeBundle = try authorPeer.exportAuthorBundle(authorAddress)
        let duplicatedBundle = AuthorRecordBundle(
            manifest: completeBundle.manifest,
            documents: [completeBundle.documents[0], completeBundle.documents[0]]
        )

        #expect(throws: ForkError.invalidSignature) {
            try readerPeer.importAuthorBundle(
                duplicatedBundle,
                expectedAuthor: authorAddress,
                cachedAt: now
            )
        }
        #expect(throws: ForkError.missingManifest(authorAddress)) {
            try readerPeer.renderAuthor(authorAddress)
        }
    }

    @Test("author bundles reject manifest titles that do not match documents")
    func authorBundlesRejectMismatchedManifestTitles() throws {
        let now = Date(timeIntervalSince1970: 1_783_078_400)
        let authorIdentity = ForkIdentity(role: .author)
        let documentIdentity = ForkIdentity(role: .document)
        let readerPeer = LocalPeer(name: "Reader")
        let documentPayload = DocumentRecordPayload(
            documentPublicKey: Base64URL.encode(documentIdentity.publicKeyData),
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            title: "Signed Document Title",
            markdown: "# Signed Document Title",
            version: 1,
            previous: nil,
            createdAt: now
        )
        let document = try ForkRecordSigner.signDocument(
            payload: documentPayload,
            with: documentIdentity
        )
        let manifestPayload = AuthorManifestPayload(
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            version: 1,
            previous: nil,
            homeDocument: documentIdentity.address.rawValue,
            documents: [
                AuthorManifestDocument(
                    address: documentIdentity.address.rawValue,
                    role: "home",
                    title: "Different Manifest Title"
                )
            ],
            createdAt: now
        )
        let manifest = try ForkRecordSigner.signManifest(
            payload: manifestPayload,
            with: authorIdentity
        )

        #expect(throws: ForkError.invalidSignature) {
            try readerPeer.importAuthorBundle(
                AuthorRecordBundle(manifest: manifest, documents: [document]),
                expectedAuthor: authorIdentity.address,
                cachedAt: now
            )
        }
        #expect(throws: ForkError.missingManifest(authorIdentity.address)) {
            try readerPeer.renderAuthor(authorIdentity.address)
        }
    }

    @Test("author bundles reject bad update chains without partial caching")
    func authorBundlesRejectBadUpdateChainsWithoutPartialCaching() throws {
        let firstDate = Date(timeIntervalSince1970: 1_783_078_400)
        let secondDate = Date(timeIntervalSince1970: 1_783_078_500)
        let authorIdentity = ForkIdentity(role: .author)
        let documentIdentity = ForkIdentity(role: .document)
        let readerPeer = LocalPeer(name: "Reader")
        let firstDocumentPayload = DocumentRecordPayload(
            documentPublicKey: Base64URL.encode(documentIdentity.publicKeyData),
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            title: "First",
            markdown: "# First",
            version: 1,
            previous: nil,
            createdAt: firstDate
        )
        let firstDocument = try ForkRecordSigner.signDocument(
            payload: firstDocumentPayload,
            with: documentIdentity
        )
        let firstManifestPayload = AuthorManifestPayload(
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            version: 1,
            previous: nil,
            homeDocument: documentIdentity.address.rawValue,
            documents: [
                AuthorManifestDocument(
                    address: documentIdentity.address.rawValue,
                    role: "home",
                    title: "First"
                )
            ],
            createdAt: firstDate
        )
        let firstManifest = try ForkRecordSigner.signManifest(
            payload: firstManifestPayload,
            with: authorIdentity
        )
        try readerPeer.importAuthorBundle(
            AuthorRecordBundle(manifest: firstManifest, documents: [firstDocument]),
            expectedAuthor: authorIdentity.address,
            cachedAt: firstDate
        )

        let secondDocumentPayload = DocumentRecordPayload(
            documentPublicKey: Base64URL.encode(documentIdentity.publicKeyData),
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            title: "Second",
            markdown: "# Second",
            version: 2,
            previous: Base64URL.encode(Data(repeating: 1, count: 32)),
            createdAt: secondDate
        )
        let secondDocument = try ForkRecordSigner.signDocument(
            payload: secondDocumentPayload,
            with: documentIdentity
        )
        let secondManifestPayload = AuthorManifestPayload(
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            version: 2,
            previous: try ForkRecordHasher.hash(firstManifest),
            homeDocument: documentIdentity.address.rawValue,
            documents: [
                AuthorManifestDocument(
                    address: documentIdentity.address.rawValue,
                    role: "home",
                    title: "Second"
                )
            ],
            createdAt: secondDate
        )
        let secondManifest = try ForkRecordSigner.signManifest(
            payload: secondManifestPayload,
            with: authorIdentity
        )

        #expect(throws: ForkError.invalidSignature) {
            try readerPeer.importAuthorBundle(
                AuthorRecordBundle(manifest: secondManifest, documents: [secondDocument]),
                expectedAuthor: authorIdentity.address,
                cachedAt: secondDate
            )
        }
        let cachedManifest = try readerPeer.exportManifest(authorIdentity.address)
        let cachedPage = try readerPeer.renderAuthor(authorIdentity.address)

        #expect(cachedManifest == firstManifest)
        #expect(cachedPage.title == "First")
        #expect(cachedPage.source == .cache(firstDate))
    }

    @Test("author bundles reject home documents missing from manifest page list")
    func authorBundlesRejectUnlistedHomeDocument() throws {
        let now = Date(timeIntervalSince1970: 1_783_078_400)
        let authorIdentity = ForkIdentity(role: .author)
        let listedIdentity = ForkIdentity(role: .document)
        let unlistedHomeIdentity = ForkIdentity(role: .document)
        let readerPeer = LocalPeer(name: "Reader")
        let listedDocumentPayload = DocumentRecordPayload(
            documentPublicKey: Base64URL.encode(listedIdentity.publicKeyData),
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            title: "Listed",
            markdown: "# Listed",
            version: 1,
            previous: nil,
            createdAt: now
        )
        let listedDocument = try ForkRecordSigner.signDocument(
            payload: listedDocumentPayload,
            with: listedIdentity
        )
        let manifestPayload = AuthorManifestPayload(
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            version: 1,
            previous: nil,
            homeDocument: unlistedHomeIdentity.address.rawValue,
            documents: [
                AuthorManifestDocument(
                    address: listedIdentity.address.rawValue,
                    role: "page",
                    title: "Listed"
                )
            ],
            createdAt: now
        )
        let manifest = try ForkRecordSigner.signManifest(
            payload: manifestPayload,
            with: authorIdentity
        )
        let bundle = AuthorRecordBundle(
            manifest: manifest,
            documents: [listedDocument]
        )

        #expect(throws: ForkError.invalidSignature) {
            try readerPeer.importAuthorBundle(
                bundle,
                expectedAuthor: authorIdentity.address,
                cachedAt: now
            )
        }
        #expect(throws: ForkError.missingManifest(authorIdentity.address)) {
            try readerPeer.renderAuthor(authorIdentity.address)
        }
    }

    @Test("direct manifest accept rejects invalid page lists")
    func directManifestAcceptRejectsInvalidPageLists() throws {
        let now = Date(timeIntervalSince1970: 1_783_078_400)
        let authorIdentity = ForkIdentity(role: .author)
        let listedIdentity = ForkIdentity(role: .document)
        let unlistedHomeIdentity = ForkIdentity(role: .document)
        let manifestPayload = AuthorManifestPayload(
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            version: 1,
            previous: nil,
            homeDocument: unlistedHomeIdentity.address.rawValue,
            documents: [
                AuthorManifestDocument(
                    address: listedIdentity.address.rawValue,
                    role: "page",
                    title: "Listed"
                )
            ],
            createdAt: now
        )
        let manifest = try ForkRecordSigner.signManifest(
            payload: manifestPayload,
            with: authorIdentity
        )
        let readerPeer = LocalPeer(name: "Reader")

        #expect(throws: ForkError.invalidSignature) {
            try readerPeer.accept(manifest: manifest, cachedAt: now)
        }
        #expect(throws: ForkError.missingManifest(authorIdentity.address)) {
            try readerPeer.renderAuthor(authorIdentity.address)
        }
    }

    @Test("direct manifest accept rejects duplicate page addresses")
    func directManifestAcceptRejectsDuplicatePageAddresses() throws {
        let now = Date(timeIntervalSince1970: 1_783_078_400)
        let authorIdentity = ForkIdentity(role: .author)
        let homeIdentity = ForkIdentity(role: .document)
        let manifestPayload = AuthorManifestPayload(
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            version: 1,
            previous: nil,
            homeDocument: homeIdentity.address.rawValue,
            documents: [
                AuthorManifestDocument(
                    address: homeIdentity.address.rawValue,
                    role: "home",
                    title: "Home"
                ),
                AuthorManifestDocument(
                    address: homeIdentity.address.rawValue,
                    role: "home",
                    title: "Home Again"
                )
            ],
            createdAt: now
        )
        let manifest = try ForkRecordSigner.signManifest(
            payload: manifestPayload,
            with: authorIdentity
        )
        let readerPeer = LocalPeer(name: "Reader")

        #expect(throws: ForkError.invalidSignature) {
            try readerPeer.accept(manifest: manifest, cachedAt: now)
        }
        #expect(throws: ForkError.missingManifest(authorIdentity.address)) {
            try readerPeer.renderAuthor(authorIdentity.address)
        }
    }

    @Test("direct manifest accept rejects mismatched page roles")
    func directManifestAcceptRejectsMismatchedPageRoles() throws {
        let now = Date(timeIntervalSince1970: 1_783_078_400)
        let authorIdentity = ForkIdentity(role: .author)
        let homeIdentity = ForkIdentity(role: .document)
        let aboutIdentity = ForkIdentity(role: .document)
        let manifestPayload = AuthorManifestPayload(
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            version: 1,
            previous: nil,
            homeDocument: homeIdentity.address.rawValue,
            documents: [
                AuthorManifestDocument(
                    address: homeIdentity.address.rawValue,
                    role: "page",
                    title: "Home"
                ),
                AuthorManifestDocument(
                    address: aboutIdentity.address.rawValue,
                    role: "home",
                    title: "About"
                )
            ],
            createdAt: now
        )
        let manifest = try ForkRecordSigner.signManifest(
            payload: manifestPayload,
            with: authorIdentity
        )
        let readerPeer = LocalPeer(name: "Reader")

        #expect(throws: ForkError.invalidSignature) {
            try readerPeer.accept(manifest: manifest, cachedAt: now)
        }
        #expect(throws: ForkError.missingManifest(authorIdentity.address)) {
            try readerPeer.renderAuthor(authorIdentity.address)
        }
    }

    @Test("direct manifest accept rejects malformed document addresses")
    func directManifestAcceptRejectsMalformedDocumentAddresses() throws {
        let now = Date(timeIntervalSince1970: 1_783_078_400)
        let authorIdentity = ForkIdentity(role: .author)
        let malformedAddress = ForkAddress(
            kind: .document,
            publicKeyData: Data(repeating: 0, count: 31)
        )
        let manifestPayload = AuthorManifestPayload(
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            version: 1,
            previous: nil,
            homeDocument: malformedAddress.rawValue,
            documents: [
                AuthorManifestDocument(
                    address: malformedAddress.rawValue,
                    role: "home",
                    title: "Malformed"
                )
            ],
            createdAt: now
        )
        let manifest = try ForkRecordSigner.signManifest(
            payload: manifestPayload,
            with: authorIdentity
        )
        let readerPeer = LocalPeer(name: "Reader")

        #expect(try ForkRecordSigner.verify(manifest) == true)
        #expect(throws: ForkError.invalidSignature) {
            try readerPeer.accept(manifest: manifest, cachedAt: now)
        }
        #expect(throws: ForkError.missingManifest(authorIdentity.address)) {
            try readerPeer.renderAuthor(authorIdentity.address)
        }
    }

    @Test("manifests with the wrong type are refused")
    func manifestsWithWrongTypeAreRefused() throws {
        let now = Date(timeIntervalSince1970: 1_783_078_400)
        let authorIdentity = ForkIdentity(role: .author)
        let homeIdentity = ForkIdentity(role: .document)
        var manifestPayload = AuthorManifestPayload(
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            version: 1,
            previous: nil,
            homeDocument: homeIdentity.address.rawValue,
            documents: [
                AuthorManifestDocument(
                    address: homeIdentity.address.rawValue,
                    role: "home",
                    title: "Home"
                )
            ],
            createdAt: now
        )
        manifestPayload.type = "fork.documentRecord"
        let manifest = try ForkRecordSigner.signManifest(
            payload: manifestPayload,
            with: authorIdentity
        )
        let readerPeer = LocalPeer(name: "Reader")

        #expect(try ForkRecordSigner.verify(manifest) == false)
        #expect(throws: ForkError.invalidSignature) {
            try readerPeer.accept(manifest: manifest, cachedAt: now)
        }
        #expect(throws: ForkError.missingManifest(authorIdentity.address)) {
            try readerPeer.renderAuthor(authorIdentity.address)
        }
    }

    @Test("published updates link to previous signed records")
    func publishedUpdatesLinkToPreviousSignedRecords() throws {
        let firstDate = Date(timeIntervalSince1970: 1_783_078_400)
        let secondDate = Date(timeIntervalSince1970: 1_783_078_500)
        let authorPeer = LocalPeer(name: "Author")
        let authorAddress = authorPeer.createAuthorIdentity()
        let documentIdentity = ForkIdentity(role: .document)
        authorPeer.useDocumentIdentity(documentIdentity)

        let first = try authorPeer.publishHomePage(
            title: "First",
            markdown: "# First",
            createdAt: firstDate
        )
        let second = try authorPeer.publishHomePage(
            title: "Second",
            markdown: "# Second",
            createdAt: secondDate
        )

        let latestManifest = try authorPeer.exportManifest(authorAddress)
        let latestDocument = try authorPeer.exportDocument(documentIdentity.address)
        let renderedPage = try authorPeer.renderAuthor(authorAddress)

        #expect(first.manifest.payload.previous == nil)
        #expect(first.document.payload.previous == nil)
        #expect(second.manifest.payload.previous == (try ForkRecordHasher.hash(first.manifest)))
        #expect(second.document.payload.previous == (try ForkRecordHasher.hash(first.document)))
        #expect(second.manifest.payload.version == 2)
        #expect(second.document.payload.version == 2)
        #expect(latestManifest == second.manifest)
        #expect(latestDocument == second.document)
        #expect(renderedPage.version == second.document.payload.version)
        #expect(renderedPage.previous == second.document.payload.previous)
    }

    @Test("same-version document records do not replace cached records")
    func sameVersionDocumentRecordsDoNotReplaceCachedRecords() throws {
        let firstDate = Date(timeIntervalSince1970: 1_783_078_400)
        let secondDate = Date(timeIntervalSince1970: 1_783_078_500)
        let authorIdentity = ForkIdentity(role: .author)
        let documentIdentity = ForkIdentity(role: .document)
        let firstPayload = DocumentRecordPayload(
            documentPublicKey: Base64URL.encode(documentIdentity.publicKeyData),
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            title: "First",
            markdown: "# First",
            version: 1,
            previous: nil,
            createdAt: firstDate
        )
        let secondPayload = DocumentRecordPayload(
            documentPublicKey: Base64URL.encode(documentIdentity.publicKeyData),
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            title: "Second",
            markdown: "# Second",
            version: 1,
            previous: nil,
            createdAt: secondDate
        )
        let firstRecord = try ForkRecordSigner.signDocument(
            payload: firstPayload,
            with: documentIdentity
        )
        let secondRecord = try ForkRecordSigner.signDocument(
            payload: secondPayload,
            with: documentIdentity
        )
        let peer = LocalPeer(name: "Reader")

        try peer.accept(document: firstRecord, cachedAt: firstDate)
        try peer.accept(document: secondRecord, cachedAt: secondDate)
        let page = try peer.render(documentIdentity.address)

        #expect(page.title == "First")
        #expect(page.markdown == "# First")
        #expect(page.source == .cache(firstDate))
    }

    @Test("older document records do not replace cached records")
    func olderDocumentRecordsDoNotReplaceCachedRecords() throws {
        let firstDate = Date(timeIntervalSince1970: 1_783_078_400)
        let secondDate = Date(timeIntervalSince1970: 1_783_078_500)
        let authorIdentity = ForkIdentity(role: .author)
        let documentIdentity = ForkIdentity(role: .document)
        let newerPayload = DocumentRecordPayload(
            documentPublicKey: Base64URL.encode(documentIdentity.publicKeyData),
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            title: "Newer",
            markdown: "# Newer",
            version: 2,
            previous: nil,
            createdAt: firstDate
        )
        let olderPayload = DocumentRecordPayload(
            documentPublicKey: Base64URL.encode(documentIdentity.publicKeyData),
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            title: "Older",
            markdown: "# Older",
            version: 1,
            previous: nil,
            createdAt: secondDate
        )
        let peer = LocalPeer(name: "Reader")

        try peer.accept(
            document: try ForkRecordSigner.signDocument(payload: newerPayload, with: documentIdentity),
            cachedAt: firstDate
        )
        try peer.accept(
            document: try ForkRecordSigner.signDocument(payload: olderPayload, with: documentIdentity),
            cachedAt: secondDate
        )
        let page = try peer.render(documentIdentity.address)

        #expect(page.title == "Newer")
        #expect(page.markdown == "# Newer")
        #expect(page.version == 2)
        #expect(page.source == .cache(firstDate))
    }

    @Test("newer document records must link to cached records")
    func newerDocumentRecordsMustLinkToCachedRecords() throws {
        let firstDate = Date(timeIntervalSince1970: 1_783_078_400)
        let secondDate = Date(timeIntervalSince1970: 1_783_078_500)
        let authorIdentity = ForkIdentity(role: .author)
        let documentIdentity = ForkIdentity(role: .document)
        let firstPayload = DocumentRecordPayload(
            documentPublicKey: Base64URL.encode(documentIdentity.publicKeyData),
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            title: "First",
            markdown: "# First",
            version: 1,
            previous: nil,
            createdAt: firstDate
        )
        let secondPayload = DocumentRecordPayload(
            documentPublicKey: Base64URL.encode(documentIdentity.publicKeyData),
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            title: "Second",
            markdown: "# Second",
            version: 2,
            previous: Base64URL.encode(Data(repeating: 1, count: 32)),
            createdAt: secondDate
        )
        let peer = LocalPeer(name: "Reader")

        try peer.accept(
            document: try ForkRecordSigner.signDocument(payload: firstPayload, with: documentIdentity),
            cachedAt: firstDate
        )
        #expect(throws: ForkError.invalidSignature) {
            try peer.accept(
                document: try ForkRecordSigner.signDocument(payload: secondPayload, with: documentIdentity),
                cachedAt: secondDate
            )
        }
        let page = try peer.render(documentIdentity.address)

        #expect(page.title == "First")
        #expect(page.version == 1)
        #expect(page.source == .cache(firstDate))
    }

    @Test("same-version manifests do not replace cached manifests")
    func sameVersionManifestsDoNotReplaceCachedManifests() throws {
        let firstDate = Date(timeIntervalSince1970: 1_783_078_400)
        let secondDate = Date(timeIntervalSince1970: 1_783_078_500)
        let authorIdentity = ForkIdentity(role: .author)
        let homeIdentity = ForkIdentity(role: .document)
        let alternateIdentity = ForkIdentity(role: .document)
        let homeDocumentPayload = DocumentRecordPayload(
            documentPublicKey: Base64URL.encode(homeIdentity.publicKeyData),
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            title: "Home",
            markdown: "# Home",
            version: 1,
            previous: nil,
            createdAt: firstDate
        )
        let alternateDocumentPayload = DocumentRecordPayload(
            documentPublicKey: Base64URL.encode(alternateIdentity.publicKeyData),
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            title: "Alternate",
            markdown: "# Alternate",
            version: 1,
            previous: nil,
            createdAt: secondDate
        )
        let firstManifestPayload = AuthorManifestPayload(
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            version: 1,
            previous: nil,
            homeDocument: homeIdentity.address.rawValue,
            documents: [
                AuthorManifestDocument(
                    address: homeIdentity.address.rawValue,
                    role: "home",
                    title: "Home"
                )
            ],
            createdAt: firstDate
        )
        let secondManifestPayload = AuthorManifestPayload(
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            version: 1,
            previous: nil,
            homeDocument: alternateIdentity.address.rawValue,
            documents: [
                AuthorManifestDocument(
                    address: alternateIdentity.address.rawValue,
                    role: "home",
                    title: "Alternate"
                )
            ],
            createdAt: secondDate
        )
        let peer = LocalPeer(name: "Reader")

        try peer.accept(
            document: try ForkRecordSigner.signDocument(payload: homeDocumentPayload, with: homeIdentity),
            cachedAt: firstDate
        )
        try peer.accept(
            document: try ForkRecordSigner.signDocument(payload: alternateDocumentPayload, with: alternateIdentity),
            cachedAt: secondDate
        )
        try peer.accept(
            manifest: try ForkRecordSigner.signManifest(payload: firstManifestPayload, with: authorIdentity),
            cachedAt: firstDate
        )
        try peer.accept(
            manifest: try ForkRecordSigner.signManifest(payload: secondManifestPayload, with: authorIdentity),
            cachedAt: secondDate
        )
        let page = try peer.renderAuthor(authorIdentity.address)

        #expect(page.title == "Home")
        #expect(page.documentAddress == homeIdentity.address)
        #expect(page.source == .cache(firstDate))
    }

    @Test("older manifests do not replace cached manifests")
    func olderManifestsDoNotReplaceCachedManifests() throws {
        let firstDate = Date(timeIntervalSince1970: 1_783_078_400)
        let secondDate = Date(timeIntervalSince1970: 1_783_078_500)
        let authorIdentity = ForkIdentity(role: .author)
        let homeIdentity = ForkIdentity(role: .document)
        let alternateIdentity = ForkIdentity(role: .document)
        let homeDocumentPayload = DocumentRecordPayload(
            documentPublicKey: Base64URL.encode(homeIdentity.publicKeyData),
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            title: "Home",
            markdown: "# Home",
            version: 1,
            previous: nil,
            createdAt: firstDate
        )
        let alternateDocumentPayload = DocumentRecordPayload(
            documentPublicKey: Base64URL.encode(alternateIdentity.publicKeyData),
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            title: "Alternate",
            markdown: "# Alternate",
            version: 1,
            previous: nil,
            createdAt: secondDate
        )
        let newerManifestPayload = AuthorManifestPayload(
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            version: 2,
            previous: nil,
            homeDocument: homeIdentity.address.rawValue,
            documents: [
                AuthorManifestDocument(
                    address: homeIdentity.address.rawValue,
                    role: "home",
                    title: "Home"
                )
            ],
            createdAt: firstDate
        )
        let olderManifestPayload = AuthorManifestPayload(
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            version: 1,
            previous: nil,
            homeDocument: alternateIdentity.address.rawValue,
            documents: [
                AuthorManifestDocument(
                    address: alternateIdentity.address.rawValue,
                    role: "home",
                    title: "Alternate"
                )
            ],
            createdAt: secondDate
        )
        let peer = LocalPeer(name: "Reader")

        try peer.accept(
            document: try ForkRecordSigner.signDocument(payload: homeDocumentPayload, with: homeIdentity),
            cachedAt: firstDate
        )
        try peer.accept(
            document: try ForkRecordSigner.signDocument(payload: alternateDocumentPayload, with: alternateIdentity),
            cachedAt: secondDate
        )
        try peer.accept(
            manifest: try ForkRecordSigner.signManifest(payload: newerManifestPayload, with: authorIdentity),
            cachedAt: firstDate
        )
        try peer.accept(
            manifest: try ForkRecordSigner.signManifest(payload: olderManifestPayload, with: authorIdentity),
            cachedAt: secondDate
        )
        let page = try peer.renderAuthor(authorIdentity.address)

        #expect(page.title == "Home")
        #expect(page.documentAddress == homeIdentity.address)
        #expect(page.version == 1)
        #expect(page.source == .cache(firstDate))
    }

    @Test("newer manifests must link to cached manifests")
    func newerManifestsMustLinkToCachedManifests() throws {
        let firstDate = Date(timeIntervalSince1970: 1_783_078_400)
        let secondDate = Date(timeIntervalSince1970: 1_783_078_500)
        let authorIdentity = ForkIdentity(role: .author)
        let homeIdentity = ForkIdentity(role: .document)
        let firstDocumentPayload = DocumentRecordPayload(
            documentPublicKey: Base64URL.encode(homeIdentity.publicKeyData),
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            title: "Home",
            markdown: "# Home",
            version: 1,
            previous: nil,
            createdAt: firstDate
        )
        let firstDocument = try ForkRecordSigner.signDocument(
            payload: firstDocumentPayload,
            with: homeIdentity
        )
        let secondDocumentPayload = DocumentRecordPayload(
            documentPublicKey: Base64URL.encode(homeIdentity.publicKeyData),
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            title: "Home",
            markdown: "# Home\n\nSecond document is fine.",
            version: 2,
            previous: try ForkRecordHasher.hash(firstDocument),
            createdAt: secondDate
        )
        let firstManifestPayload = AuthorManifestPayload(
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            version: 1,
            previous: nil,
            homeDocument: homeIdentity.address.rawValue,
            documents: [
                AuthorManifestDocument(
                    address: homeIdentity.address.rawValue,
                    role: "home",
                    title: "Home"
                )
            ],
            createdAt: firstDate
        )
        let secondManifestPayload = AuthorManifestPayload(
            authorPublicKey: Base64URL.encode(authorIdentity.publicKeyData),
            version: 2,
            previous: Base64URL.encode(Data(repeating: 1, count: 32)),
            homeDocument: homeIdentity.address.rawValue,
            documents: [
                AuthorManifestDocument(
                    address: homeIdentity.address.rawValue,
                    role: "home",
                    title: "Second Home"
                )
            ],
            createdAt: secondDate
        )
        let peer = LocalPeer(name: "Reader")

        try peer.accept(
            document: firstDocument,
            cachedAt: firstDate
        )
        try peer.accept(
            manifest: try ForkRecordSigner.signManifest(payload: firstManifestPayload, with: authorIdentity),
            cachedAt: firstDate
        )
        #expect(throws: ForkError.invalidSignature) {
            try peer.accept(
                manifest: try ForkRecordSigner.signManifest(payload: secondManifestPayload, with: authorIdentity),
                cachedAt: secondDate
            )
        }
        try peer.accept(
            document: try ForkRecordSigner.signDocument(payload: secondDocumentPayload, with: homeIdentity),
            cachedAt: secondDate
        )
        let page = try peer.renderAuthor(authorIdentity.address)

        #expect(page.title == "Home")
        #expect(page.source == .cache(firstDate))
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

    @Test("loopback transport can fetch multiple local authors")
    func loopbackTransportFetchesMultipleAuthors() throws {
        let now = Date(timeIntervalSince1970: 1_783_078_400)
        let firstAuthor = LocalPeer(name: "First Author")
        let secondAuthor = LocalPeer(name: "Second Author")
        let readerPeer = LocalPeer(name: "Reader")
        let firstAddress = firstAuthor.createAuthorIdentity()
        let secondAddress = secondAuthor.createAuthorIdentity()
        try firstAuthor.publishHomePage(
            title: "First Place",
            markdown: "# First Place",
            createdAt: now
        )
        try secondAuthor.publishHomePage(
            title: "Second Place",
            markdown: "# Second Place",
            createdAt: now
        )

        let firstServer = try LoopbackAuthorBundleServer(peer: firstAuthor)
        let secondServer = try LoopbackAuthorBundleServer(peer: secondAuthor)
        try firstServer.start()
        try secondServer.start()
        defer {
            firstServer.stop()
            secondServer.stop()
        }

        let firstClient = try LoopbackAuthorBundleClient(baseURL: firstServer.baseURL)
        let secondClient = try LoopbackAuthorBundleClient(baseURL: secondServer.baseURL)
        let firstPage = try readerPeer.renderAuthor(
            firstAddress,
            preferLiveSource: firstClient,
            fetchedAt: now
        )
        let secondPage = try readerPeer.renderAuthor(
            secondAddress,
            preferLiveSource: secondClient,
            fetchedAt: now
        )

        #expect(firstPage.source == .live)
        #expect(secondPage.source == .live)
        #expect(firstPage.title == "First Place")
        #expect(secondPage.title == "Second Place")
    }

    @Test("loopback render falls back to cache when live source is unavailable")
    func loopbackRenderFallsBackToCacheWhenLiveSourceIsUnavailable() throws {
        let liveDate = Date(timeIntervalSince1970: 1_783_078_400)
        let cachedDate = Date(timeIntervalSince1970: 1_783_078_500)
        let authorPeer = LocalPeer(name: "Author")
        let readerPeer = LocalPeer(name: "Reader")
        let authorAddress = authorPeer.createAuthorIdentity()
        try authorPeer.publishHomePage(
            title: "Sometimes Offline",
            markdown: "# Sometimes Offline",
            createdAt: liveDate
        )

        let server = try LoopbackAuthorBundleServer(peer: authorPeer)
        try server.start()
        let client = try LoopbackAuthorBundleClient(baseURL: server.baseURL)
        let livePage = try readerPeer.renderAuthor(
            authorAddress,
            preferLiveSource: client,
            fetchedAt: liveDate
        )
        server.stop()
        let unavailableClient = LoopbackAuthorBundleClient(
            baseURL: URL(string: "http://127.0.0.1:1")!
        )

        let cachedPage = try readerPeer.renderAuthor(
            authorAddress,
            preferLiveSource: unavailableClient,
            fetchedAt: cachedDate
        )

        #expect(livePage.source == .live)
        #expect(cachedPage.source == .cache(liveDate))
        #expect(cachedPage.title == "Sometimes Offline")
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

        #expect(throws: ForkError.missingManifest(authorAddress)) {
            try restartedReader.renderAuthor(authorAddress)
        }
    }

    @Test("cached manifest titles must still match documents after restart")
    func cachedManifestTitlesMustStillMatchDocumentsAfterRestart() throws {
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

        let manifestURL = rootURL
            .appendingPathComponent("manifests", isDirectory: true)
            .appendingPathComponent("\(authorAddress.key).json")
        var cachedManifest = try JSONDecoder.fork.decode(
            CachedAuthorManifest.self,
            from: Data(contentsOf: manifestURL)
        )
        cachedManifest.record.payload.documents[0].title = "Forged Title"
        try JSONEncoder.fork.encode(cachedManifest).write(to: manifestURL, options: [.atomic])

        let restartedReader = try LocalPeer(
            name: "Restarted Reader",
            recordCache: FileRecordCache(rootDirectory: rootURL)
        )

        #expect(throws: ForkError.missingManifest(authorAddress)) {
            try restartedReader.renderAuthor(authorAddress)
        }
    }

    @Test("incomplete cache bundles are ignored on restart")
    func incompleteCacheBundlesAreIgnoredOnRestart() throws {
        let rootURL = temporaryDirectory()
        let cache = FileRecordCache(rootDirectory: rootURL)
        let now = Date(timeIntervalSince1970: 1_783_078_400)

        let authorPeer = LocalPeer(name: "Author")
        let authorAddress = authorPeer.createAuthorIdentity()
        try authorPeer.publishHomePage(
            title: "Cached Place",
            markdown: "# Cached Place\n\nNeeds its document.",
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
        try FileManager.default.removeItem(at: documentURL)

        let restartedReader = try LocalPeer(
            name: "Restarted Reader",
            recordCache: FileRecordCache(rootDirectory: rootURL)
        )

        #expect(throws: ForkError.missingManifest(authorAddress)) {
            try restartedReader.renderAuthor(authorAddress)
        }
        #expect(throws: ForkError.missingDocument(documentAddress)) {
            try restartedReader.render(documentAddress)
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
