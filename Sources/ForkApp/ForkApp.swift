import ForkCore
import AppKit
import Foundation
import SwiftUI

@main
struct ForkApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(model: ForkAppModel())
        }
    }
}

struct ContentView: View {
    @StateObject var model: ForkAppModel

    var body: some View {
        if let page = model.page {
            ForkShell(model: model, page: page)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Fork")
                    .font(.largeTitle)
                Text("The local Fork workspace could not start.")
                    .foregroundStyle(.secondary)
                Text(model.errorMessage ?? "Unknown error")
                    .font(.callout)
            }
            .padding(28)
            .frame(minWidth: 760, minHeight: 520)
        }
    }
}

private func forkCacheDirectory() throws -> URL {
    forkApplicationSupportDirectory()
        .appendingPathComponent("Records", isDirectory: true)
}

private func forkDraftDirectory() throws -> URL {
    forkApplicationSupportDirectory()
        .appendingPathComponent("Drafts", isDirectory: true)
}

private func forkBookmarksFile() throws -> URL {
    forkApplicationSupportDirectory()
        .appendingPathComponent("Bookmarks", isDirectory: true)
        .appendingPathComponent("bookmarks.json")
}

private func forkApplicationSupportDirectory() -> URL {
    let applicationSupport = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
    )[0]
    return applicationSupport
        .appendingPathComponent("Fork", isDirectory: true)
}

struct ForkShell: View {
    @ObservedObject var model: ForkAppModel
    let page: RenderedPage

    var body: some View {
        NavigationSplitView {
            List {
                Section("Read") {
                    Button {
                        model.visitOwnPlace()
                    } label: {
                        Label("My Place", systemImage: "doc.text")
                    }
                }

                if !model.placePages.isEmpty {
                    Section("Place") {
                        ForEach(model.placePages) { page in
                            Button {
                                model.visit(page.address)
                            } label: {
                                Label {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(page.title)
                                            .lineLimit(1)
                                        Text(page.subtitle)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                } icon: {
                                    Image(systemName: page.isHome ? "house" : "doc.text")
                                }
                            }
                        }
                    }
                }

                Section("History") {
                    ForEach(model.historyEntries) { entry in
                        Button {
                            model.visit(entry.address)
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title)
                                    Text(entry.address)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            } icon: {
                                Image(systemName: "clock")
                            }
                        }
                    }
                }

                Section("Bookmarks") {
                    ForEach(model.bookmarks) { bookmark in
                        Button {
                            model.visit(bookmark.address)
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bookmark.displayTitle)
                                    Text(bookmark.address)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            } icon: {
                                Image(systemName: "bookmark")
                            }
                        }
                    }
                }

                Section("Write") {
                    Button(action: model.createDraft) {
                        Label("New Page", systemImage: "plus")
                    }

                    ForEach(model.drafts) { draft in
                        Button {
                            model.selectDraft(draft.id)
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(draft.title)
                                    Text(draft.id == model.selectedDraftID ? "Editing" : draft.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: draft.id == model.selectedDraftID ? "square.and.pencil" : "doc")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Fork")
        } detail: {
            VStack(spacing: 0) {
                AddressBar(
                    address: $model.addressText,
                    bookmarkLabel: $model.bookmarkLabel,
                    status: model.statusMessage,
                    visit: model.visitAddress,
                    bookmark: model.bookmarkCurrentPage
                )
                Divider()

                HStack(spacing: 0) {
                    ReaderView(page: page)
                        .frame(minWidth: 420)

                    Divider()

                    WriterPreview(
                        title: $model.draftTitle,
                        markdown: $model.draftMarkdown,
                        status: model.statusMessage,
                        saveDraft: model.saveDraft,
                        publish: model.publish
                    )
                        .frame(minWidth: 300)
                }
            }
            .toolbar {
                ToolbarItemGroup {
                    Button(action: model.goBack) {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .disabled(!model.canGoBack)

                    Button(action: model.goForward) {
                        Label("Forward", systemImage: "chevron.right")
                    }
                    .disabled(!model.canGoForward)

                    Button(action: model.bookmarkCurrentPage) {
                        Label("Bookmark", systemImage: "bookmark")
                    }
                }
            }
        }
        .frame(minWidth: 920, minHeight: 620)
    }
}

struct ForkHistoryEntry: Identifiable, Equatable {
    let id: String
    let address: String
    let title: String
}

struct ForkPlacePage: Identifiable, Equatable {
    let id: String
    let address: String
    let title: String
    let role: String
    let isCurrent: Bool

    var isHome: Bool {
        role == "home"
    }

    var subtitle: String {
        if isCurrent {
            return "Current page"
        }
        if isHome {
            return "Home"
        }
        return address
    }
}

struct AddressBar: View {
    @Binding var address: String
    @Binding var bookmarkLabel: String
    let status: String
    let visit: () -> Void
    let bookmark: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("fork://author/...", text: $address)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit(visit)

                Button(action: visit) {
                    Label("Visit", systemImage: "arrow.right.circle")
                }
            }

            HStack(spacing: 8) {
                TextField("Local nickname", text: $bookmarkLabel)
                    .textFieldStyle(.roundedBorder)

                Button(action: bookmark) {
                    Label("Bookmark", systemImage: "bookmark")
                }
            }

            HStack {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(12)
    }
}

struct ReaderView: View {
    let page: RenderedPage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(page.title)
                        .font(.system(size: 34, weight: .semibold))
                    Text(statusText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Divider()

                Text(renderedMarkdown)
                    .font(.body)
                    .textSelection(.enabled)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Author")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    AddressCopyRow(address: page.authorAddress.rawValue)

                    Text("Document")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    AddressCopyRow(address: page.documentAddress.rawValue)
                }
                .padding(.top, 16)
            }
            .padding(32)
            .frame(maxWidth: 720, alignment: .leading)
        }
    }

    private var renderedMarkdown: AttributedString {
        (try? AttributedString(markdown: page.markdown)) ?? AttributedString(page.markdown)
    }

    private var statusText: String {
        switch page.source {
        case .live:
            "Showing newest signed version from the author peer."
        case .cache(let date):
            "Showing verified cached version from \(date.formatted(date: .abbreviated, time: .shortened)). Looking for newer signed versions..."
        }
    }
}

struct AddressCopyRow: View {
    let address: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(address)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(2)

            Button {
                copyToPasteboard(address)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .labelStyle(.iconOnly)
            .help("Copy address")
        }
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

struct WriterPreview: View {
    @Binding var title: String
    @Binding var markdown: String
    let status: String
    let saveDraft: () -> Void
    let publish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Write")
                .font(.title2)
                .fontWeight(.semibold)

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            TextEditor(text: $markdown)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 10) {
                Button(action: saveDraft) {
                    Label("Save Draft", systemImage: "tray.and.arrow.down")
                }

                Button(action: publish) {
                    Label("Publish Signed Record", systemImage: "signature")
                }
                .buttonStyle(.borderedProminent)
            }

            Text(status)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }
}

@MainActor
final class ForkAppModel: ObservableObject {
    @Published var draftTitle = ""
    @Published var draftMarkdown = ""
    @Published var page: RenderedPage?
    @Published var statusMessage = "Ready."
    @Published var errorMessage: String?
    @Published var addressText = ""
    @Published var bookmarkLabel = ""
    @Published var bookmarks: [ForkBookmark] = []
    @Published var historyEntries: [ForkHistoryEntry] = []
    @Published var placePages: [ForkPlacePage] = []
    @Published var drafts: [DraftDocument] = []
    @Published var selectedDraftID = "home"
    @Published var canGoBack = false
    @Published var canGoForward = false

    private var identityProvider: StoredIdentityProvider
    private var draftProvider: StoredDraftProvider
    private var bookmarkStore: any BookmarkStore
    private var readerPeer: LocalPeer
    private let authorPeer = LocalPeer(name: "Author")
    private var authorServer: LoopbackAuthorBundleServer?
    private var authorClient: LoopbackAuthorBundleClient?
    private var authorAddress: ForkAddress?
    private var history: [String] = []
    private var historyIndex: Int?

    init() {
        do {
            identityProvider = StoredIdentityProvider(store: KeychainIdentityStore())
            draftProvider = try StoredDraftProvider(
                store: FileDraftStore(rootDirectory: forkDraftDirectory())
            )
            bookmarkStore = try FileBookmarkStore(fileURL: forkBookmarksFile())
            readerPeer = try LocalPeer(
                name: "Reader",
                recordCache: FileRecordCache(rootDirectory: forkCacheDirectory())
            )

            try load()
        } catch {
            identityProvider = StoredIdentityProvider(store: MemoryIdentityStore())
            draftProvider = StoredDraftProvider(store: MemoryDraftStore())
            bookmarkStore = MemoryBookmarkStore()
            readerPeer = LocalPeer(name: "Reader")
            errorMessage = error.localizedDescription
        }
    }

    func saveDraft() {
        do {
            _ = try persistDraft()
            try refreshDrafts()
            statusMessage = "Draft saved."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Draft could not be saved."
        }
    }

    func publish() {
        do {
            let draft = try persistDraft()
            let documents = try publicationDocuments(currentDraft: draft)
            guard let homeDocument = documents.first(where: { $0.draftID == draft.id })?.publication.identity.address else {
                throw ForkError.missingPublicationDocuments
            }
            let now = Date()
            try authorPeer.publishDocuments(
                documents.map { $0.publication },
                homeDocument: homeDocument,
                createdAt: now
            )
            guard let authorAddress else {
                return
            }
            let renderedPage = try readerPeer.renderAuthor(
                authorAddress,
                preferLiveSource: authorClient,
                fetchedAt: now
            )
            show(
                renderedPage,
                displayedAddress: authorAddress.rawValue,
                addHistory: history.isEmpty
            )
            addressText = authorAddress.rawValue
            try refreshDrafts()
            statusMessage = "Published signed record over localhost."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Publish failed."
        }
    }

    func createDraft() {
        do {
            _ = try persistDraft()
            let draft = try draftProvider.createDraft()
            try refreshDrafts()
            try loadDraft(draft.id)
            statusMessage = "Created draft."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Draft could not be created."
        }
    }

    func selectDraft(_ id: String) {
        do {
            _ = try persistDraft()
            try loadDraft(id)
            statusMessage = "Editing draft."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Draft could not be opened."
        }
    }

    func visitAddress() {
        visit(addressText)
    }

    func visitOwnPlace() {
        guard let authorAddress else {
            return
        }
        visit(authorAddress.rawValue)
    }

    func visit(_ rawAddress: String) {
        do {
            let address = try ForkAddress(rawAddress.trimmingCharacters(in: .whitespacesAndNewlines))
            let renderedPage: RenderedPage
            if address.kind == .author {
                let liveSource: (any AuthorBundleSource)? = address == authorAddress ? authorClient : nil
                renderedPage = try readerPeer.renderAuthor(
                    address,
                    preferLiveSource: liveSource,
                    fetchedAt: Date()
                )
            } else {
                renderedPage = try readerPeer.render(address)
            }
            show(renderedPage, displayedAddress: address.rawValue, addHistory: true)
            statusMessage = renderedPage.source == .live ? "Showing live signed record." : "Showing verified cached record."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Address unavailable."
        }
    }

    func bookmarkCurrentPage() {
        guard let page else {
            return
        }

        do {
            let address = try ForkAddress(addressText.trimmingCharacters(in: .whitespacesAndNewlines))
            let bookmark = ForkBookmark(
                address: address.rawValue,
                title: page.title,
                nickname: bookmarkLabel,
                createdAt: Date()
            )
            bookmarks.removeAll { $0.address == bookmark.address }
            bookmarks.insert(bookmark, at: 0)
            try bookmarkStore.saveBookmarks(bookmarks)
            statusMessage = "Bookmark saved."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Bookmark could not be saved."
        }
    }

    func goBack() {
        guard let index = historyIndex, index > 0 else {
            return
        }
        historyIndex = index - 1
        restoreHistorySelection()
    }

    func goForward() {
        guard let index = historyIndex, index + 1 < history.count else {
            return
        }
        historyIndex = index + 1
        restoreHistorySelection()
    }

    private func load() throws {
        let authorIdentity = try identityProvider.loadOrCreateAuthorIdentity()
        let documentIdentity = try identityProvider.loadOrCreateDocumentIdentity(account: selectedDraftID)
        authorPeer.useAuthorIdentity(authorIdentity)
        authorPeer.useDocumentIdentity(documentIdentity)
        authorAddress = authorIdentity.address
        try startAuthorTransport()
        bookmarks = try bookmarkStore.loadBookmarks()
        addressText = authorIdentity.address.rawValue

        let draft = try draftProvider.loadOrCreateHomeDraft()
        try refreshDrafts()
        applyDraft(draft)
        publish()
    }

    private func startAuthorTransport() throws {
        let server = try LoopbackAuthorBundleServer(peer: authorPeer)
        try server.start()
        authorServer = server
        authorClient = try LoopbackAuthorBundleClient(baseURL: server.baseURL)
    }

    private func persistDraft() throws -> DraftDocument {
        let draft = DraftDocument(
            id: selectedDraftID,
            title: draftTitle,
            markdown: draftMarkdown,
            updatedAt: Date()
        )
        try draftProvider.saveDraft(draft)
        return draft
    }

    private func loadDraft(_ id: String) throws {
        guard let draft = try draftProvider.loadDraft(id: id) else {
            return
        }
        applyDraft(draft)
    }

    private func applyDraft(_ draft: DraftDocument) {
        selectedDraftID = draft.id
        draftTitle = draft.title
        draftMarkdown = draft.markdown
    }

    private func refreshDrafts() throws {
        drafts = try draftProvider.loadDrafts()
    }

    private func publicationDocuments(currentDraft: DraftDocument) throws -> [(draftID: String, publication: LocalDocumentPublication)] {
        let storedDrafts = try draftProvider.loadDrafts()
        let publicationDrafts = mergedDrafts(storedDrafts, replacingWith: currentDraft)
        return try publicationDrafts.map { draft in
            let identity = try identityProvider.loadOrCreateDocumentIdentity(account: draft.id)
            return (
                draftID: draft.id,
                publication: LocalDocumentPublication(
                    identity: identity,
                    title: draft.title,
                    markdown: draft.markdown
                )
            )
        }
    }

    private func mergedDrafts(_ drafts: [DraftDocument], replacingWith currentDraft: DraftDocument) -> [DraftDocument] {
        var merged = drafts.filter { $0.id != currentDraft.id }
        merged.append(currentDraft)
        return merged.sorted { lhs, rhs in
            if lhs.id == "home" {
                return true
            }
            if rhs.id == "home" {
                return false
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private func show(_ renderedPage: RenderedPage, displayedAddress: String, addHistory: Bool) {
        page = renderedPage
        addressText = displayedAddress
        bookmarkLabel = bookmarkLabel(for: displayedAddress) ?? renderedPage.title
        updatePlacePages(for: renderedPage)

        if addHistory {
            if let index = historyIndex, index + 1 < history.count {
                history = Array(history.prefix(index + 1))
            }

            if history.last != displayedAddress {
                history.append(displayedAddress)
            }
            historyIndex = history.count - 1
        }

        updateHistoryEntries()
        updateHistoryAvailability()
    }

    private func updatePlacePages(for renderedPage: RenderedPage) {
        guard let manifest = try? readerPeer.exportManifest(renderedPage.authorAddress) else {
            placePages = []
            return
        }

        placePages = manifest.payload.documents.map { document in
            ForkPlacePage(
                id: document.address,
                address: document.address,
                title: document.title,
                role: document.role,
                isCurrent: document.address == renderedPage.documentAddress.rawValue
            )
        }
    }

    private func restoreHistorySelection() {
        guard let index = historyIndex else {
            return
        }

        do {
            let address = try ForkAddress(history[index])
            let renderedPage = try readerPeer.render(address)
            show(renderedPage, displayedAddress: address.rawValue, addHistory: false)
            statusMessage = "Showing verified cached record."
            updateHistoryEntries()
            updateHistoryAvailability()
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "History item unavailable."
        }
    }

    private func updateHistoryAvailability() {
        let index = historyIndex ?? 0
        canGoBack = historyIndex != nil && index > 0
        canGoForward = historyIndex != nil && index + 1 < history.count
    }

    private func bookmarkLabel(for address: String) -> String? {
        bookmarks.first { $0.address == address }?.displayTitle
    }

    private func updateHistoryEntries() {
        historyEntries = history.reversed().enumerated().map { offset, address in
            ForkHistoryEntry(
                id: "\(offset)-\(address)",
                address: address,
                title: bookmarkLabel(for: address) ?? historyTitle(for: address)
            )
        }
    }

    private func historyTitle(for address: String) -> String {
        guard let forkAddress = try? ForkAddress(address) else {
            return address
        }

        switch forkAddress.kind {
        case .author:
            return "Author place"
        case .document:
            return "Document"
        }
    }
}
