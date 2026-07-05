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

                    if model.samplePlaceAddress != nil {
                        Button {
                            model.visitSamplePlace()
                        } label: {
                            Label("Sample Place", systemImage: "network")
                        }

                        Button {
                            model.toggleSamplePeer()
                        } label: {
                            Label(
                                model.samplePeerOnline ? "Take Sample Offline" : "Bring Sample Online",
                                systemImage: model.samplePeerOnline ? "wifi.slash" : "antenna.radiowaves.left.and.right"
                            )
                        }
                    }
                }

                if !model.placePages.isEmpty {
                    Section("Place Pages") {
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
                            .help(page.address)
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
                                    Text(bookmark.subtitle)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            } icon: {
                                Image(systemName: bookmark.iconName)
                            }
                        }
                    }
                }

                Section("Write") {
                    Button(action: model.createDraft) {
                        Label("Add Page", systemImage: "plus")
                    }

                    ForEach(model.drafts) { draft in
                        HStack(spacing: 8) {
                            Button {
                                model.selectDraft(draft.id)
                            } label: {
                                Label {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(draft.title)
                                            .lineLimit(1)
                                        Text(draftSubtitle(for: draft))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                } icon: {
                                    Image(systemName: draft.id == model.selectedDraftID ? "square.and.pencil" : "doc")
                                }
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            if draft.id != "home" {
                                Button {
                                    model.requestDraftDeletion(draft.id)
                                } label: {
                                    Label("Delete Page", systemImage: "trash")
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                                .help("Delete page")
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
                    ReaderView(page: page, theme: model.readerTheme)
                        .frame(minWidth: 420)

                    Divider()

                    WriterPreview(
                        title: $model.draftTitle,
                        markdown: $model.draftMarkdown,
                        documentAddress: model.draftDocumentAddress,
                        status: model.statusMessage,
                        createPage: model.createDraft,
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

                    Button(action: model.visitCurrentPlaceHome) {
                        Label("Home", systemImage: "house")
                    }
                    .disabled(!model.canVisitPlaceHome)

                    Button(action: model.bookmarkCurrentPage) {
                        Label("Bookmark", systemImage: "bookmark")
                    }

                    Picker("Theme", selection: $model.readerTheme) {
                        ForEach(ForkReaderTheme.allCases) { theme in
                            Text(theme.title).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
            }
        }
        .frame(minWidth: 920, minHeight: 620)
        .confirmationDialog(
            "Delete Page?",
            isPresented: $model.isConfirmingDraftDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete Page", role: .destructive) {
                model.confirmDraftDeletion()
            }
            Button("Cancel", role: .cancel) {
                model.cancelDraftDeletion()
            }
        } message: {
            Text("This removes \(model.pendingDraftDeletionTitle) from local pages. Publish afterward to update your signed place.")
        }
    }

    private func draftSubtitle(for draft: DraftDocument) -> String {
        if draft.id == model.selectedDraftID {
            return draft.id == "home" ? "Editing home" : "Editing page"
        }
        if draft.id == "home" {
            return "Home page"
        }
        return draft.updatedAt.formatted(date: .abbreviated, time: .shortened)
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
            return isHome ? "Current home page" : "Current page"
        }
        if isHome {
            return "Home page"
        }
        return "Place page"
    }
}

extension ForkBookmark {
    var subtitle: String {
        switch addressKind {
        case .author:
            "Author place"
        case .document:
            "Document page"
        case nil:
            address
        }
    }

    var iconName: String {
        switch addressKind {
        case .author:
            "person.crop.square"
        case .document:
            "doc.text"
        case nil:
            "bookmark"
        }
    }

    private var addressKind: ForkAddress.Kind? {
        (try? ForkAddress(address))?.kind
    }
}

private enum ForkSamplePlace {
    static let authorAccount = "sample-author"
    static let fieldNotesAccount = "sample-field-notes"
    static let aboutAccount = "sample-about"
    static let publishedAt = Date(timeIntervalSince1970: 1_783_078_400)

    static func authorIdentity(using provider: StoredIdentityProvider) throws -> ForkIdentity {
        try provider.loadOrCreateAuthorIdentity(account: authorAccount)
    }

    static func publications(using provider: StoredIdentityProvider) throws -> (homeDocument: ForkAddress, documents: [LocalDocumentPublication]) {
        let fieldNotes = try provider.loadOrCreateDocumentIdentity(account: fieldNotesAccount)
        let about = try provider.loadOrCreateDocumentIdentity(account: aboutAccount)
        return (
            homeDocument: fieldNotes.address,
            documents: [
                LocalDocumentPublication(
                    identity: fieldNotes,
                    title: "Field Notes from Elsewhere",
                    markdown: """
                    # Field Notes from Elsewhere

                    This page belongs to a second local Fork author. It is fetched over the same loopback transport, verified, cached, and then rendered like any other place.
                    """
                ),
                LocalDocumentPublication(
                    identity: about,
                    title: "About This Sample",
                    markdown: """
                    # About This Sample

                    Fork addresses are intentionally strange. Browsing should lean on bookmarks, history, trails, and local names instead of nice domains.
                    """
                )
            ]
        )
    }
}

enum ForkReaderTheme: String, CaseIterable, Identifiable {
    case system
    case paper
    case night

    private static let storageKey = "ForkReaderTheme"

    static var saved: ForkReaderTheme {
        guard let rawValue = UserDefaults.standard.string(forKey: storageKey) else {
            return .system
        }
        return ForkReaderTheme(rawValue: rawValue) ?? .system
    }

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .system:
            "Classic"
        case .paper:
            "Starship"
        case .night:
            "NvChad"
        }
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: Self.storageKey)
    }

    var readerBackground: Color {
        switch self {
        case .system:
            Color(red: 0.91, green: 0.94, blue: 0.96)
        case .paper:
            Color(red: 0.07, green: 0.08, blue: 0.13)
        case .night:
            Color(red: 0.05, green: 0.06, blue: 0.08)
        }
    }

    var pageBackground: Color {
        switch self {
        case .system:
            Color(red: 1.00, green: 0.98, blue: 0.94)
        case .paper:
            Color(red: 0.10, green: 0.11, blue: 0.18)
        case .night:
            Color(red: 0.09, green: 0.10, blue: 0.14)
        }
    }

    var primaryText: Color {
        switch self {
        case .system:
            Color(red: 0.12, green: 0.16, blue: 0.20)
        case .paper:
            Color(red: 0.88, green: 0.94, blue: 1.00)
        case .night:
            Color(red: 0.82, green: 0.86, blue: 0.96)
        }
    }

    var secondaryText: Color {
        switch self {
        case .system:
            Color(red: 0.38, green: 0.42, blue: 0.48)
        case .paper:
            Color(red: 0.64, green: 0.72, blue: 0.86)
        case .night:
            Color(red: 0.55, green: 0.62, blue: 0.76)
        }
    }

    var divider: Color {
        switch self {
        case .system:
            Color(red: 0.92, green: 0.48, blue: 0.42)
        case .paper:
            Color(red: 0.21, green: 0.84, blue: 0.88)
        case .night:
            Color(red: 0.74, green: 0.48, blue: 0.96)
        }
    }

    var accent: Color {
        switch self {
        case .system:
            Color(red: 0.10, green: 0.55, blue: 0.78)
        case .paper:
            Color(red: 0.39, green: 0.92, blue: 0.86)
        case .night:
            Color(red: 0.58, green: 0.91, blue: 0.48)
        }
    }

    var accentSecondary: Color {
        switch self {
        case .system:
            Color(red: 0.91, green: 0.24, blue: 0.45)
        case .paper:
            Color(red: 0.96, green: 0.63, blue: 0.23)
        case .night:
            Color(red: 0.96, green: 0.43, blue: 0.72)
        }
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
    let theme: ForkReaderTheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    Capsule()
                        .fill(theme.accent)
                        .frame(width: 54, height: 5)
                    Capsule()
                        .fill(theme.accentSecondary)
                        .frame(width: 22, height: 5)
                    Capsule()
                        .fill(theme.divider)
                        .frame(width: 10, height: 5)
                }
                .padding(.bottom, 2)

                VStack(alignment: .leading, spacing: 6) {
                    Text(page.title)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(theme.primaryText)
                    Text(statusText)
                        .font(.callout)
                        .foregroundStyle(theme.secondaryText)
                    Text(recordText)
                        .font(.caption)
                        .foregroundStyle(theme.accent)
                }

                Divider().overlay(theme.divider)

                Text(renderedMarkdown)
                    .font(.body)
                    .foregroundStyle(theme.primaryText)
                    .textSelection(.enabled)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Author")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                    AddressCopyRow(address: page.authorAddress.rawValue, theme: theme)

                    Text("Document")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                        .padding(.top, 8)
                    AddressCopyRow(address: page.documentAddress.rawValue, theme: theme)
                }
                .padding(.top, 16)
            }
            .padding(32)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
            .background(theme.pageBackground)
        }
        .background(theme.readerBackground)
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

    private var recordText: String {
        if let previous = page.previous {
            return "Document version \(page.version), replacing \(previous.prefix(12))..."
        }
        return "Document version \(page.version), first signed version."
    }
}

struct AddressCopyRow: View {
    let address: String
    let theme: ForkReaderTheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(address)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(theme.secondaryText)
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
    private enum Mode: String, CaseIterable, Identifiable {
        case edit = "Edit"
        case preview = "Preview"

        var id: String {
            rawValue
        }
    }

    @Binding var title: String
    @Binding var markdown: String
    let documentAddress: String
    let status: String
    let createPage: () -> Void
    let saveDraft: () -> Void
    let publish: () -> Void
    @State private var mode: Mode = .edit

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Write")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: createPage) {
                    Label("Add Page", systemImage: "plus")
                }

                Picker("Writer Mode", selection: $mode) {
                    ForEach(Mode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 4) {
                Text("Document Address")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                DraftAddressCopyRow(address: documentAddress)
            }

            Group {
                switch mode {
                case .edit:
                    TextEditor(text: $markdown)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                case .preview:
                    ScrollView {
                        Text(renderedMarkdown)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 10) {
                Button(action: saveDraft) {
                    Label("Save Draft", systemImage: "tray.and.arrow.down")
                }

                Button(action: publish) {
                    Label("Publish Signed Place", systemImage: "signature")
                }
                .buttonStyle(.borderedProminent)
            }

            Text(status)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }

    private var renderedMarkdown: AttributedString {
        (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
    }
}

struct DraftAddressCopyRow: View {
    let address: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(address.isEmpty ? "Unavailable" : address)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .textSelection(.enabled)

            Button {
                copyToPasteboard(address)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .labelStyle(.iconOnly)
            .help("Copy document address")
            .disabled(address.isEmpty)
        }
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

@MainActor
final class ForkAppModel: ObservableObject {
    @Published var draftTitle = ""
    @Published var draftMarkdown = ""
    @Published var draftDocumentAddress = ""
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
    @Published var readerTheme = ForkReaderTheme.saved {
        didSet {
            readerTheme.save()
        }
    }
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var canVisitPlaceHome = false
    @Published var samplePlaceAddress: String?
    @Published var samplePeerOnline = false
    @Published var isConfirmingDraftDeletion = false
    @Published var pendingDraftDeletionTitle = "this page"

    private var identityProvider: StoredIdentityProvider
    private var draftProvider: StoredDraftProvider
    private var bookmarkStore: any BookmarkStore
    private var readerPeer: LocalPeer
    private let authorPeer = LocalPeer(name: "Author")
    private let samplePeer = LocalPeer(name: "Sample Author")
    private var authorServer: LoopbackAuthorBundleServer?
    private var authorClient: LoopbackAuthorBundleClient?
    private var sampleServer: LoopbackAuthorBundleServer?
    private var sampleClient: LoopbackAuthorBundleClient?
    private var authorAddress: ForkAddress?
    private var sampleAddress: ForkAddress?
    private var history: [String] = []
    private var historyIndex: Int?
    private var pendingDraftDeletionID: String?
    private var currentHomePageAddress: String?

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
            statusMessage = "Page saved."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Page could not be saved."
        }
    }

    func publish() {
        do {
            let draft = try persistDraft()
            let documents = try publicationDocuments(currentDraft: draft)
            guard let homeDocument = documents.first(where: { $0.draftID == "home" })?.publication.identity.address else {
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
            let homePage = try readerPeer.renderAuthor(
                authorAddress,
                preferLiveSource: authorClient,
                fetchedAt: now
            )
            let currentDocument = documents.first(where: { $0.draftID == draft.id })?.publication.identity.address
            let displayedAddress: ForkAddress
            let renderedPage: RenderedPage
            if let currentDocument, currentDocument != homeDocument {
                displayedAddress = currentDocument
                renderedPage = try readerPeer.render(currentDocument)
            } else {
                displayedAddress = authorAddress
                renderedPage = homePage
            }
            show(
                renderedPage,
                displayedAddress: displayedAddress.rawValue,
                addHistory: history.isEmpty || displayedAddress.rawValue != addressText
            )
            try refreshDrafts()
            statusMessage = "Published signed place over localhost."
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
            statusMessage = "Added page to your place."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Page could not be added."
        }
    }

    func selectDraft(_ id: String) {
        do {
            _ = try persistDraft()
            try loadDraft(id)
            statusMessage = "Editing page."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Page could not be opened."
        }
    }

    func requestDraftDeletion(_ id: String) {
        guard id != "home" else {
            statusMessage = "The home page cannot be deleted."
            return
        }
        pendingDraftDeletionID = id
        pendingDraftDeletionTitle = drafts.first { $0.id == id }?.title ?? "this page"
        isConfirmingDraftDeletion = true
    }

    func confirmDraftDeletion() {
        guard let id = pendingDraftDeletionID else {
            isConfirmingDraftDeletion = false
            return
        }
        deleteDraft(id)
        cancelDraftDeletion()
    }

    func cancelDraftDeletion() {
        pendingDraftDeletionID = nil
        pendingDraftDeletionTitle = "this page"
        isConfirmingDraftDeletion = false
    }

    private func deleteDraft(_ id: String) {
        do {
            if id != selectedDraftID {
                _ = try persistDraft()
            }
            try draftProvider.deleteDraft(id: id)
            try refreshDrafts()
            if id == selectedDraftID {
                try loadDraft(drafts.first?.id ?? "home")
            }
            statusMessage = "Page deleted. Publish to update your signed place."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Page could not be deleted."
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

    func visitSamplePlace() {
        guard let sampleAddress else {
            return
        }
        visit(sampleAddress.rawValue)
    }

    func visitCurrentPlaceHome() {
        guard let currentHomePageAddress else {
            return
        }
        visit(currentHomePageAddress)
    }

    func toggleSamplePeer() {
        do {
            if samplePeerOnline {
                stopSampleServer()
                statusMessage = "Sample author is offline. Verified cached copies remain readable."
            } else {
                try startSampleServer()
                statusMessage = "Sample author is online over localhost."
            }
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Sample author could not change network state."
        }
    }

    func visit(_ rawAddress: String) {
        do {
            let address = try ForkAddress(rawAddress.trimmingCharacters(in: .whitespacesAndNewlines))
            let renderedPage: RenderedPage
            if address.kind == .author {
                renderedPage = try readerPeer.renderAuthor(
                    address,
                    preferLiveSource: liveSource(for: address),
                    fetchedAt: Date()
                )
            } else {
                renderedPage = try readerPeer.render(address)
            }
            show(renderedPage, displayedAddress: address.rawValue, addHistory: true)
            statusMessage = statusText(for: renderedPage)
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = unavailableStatusText(for: error)
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
        try startSampleTransport()
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

    private func startSampleTransport() throws {
        let sampleIdentity = try ForkSamplePlace.authorIdentity(using: identityProvider)
        samplePeer.useAuthorIdentity(sampleIdentity)
        sampleAddress = sampleIdentity.address
        samplePlaceAddress = sampleIdentity.address.rawValue

        let publication = try ForkSamplePlace.publications(using: identityProvider)
        try samplePeer.publishDocuments(
            publication.documents,
            homeDocument: publication.homeDocument,
            createdAt: ForkSamplePlace.publishedAt
        )

        try startSampleServer()
    }

    private func startSampleServer() throws {
        stopSampleServer()
        let server = try LoopbackAuthorBundleServer(peer: samplePeer)
        do {
            try server.start()
            sampleServer = server
            sampleClient = try LoopbackAuthorBundleClient(baseURL: server.baseURL)
            samplePeerOnline = true
        } catch {
            samplePeerOnline = false
            throw error
        }
    }

    private func stopSampleServer() {
        sampleServer?.stop()
        sampleServer = nil
        sampleClient = nil
        samplePeerOnline = false
    }

    private func liveSource(for address: ForkAddress) -> (any AuthorBundleSource)? {
        if address == authorAddress {
            return authorClient
        }
        if address == sampleAddress {
            return sampleClient
        }
        return nil
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
        refreshDraftDocumentAddress()
    }

    private func refreshDrafts() throws {
        drafts = try draftProvider.loadDrafts()
    }

    private func refreshDraftDocumentAddress() {
        do {
            let identity = try identityProvider.loadOrCreateDocumentIdentity(account: selectedDraftID)
            draftDocumentAddress = identity.address.rawValue
        } catch {
            draftDocumentAddress = ""
            errorMessage = error.localizedDescription
        }
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
            currentHomePageAddress = nil
            canVisitPlaceHome = false
            return
        }

        currentHomePageAddress = manifest.payload.homeDocument
        placePages = manifest.payload.documents.map { document in
            ForkPlacePage(
                id: document.address,
                address: document.address,
                title: document.title,
                role: document.role,
                isCurrent: document.address == renderedPage.documentAddress.rawValue
            )
        }
        canVisitPlaceHome = renderedPage.documentAddress.rawValue != manifest.payload.homeDocument
    }

    private func restoreHistorySelection() {
        guard let index = historyIndex else {
            return
        }

        do {
            let address = try ForkAddress(history[index])
            let renderedPage = try readerPeer.render(address)
            show(renderedPage, displayedAddress: address.rawValue, addHistory: false)
            statusMessage = statusText(for: renderedPage)
            updateHistoryEntries()
            updateHistoryAvailability()
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = unavailableStatusText(for: error)
        }
    }

    private func unavailableStatusText(for error: Error) -> String {
        guard let forkError = error as? ForkError else {
            return "Address unavailable."
        }

        switch forkError {
        case .invalidAddress:
            return "That does not look like a Fork address."
        case .missingManifest, .missingDocument:
            return "No verified cached copy is available yet."
        case .invalidSignature:
            return "Refused a record that did not verify."
        default:
            return forkError.localizedDescription
        }
    }

    private func statusText(for renderedPage: RenderedPage) -> String {
        switch renderedPage.source {
        case .live:
            return "Showing live signed place."
        case .cache(let cachedAt):
            return "Showing verified cached copy from \(cachedAt.formatted(date: .abbreviated, time: .shortened))."
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

        if let renderedPage = try? readerPeer.render(forkAddress) {
            return renderedPage.title
        }

        switch forkAddress.kind {
        case .author:
            return "Author place"
        case .document:
            return "Document"
        }
    }
}
