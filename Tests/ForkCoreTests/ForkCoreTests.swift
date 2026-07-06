import Foundation
import Testing
@testable import ForkCore

@Suite("fork local editor")
struct ForkCoreTests {
    @Test("home draft is created when no pages exist")
    func homeDraftIsCreated() throws {
        let provider = StoredDraftProvider(store: MemoryDraftStore())
        let draft = try provider.loadOrCreateHomeDraft(now: Date(timeIntervalSince1970: 1_783_078_400))

        #expect(draft.id == "home")
        #expect(draft.title == "A Small Fork Place")
        #expect(draft.markdown.contains("# A Small Fork Place"))
    }

    @Test("draft titles are normalized")
    func draftTitlesAreNormalized() {
        let draft = DraftDocument(
            id: "draft",
            title: "  ",
            markdown: "",
            updatedAt: Date()
        )

        #expect(draft.title == "Untitled Page")
    }

    @Test("draft provider lists home first then ordered pages")
    func draftProviderListsHomeFirstThenPages() throws {
        let store = MemoryDraftStore()
        let provider = StoredDraftProvider(store: store)

        try store.saveDraft(DraftDocument(
            id: "later",
            title: "Later",
            markdown: "# Later",
            updatedAt: Date(timeIntervalSince1970: 30),
            pageOrder: 2
        ))
        try store.saveDraft(DraftDocument(
            id: "home",
            title: "Home",
            markdown: "# Home",
            updatedAt: Date(timeIntervalSince1970: 10),
            pageOrder: 0
        ))
        try store.saveDraft(DraftDocument(
            id: "first",
            title: "First",
            markdown: "# First",
            updatedAt: Date(timeIntervalSince1970: 20),
            pageOrder: 1
        ))

        #expect(try provider.loadDrafts().map(\.id) == ["home", "first", "later"])
    }

    @Test("draft provider refuses to delete home")
    func draftProviderRefusesToDeleteHome() throws {
        let provider = StoredDraftProvider(store: MemoryDraftStore())

        #expect(throws: ForkError.protectedDraft("home")) {
            try provider.deleteDraft(id: "home")
        }
    }

    @Test("file draft store survives restart")
    func fileDraftStoreSurvivesRestart() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let firstProvider = StoredDraftProvider(store: FileDraftStore(rootDirectory: root))
        try firstProvider.saveDraft(DraftDocument(
            id: "notes",
            title: "Notes",
            markdown: "# Notes",
            updatedAt: Date(timeIntervalSince1970: 1_783_078_400)
        ))

        let secondProvider = StoredDraftProvider(store: FileDraftStore(rootDirectory: root))
        let loadedDraft = try secondProvider.loadDraft(id: "notes")
        let draft = try #require(loadedDraft)

        #expect(draft.title == "Notes")
        #expect(draft.markdown == "# Notes")
    }
}
