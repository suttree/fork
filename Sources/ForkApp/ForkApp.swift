import ForkCore
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
                    Label("History", systemImage: "clock")
                }

                Section("Bookmarks") {
                    ForEach(model.bookmarks) { bookmark in
                        Button {
                            model.visit(bookmark.address)
                        } label: {
                            Label(bookmark.title, systemImage: "bookmark")
                        }
                    }
                }

                Section("Write") {
                    Label("My Place", systemImage: "square.and.pencil")
                }
            }
            .navigationTitle("Fork")
        } detail: {
            VStack(spacing: 0) {
                AddressBar(
                    address: $model.addressText,
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

struct AddressBar: View {
    @Binding var address: String
    let visit: () -> Void
    let bookmark: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("fork://author/...", text: $address)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .onSubmit(visit)

            Button(action: visit) {
                Label("Visit", systemImage: "arrow.right.circle")
            }

            Button(action: bookmark) {
                Label("Bookmark", systemImage: "bookmark")
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
                    Text(page.authorAddress.rawValue)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)

                    Text("Document")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    Text(page.documentAddress.rawValue)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
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
    @Published var bookmarks: [ForkBookmark] = []
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
            statusMessage = "Draft saved."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Draft could not be saved."
        }
    }

    func publish() {
        do {
            let draft = try persistDraft()
            let now = Date()
            try authorPeer.publishHomePage(
                title: draft.title,
                markdown: draft.markdown,
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
            statusMessage = "Published signed record over localhost."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Publish failed."
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
            let bookmark = ForkBookmark(
                address: page.authorAddress.rawValue,
                title: page.title,
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
        let documentIdentity = try identityProvider.loadOrCreateDocumentIdentity(account: "home")
        authorPeer.useAuthorIdentity(authorIdentity)
        authorPeer.useDocumentIdentity(documentIdentity)
        authorAddress = authorIdentity.address
        try startAuthorTransport()
        bookmarks = try bookmarkStore.loadBookmarks()
        addressText = authorIdentity.address.rawValue

        let draft = try draftProvider.loadOrCreateHomeDraft()
        draftTitle = draft.title
        draftMarkdown = draft.markdown
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
            id: "home",
            title: draftTitle,
            markdown: draftMarkdown,
            updatedAt: Date()
        )
        try draftProvider.saveDraft(draft)
        return draft
    }

    private func show(_ renderedPage: RenderedPage, displayedAddress: String, addHistory: Bool) {
        page = renderedPage
        addressText = displayedAddress

        if addHistory {
            if let index = historyIndex, index + 1 < history.count {
                history = Array(history.prefix(index + 1))
            }

            if history.last != displayedAddress {
                history.append(displayedAddress)
            }
            historyIndex = history.count - 1
        }

        updateHistoryAvailability()
    }

    private func restoreHistorySelection() {
        guard let index = historyIndex else {
            return
        }

        do {
            let address = try ForkAddress(history[index])
            page = try readerPeer.render(address)
            addressText = address.rawValue
            statusMessage = "Showing verified cached record."
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
}
