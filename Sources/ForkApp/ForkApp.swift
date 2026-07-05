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
            List(selection: .constant("home")) {
                Section("Read") {
                    Label("Cached Home", systemImage: "doc.text")
                        .tag("home")
                    Label("Bookmarks", systemImage: "bookmark")
                    Label("History", systemImage: "clock")
                }

                Section("Write") {
                    Label("My Place", systemImage: "square.and.pencil")
                }
            }
            .navigationTitle("Fork")
        } detail: {
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
            .toolbar {
                ToolbarItemGroup {
                    Button {
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    Button {
                    } label: {
                        Label("Forward", systemImage: "chevron.right")
                    }
                    Button {
                    } label: {
                        Label("Bookmark", systemImage: "bookmark")
                    }
                }
            }
        }
        .frame(minWidth: 920, minHeight: 620)
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

    private var identityProvider: StoredIdentityProvider
    private var draftProvider: StoredDraftProvider
    private var readerPeer: LocalPeer
    private let authorPeer = LocalPeer(name: "Author")
    private var authorAddress: ForkAddress?

    init() {
        do {
            identityProvider = StoredIdentityProvider(store: KeychainIdentityStore())
            draftProvider = try StoredDraftProvider(
                store: FileDraftStore(rootDirectory: forkDraftDirectory())
            )
            readerPeer = try LocalPeer(
                name: "Reader",
                recordCache: FileRecordCache(rootDirectory: forkCacheDirectory())
            )

            try load()
        } catch {
            identityProvider = StoredIdentityProvider(store: MemoryIdentityStore())
            draftProvider = StoredDraftProvider(store: MemoryDraftStore())
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
            _ = try readerPeer.renderAuthor(
                authorAddress,
                preferLivePeer: authorPeer,
                fetchedAt: now
            )
            page = try readerPeer.renderAuthor(authorAddress)
            statusMessage = "Published signed record."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Publish failed."
        }
    }

    private func load() throws {
        let authorIdentity = try identityProvider.loadOrCreateAuthorIdentity()
        let documentIdentity = try identityProvider.loadOrCreateDocumentIdentity(account: "home")
        authorPeer.useAuthorIdentity(authorIdentity)
        authorPeer.useDocumentIdentity(documentIdentity)
        authorAddress = authorIdentity.address

        let draft = try draftProvider.loadOrCreateHomeDraft()
        draftTitle = draft.title
        draftMarkdown = draft.markdown
        publish()
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
}
