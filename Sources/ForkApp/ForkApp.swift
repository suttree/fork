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

private enum ForkWorkspaceMode: String, CaseIterable, Identifiable {
    case editor = "Editor"
    case discover = "Discover"

    var id: String {
        rawValue
    }
}

struct ForkShell: View {
    @ObservedObject var model: ForkAppModel
    let page: RenderedPage
    @State private var workspaceMode: ForkWorkspaceMode = .editor

    var body: some View {
        NavigationSplitView {
            List {
                Section("Read") {
                    Button {
                        model.visitOwnPlace()
                    } label: {
                        SidebarRow(
                            title: "My Place",
                            subtitle: "Local author place",
                            iconName: "doc.text"
                        )
                    }
                    .help(model.ownPlaceAddress ?? "Local author place")

                    if model.samplePlaceAddress != nil {
                        Button {
                            model.visitSamplePlace()
                        } label: {
                            SidebarRow(
                                title: "Sample Place",
                                subtitle: model.samplePeerOnline ? "Online over localhost" : "Offline, cache only",
                                iconName: "network"
                            )
                        }
                        .help(model.samplePlaceAddress ?? "Sample author place")

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
                                SidebarRow(
                                    title: page.title,
                                    subtitle: page.subtitle,
                                    iconName: page.isHome ? "house" : "doc.text"
                                )
                            }
                            .help(page.address)
                        }
                    }
                }

                Section("History") {
                    if model.historyEntries.isEmpty {
                        Text("No history yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Button {
                            model.clearHistory()
                        } label: {
                            Label("Clear History", systemImage: "trash")
                        }
                    }

                    ForEach(model.historyEntries) { entry in
                        Button {
                            model.restoreHistoryEntry(entry.index)
                        } label: {
                            SidebarRow(
                                title: entry.title,
                                subtitle: entry.subtitle,
                                iconName: entry.iconName
                            )
                        }
                        .help(entry.address)
                    }
                }

                Section("Bookmarks") {
                    if model.bookmarks.isEmpty {
                        Text("No bookmarks yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.bookmarks) { bookmark in
                            HStack(spacing: 8) {
                                Button {
                                    model.visit(bookmark.address)
                                } label: {
                                    SidebarRow(
                                        title: bookmark.displayTitle,
                                        subtitle: bookmark.subtitle,
                                        iconName: bookmark.iconName
                                    )
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                Button {
                                    model.deleteBookmark(bookmark.address)
                                } label: {
                                    Label("Delete Bookmark", systemImage: "trash")
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                                .help("Delete bookmark")
                            }
                            .help(bookmark.address)
                        }
                    }
                }

                Section("Write") {
                    Button(action: model.createDraft) {
                        Label("Add Page", systemImage: "plus")
                    }

                    Button(action: model.publish) {
                        Label("Publish Place", systemImage: "signature")
                    }

                    ForEach(model.drafts) { draft in
                        HStack(spacing: 8) {
                            Button {
                                model.selectDraft(draft.id)
                            } label: {
                                SidebarRow(
                                    title: draft.title,
                                    subtitle: draftSubtitle(for: draft),
                                    iconName: draftIconName(for: draft)
                                )
                            }
                            .buttonStyle(.plain)
                            .help(model.draftDocumentAddresses[draft.id] ?? draft.title)

                            Spacer()

                            Button {
                                model.copyDraftMarkdownLink(draft.id)
                            } label: {
                                Label("Copy Markdown Link", systemImage: "link")
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .help("Copy Markdown link")

                            if draft.id != "home" {
                                Button {
                                    model.moveDraftUp(draft.id)
                                } label: {
                                    Label("Move Page Up", systemImage: "arrow.up")
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                                .help("Move page up")
                                .disabled(!model.canMoveDraftUp(draft.id))

                                Button {
                                    model.moveDraftDown(draft.id)
                                } label: {
                                    Label("Move Page Down", systemImage: "arrow.down")
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                                .help("Move page down")
                                .disabled(!model.canMoveDraftDown(draft.id))

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
                switch workspaceMode {
                case .editor:
                    EditorWorkspace(
                        title: $model.draftTitle,
                        markdown: $model.draftMarkdown,
                        documentAddress: model.draftDocumentAddress,
                        status: model.statusMessage,
                        createPage: model.createDraft,
                        copyAddress: model.addressCopied,
                        copyMarkdownLink: model.copySelectedDraftMarkdownLink,
                        autosaveDraft: model.autosaveDraft,
                        saveDraft: model.saveDraft,
                        publish: model.publish
                    )
                case .discover:
                    VStack(spacing: 0) {
                        AddressBar(
                            address: $model.addressText,
                            bookmarkLabel: $model.bookmarkLabel,
                            status: model.statusMessage,
                            visit: model.visitAddress,
                            copyAddress: model.addressCopied,
                            bookmark: model.bookmarkCurrentPage
                        )

                        Divider()

                        ReaderView(
                            page: page,
                            theme: model.readerTheme,
                            hasUnpublishedLocalDraft: model.hasUnpublishedLocalDraft,
                            copyAddress: model.addressCopied,
                            copyPlaceMarkdownLink: model.copyCurrentPlaceMarkdownLink,
                            copyMarkdownLink: model.copyCurrentPageMarkdownLink,
                            openURL: model.openMarkdownLink
                        )
                    }
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

                    Button {
                        workspaceMode = .editor
                    } label: {
                        Label("Editor", systemImage: "square.and.pencil")
                    }
                    .labelStyle(.iconOnly)
                    .help("Editor")
                    .foregroundStyle(workspaceMode == .editor ? Color.accentColor : Color.primary)

                    Button {
                        workspaceMode = .discover
                    } label: {
                        Label("Discover", systemImage: "network")
                    }
                    .labelStyle(.iconOnly)
                    .help("Discover")
                    .foregroundStyle(workspaceMode == .discover ? Color.accentColor : Color.primary)

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
            return draft.id == "home" ? "Editing home" : "Editing \(pageLabel(for: draft))"
        }
        if draft.id == "home" {
            return "Home page"
        }
        return pageLabel(for: draft)
    }

    private func pageLabel(for draft: DraftDocument) -> String {
        guard draft.id != "home" else {
            return "Home page"
        }
        let pageDrafts = model.drafts.filter { $0.id != "home" }
        guard let index = pageDrafts.firstIndex(where: { $0.id == draft.id }) else {
            return "Place page"
        }
        return "Page \(index + 1)"
    }

    private func draftIconName(for draft: DraftDocument) -> String {
        if draft.id == "home" {
            return draft.id == model.selectedDraftID ? "house.fill" : "house"
        }
        return draft.id == model.selectedDraftID ? "square.and.pencil" : "doc"
    }
}

struct SidebarRow: View {
    let title: String
    let subtitle: String
    let iconName: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } icon: {
            Image(systemName: iconName)
        }
    }
}

struct ForkHistoryEntry: Identifiable, Equatable {
    let id: String
    let index: Int
    let address: String
    let title: String
    let isCurrent: Bool

    var subtitle: String {
        switch addressKind {
        case .author:
            isCurrent ? "Current author place" : "Author place"
        case .document:
            isCurrent ? "Current document page" : "Document page"
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
            "clock"
        }
    }

    private var addressKind: ForkAddress.Kind? {
        (try? ForkAddress(address))?.kind
    }
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
    private static let identityProvider = StoredIdentityProvider(store: MemoryIdentityStore())

    static func authorIdentity() throws -> ForkIdentity {
        try identityProvider.loadOrCreateAuthorIdentity(account: authorAccount)
    }

    static func publications() throws -> (homeDocument: ForkAddress, documents: [LocalDocumentPublication]) {
        let fieldNotes = try identityProvider.loadOrCreateDocumentIdentity(account: fieldNotesAccount)
        let about = try identityProvider.loadOrCreateDocumentIdentity(account: aboutAccount)
        return (
            homeDocument: fieldNotes.address,
            documents: [
                LocalDocumentPublication(
                    identity: fieldNotes,
                    title: "Field Notes from Elsewhere",
                    markdown: """
                    # Field Notes from Elsewhere

                    This page belongs to a second local Fork author. It is fetched over the same loopback transport, verified, cached, and then rendered like any other place.

                    Follow the trail to [about this sample](\(about.address.rawValue)).
                    """
                ),
                LocalDocumentPublication(
                    identity: about,
                    title: "About This Sample",
                    markdown: """
                    # About This Sample

                    Fork addresses are intentionally strange. Browsing should lean on bookmarks, history, trails, and local names instead of nice domains.

                    Return to [field notes](\(fieldNotes.address.rawValue)).
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
    let copyAddress: () -> Void
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

                Button {
                    copyToPasteboard(address.trimmingCharacters(in: .whitespacesAndNewlines))
                    copyAddress()
                } label: {
                    Label("Copy Address", systemImage: "doc.on.doc")
                }
                .labelStyle(.iconOnly)
                .help("Copy current address")
                .disabled(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

struct ReaderView: View {
    let page: RenderedPage
    let theme: ForkReaderTheme
    let hasUnpublishedLocalDraft: Bool
    let copyAddress: () -> Void
    let copyPlaceMarkdownLink: () -> Void
    let copyMarkdownLink: () -> Void
    let openURL: (URL) -> OpenURLAction.Result

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

                MarkdownBlocksView(markdown: page.markdown, textColor: theme.primaryText)
                .textSelection(.enabled)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Author")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        AddressCopyRow(address: page.authorAddress.rawValue, theme: theme, copied: copyAddress)

                        Button(action: copyPlaceMarkdownLink) {
                            Label("Copy Place Markdown Link", systemImage: "link.badge.plus")
                        }
                        .labelStyle(.iconOnly)
                        .help("Copy place Markdown link")
                    }

                    Text("Document")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                        .padding(.top, 8)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        AddressCopyRow(address: page.documentAddress.rawValue, theme: theme, copied: copyAddress)

                        Button(action: copyMarkdownLink) {
                            Label("Copy Markdown Link", systemImage: "link")
                        }
                        .labelStyle(.iconOnly)
                        .help("Copy Markdown link")
                    }
                }
                .padding(.top, 16)
            }
            .padding(32)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
            .background(theme.pageBackground)
        }
        .background(theme.readerBackground)
        .environment(\.openURL, OpenURLAction(handler: openURL))
    }

    private var statusText: String {
        if hasUnpublishedLocalDraft {
            switch page.source {
            case .live:
                return "Showing last signed version. Unpublished local edits are open in the writer."
            case .cache(let date):
                return "Showing verified cached version from \(date.formatted(date: .abbreviated, time: .shortened)). Unpublished local edits are open in the writer."
            }
        }

        switch page.source {
        case .live:
            return "Showing newest signed version from the author peer."
        case .cache(let date):
            return "Showing verified cached version from \(date.formatted(date: .abbreviated, time: .shortened)). Looking for newer signed versions..."
        }
    }

    private var recordText: String {
        if let previous = page.previous {
            return "Document version \(page.version), replacing \(previous.prefix(12))..."
        }
        return "Document version \(page.version), first signed version."
    }
}

private struct MarkdownBlocksView: View {
    let markdown: String
    let textColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(MarkdownBlock.parse(markdown)) { block in
                switch block.kind {
                case .heading(let level, let text):
                    Text(inlineMarkdown(text))
                        .font(headingFont(for: level))
                        .fontWeight(.semibold)
                        .foregroundStyle(textColor)
                case .paragraph(let text):
                    Text(inlineMarkdown(text))
                        .font(.body)
                        .foregroundStyle(textColor)
                }
            }
        }
    }

    private func inlineMarkdown(_ markdown: String) -> AttributedString {
        (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
    }

    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1:
            return .system(size: 30, weight: .semibold)
        case 2:
            return .title2
        case 3:
            return .title3
        default:
            return .headline
        }
    }
}

private struct MarkdownBlock: Identifiable, Equatable {
    enum Kind: Equatable {
        case heading(level: Int, text: String)
        case paragraph(String)
    }

    let id: Int
    let kind: Kind

    static func parse(_ markdown: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraphLines: [String] = []

        func flushParagraph() {
            let paragraph = paragraphLines
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if !paragraph.isEmpty {
                blocks.append(MarkdownBlock(id: blocks.count, kind: .paragraph(paragraph)))
            }
            paragraphLines = []
        }

        for line in markdown.components(separatedBy: .newlines) {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                flushParagraph()
                continue
            }

            if let heading = heading(in: line) {
                flushParagraph()
                blocks.append(MarkdownBlock(id: blocks.count, kind: .heading(level: heading.level, text: heading.text)))
            } else {
                paragraphLines.append(line)
            }
        }

        flushParagraph()
        return blocks
    }

    private static func heading(in line: String) -> (level: Int, text: String)? {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        let hashes = trimmedLine.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(hashes),
              trimmedLine.dropFirst(hashes).first == " " else {
            return nil
        }

        let text = trimmedLine
            .dropFirst(hashes)
            .trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : (hashes, text)
    }
}

struct AddressCopyRow: View {
    let address: String
    let theme: ForkReaderTheme
    let copied: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(address)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(theme.secondaryText)
                .textSelection(.enabled)
                .lineLimit(2)

            Button {
                copyToPasteboard(address)
                copied()
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

struct EditorWorkspace: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case view = "View"
        case edit = "Edit"

        var id: String {
            rawValue
        }
    }

    @Binding var title: String
    @Binding var markdown: String
    let documentAddress: String
    let status: String
    let createPage: () -> Void
    let copyAddress: () -> Void
    let copyMarkdownLink: () -> Void
    let autosaveDraft: () -> Void
    let saveDraft: () -> Void
    let publish: () -> Void
    @State private var mode: Mode = .view
    @State private var autosaveTask: Task<Void, Never>?
    @State private var hasPendingAutosave = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedTitle)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text(mode == .view ? "Viewing your local draft" : "Editing your local draft")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: createPage) {
                    Label("Add Page", systemImage: "plus")
                }

                Button(action: saveDraft) {
                    Label("Save Draft", systemImage: "tray.and.arrow.down")
                }

                Button(action: publish) {
                    Label("Publish Signed Place", systemImage: "signature")
                }
                .buttonStyle(.borderedProminent)

                Picker("Editor Mode", selection: $mode) {
                    ForEach(Mode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                switch mode {
                case .view:
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            Text(selectedTitle)
                                .font(.system(size: 34, weight: .semibold))
                                .lineLimit(2)

                            MarkdownBlocksView(markdown: markdown, textColor: Color(nsColor: .textColor))
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 30)
                        .frame(maxWidth: 760, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                case .edit:
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Title", text: $title)
                            .font(.title2)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 2)
                            .onChange(of: title) {
                                scheduleAutosave()
                            }

                        Divider()

                        TextEditor(text: $markdown)
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .background(Color(nsColor: .textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onChange(of: markdown) {
                                scheduleAutosave()
                            }
                    }
                    .frame(maxWidth: 860, alignment: .leading)
                }

                Divider()

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("Document")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    DraftAddressCopyRow(address: documentAddress, copied: copyAddress)

                    Button(action: copyMarkdownLink) {
                        Label("Copy Markdown Link", systemImage: "link")
                    }
                    .labelStyle(.iconOnly)
                    .help("Copy Markdown link")
                    .disabled(documentAddress.isEmpty)

                    Spacer()

                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .onDisappear {
            autosaveTask?.cancel()
            flushAutosaveIfNeeded()
        }
        .onChange(of: mode) { _, newMode in
            if newMode == .view {
                flushAutosaveIfNeeded()
            }
        }
    }

    private var selectedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Page" : title
    }

    private func scheduleAutosave() {
        hasPendingAutosave = true
        autosaveTask?.cancel()
        autosaveTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else {
                return
            }
            await MainActor.run {
                flushAutosaveIfNeeded()
            }
        }
    }

    private func flushAutosaveIfNeeded() {
        guard hasPendingAutosave else {
            return
        }
        hasPendingAutosave = false
        autosaveDraft()
    }
}

struct DraftAddressCopyRow: View {
    let address: String
    let copied: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(address.isEmpty ? "Unavailable" : address)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .textSelection(.enabled)

            Button {
                copyToPasteboard(address)
                copied()
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
    private static let lastAddressKey = "ForkLastAddress"
    private static let historyKey = "ForkHistory"
    private static let historyLimit = 50

    @Published var draftTitle = ""
    @Published var draftMarkdown = ""
    @Published var draftDocumentAddress = ""
    @Published var page: RenderedPage?
    @Published var statusMessage = "Ready."
    @Published var errorMessage: String?
    @Published var addressText = ""
    @Published var bookmarkLabel = ""
    @Published var hasUnpublishedLocalDraft = false
    @Published var bookmarks: [ForkBookmark] = []
    @Published var historyEntries: [ForkHistoryEntry] = []
    @Published var placePages: [ForkPlacePage] = []
    @Published var drafts: [DraftDocument] = []
    @Published var draftDocumentAddresses: [String: String] = [:]
    @Published var selectedDraftID = "home"
    @Published var readerTheme = ForkReaderTheme.saved {
        didSet {
            readerTheme.save()
        }
    }
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var canVisitPlaceHome = false
    @Published var ownPlaceAddress: String?
    @Published var samplePlaceAddress: String?
    @Published var samplePeerOnline = false
    @Published var isConfirmingDraftDeletion = false
    @Published var pendingDraftDeletionTitle = "this page"

    private var identityProvider: StoredIdentityProvider
    private var draftProvider: StoredDraftProvider
    private var bookmarkStore: any BookmarkStore
    private var readerPeer: LocalPeer
    private var authorPeer: LocalPeer
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
    private var currentPlaceHomeAddress: String?
    private var currentDisplayedAddress: String?
    private var cachedAuthorIdentities: [String: ForkIdentity] = [:]
    private var cachedDocumentIdentities: [String: ForkIdentity] = [:]

    init() {
        do {
            identityProvider = StoredIdentityProvider(store: KeychainIdentityStore())
            draftProvider = try StoredDraftProvider(
                store: FileDraftStore(rootDirectory: forkDraftDirectory())
            )
            bookmarkStore = try FileBookmarkStore(fileURL: forkBookmarksFile())
            let recordCache = try FileRecordCache(rootDirectory: forkCacheDirectory())
            authorPeer = try LocalPeer(name: "Author", recordCache: recordCache)
            readerPeer = try LocalPeer(
                name: "Reader",
                recordCache: recordCache
            )

            try load()
        } catch {
            identityProvider = StoredIdentityProvider(store: MemoryIdentityStore())
            draftProvider = StoredDraftProvider(store: MemoryDraftStore())
            bookmarkStore = MemoryBookmarkStore()
            authorPeer = LocalPeer(name: "Author")
            readerPeer = LocalPeer(name: "Reader")
            errorMessage = error.localizedDescription
        }
    }

    func saveDraft() {
        do {
            _ = try persistDraft()
            try refreshDrafts()
            refreshUnpublishedDraftState()
            statusMessage = hasUnpublishedLocalDraft
                ? "Page saved locally. Publish signed place to update the reader."
                : "Page saved."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Page could not be saved."
        }
    }

    func autosaveDraft() {
        do {
            _ = try persistDraft()
            try refreshDrafts()
            refreshUnpublishedDraftState()
            if hasUnpublishedLocalDraft {
                statusMessage = "Local edits saved. Publish signed place to update the reader."
            }
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Page could not be autosaved."
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
            statusMessage = "Editing \(selectedDraftStatusLabel())."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Page could not be opened."
        }
    }

    func moveDraftUp(_ id: String) {
        moveDraft(id, direction: .up)
    }

    func moveDraftDown(_ id: String) {
        moveDraft(id, direction: .down)
    }

    func canMoveDraftUp(_ id: String) -> Bool {
        canMoveDraft(id, direction: .up)
    }

    func canMoveDraftDown(_ id: String) -> Bool {
        canMoveDraft(id, direction: .down)
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

    private func moveDraft(_ id: String, direction: DraftMoveDirection) {
        do {
            _ = try persistDraft()
            try draftProvider.moveDraft(id: id, direction: direction)
            try refreshDrafts()
            statusMessage = "Page order updated. Publish to update your signed place."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Page order could not be updated."
        }
    }

    private func canMoveDraft(_ id: String, direction: DraftMoveDirection) -> Bool {
        guard id != "home" else {
            return false
        }
        let pageDrafts = drafts.filter { $0.id != "home" }
        guard let index = pageDrafts.firstIndex(where: { $0.id == id }) else {
            return false
        }

        switch direction {
        case .up:
            return index > 0
        case .down:
            return index + 1 < pageDrafts.count
        }
    }

    func visitAddress() {
        visit(addressText)
    }

    func openMarkdownLink(_ url: URL) -> OpenURLAction.Result {
        guard url.scheme?.lowercased() == "fork" else {
            statusMessage = "Fork opens Fork addresses only."
            return .discarded
        }

        visit(url.absoluteString)
        return .handled
    }

    func addressCopied() {
        statusMessage = "Address copied."
    }

    func copyDraftMarkdownLink(_ id: String) {
        guard let draft = draftForMarkdownLink(id) else {
            statusMessage = "Markdown link could not be copied."
            return
        }

        do {
            let identity = try loadDocumentIdentity(account: draft.id)
            let link = "[\(markdownLinkTitle(draft.title))](\(identity.address.rawValue))"
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(link, forType: .string)
            statusMessage = "Markdown link copied for \(draft.title)."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Markdown link could not be copied."
        }
    }

    func copySelectedDraftMarkdownLink() {
        copyDraftMarkdownLink(selectedDraftID)
    }

    func copyCurrentPageMarkdownLink() {
        guard let page else {
            statusMessage = "Markdown link could not be copied."
            return
        }

        let link = "[\(markdownLinkTitle(page.title))](\(page.documentAddress.rawValue))"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(link, forType: .string)
        statusMessage = "Markdown link copied for \(page.title)."
    }

    func copyCurrentPlaceMarkdownLink() {
        guard let page else {
            statusMessage = "Place link could not be copied."
            return
        }

        let link = "[\(markdownLinkTitle(page.title))](\(page.authorAddress.rawValue))"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(link, forType: .string)
        statusMessage = "Place link copied for \(page.title)."
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
        guard let currentPlaceHomeAddress else {
            return
        }
        visit(currentPlaceHomeAddress)
    }

    func toggleSamplePeer() {
        do {
            if samplePeerOnline {
                let shouldRefreshFromCache = page?.authorAddress == sampleAddress
                stopSampleServer()
                if try refreshCurrentPageIfNeeded(shouldRefreshFromCache) == false {
                    statusMessage = "Sample author is offline. Verified cached copies remain readable."
                }
            } else {
                let shouldRefreshFromLive = page?.authorAddress == sampleAddress
                try startSampleServer()
                if try refreshCurrentPageIfNeeded(shouldRefreshFromLive) == false {
                    statusMessage = "Sample author is online over localhost."
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Sample author could not change network state."
        }
    }

    func visit(_ rawAddress: String) {
        do {
            let address = try ForkAddress(rawAddress.trimmingCharacters(in: .whitespacesAndNewlines))
            let renderedPage = try renderAddress(address.rawValue)
            show(renderedPage, displayedAddress: address.rawValue, addHistory: true)
            statusMessage = statusText(for: renderedPage)
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = unavailableStatusText(for: error)
            updateHistoryEntries()
            updateHistoryAvailability()
        }
    }

    func bookmarkCurrentPage() {
        guard let page else {
            return
        }

        do {
            let address = try ForkAddress(currentDisplayedAddress ?? addressText.trimmingCharacters(in: .whitespacesAndNewlines))
            let bookmark = ForkBookmark(
                address: address.rawValue,
                title: page.title,
                nickname: bookmarkLabel,
                createdAt: Date()
            )
            let didUpdateBookmark = bookmarks.contains { $0.address == bookmark.address }
            bookmarks.removeAll { $0.address == bookmark.address }
            bookmarks.insert(bookmark, at: 0)
            try bookmarkStore.saveBookmarks(bookmarks)
            bookmarkLabel = bookmark.displayTitle
            updateHistoryEntries()
            statusMessage = didUpdateBookmark ? "Bookmark updated." : "Bookmark saved."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Bookmark could not be saved."
        }
    }

    func deleteBookmark(_ address: String) {
        do {
            let didDeleteBookmark = bookmarks.contains { $0.address == address }
            bookmarks.removeAll { $0.address == address }
            try bookmarkStore.saveBookmarks(bookmarks)
            if let page {
                bookmarkLabel = bookmarkLabel(for: currentDisplayedAddress ?? addressText) ?? page.title
            }
            updateHistoryEntries()
            statusMessage = didDeleteBookmark ? "Bookmark deleted." : "Bookmark was already gone."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Bookmark could not be deleted."
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

    func restoreHistoryEntry(_ index: Int) {
        guard history.indices.contains(index) else {
            return
        }
        historyIndex = index
        restoreHistorySelection()
    }

    func clearHistory() {
        let didClearHistory = !history.isEmpty
        history = []
        historyIndex = nil
        saveHistory()
        updateHistoryEntries()
        updateHistoryAvailability()
        statusMessage = didClearHistory ? "History cleared." : "History was already empty."
    }

    private func load() throws {
        let authorIdentity = try loadAuthorIdentity()
        let documentIdentity = try loadDocumentIdentity(account: selectedDraftID)
        authorPeer.useAuthorIdentity(authorIdentity)
        authorPeer.useDocumentIdentity(documentIdentity)
        authorAddress = authorIdentity.address
        ownPlaceAddress = authorIdentity.address.rawValue
        try startAuthorTransport()
        try startSampleTransport()
        bookmarks = try bookmarkStore.loadBookmarks()
        addressText = authorIdentity.address.rawValue
        let launchAddress = UserDefaults.standard.string(forKey: Self.lastAddressKey)
        loadHistory()

        let draft = try draftProvider.loadOrCreateHomeDraft()
        try refreshDrafts()
        applyDraft(draft)
        publish()
        restoreLastAddressIfNeeded(launchAddress)
    }

    private func startAuthorTransport() throws {
        let server = try LoopbackAuthorBundleServer(peer: authorPeer)
        try server.start()
        authorServer = server
        authorClient = try LoopbackAuthorBundleClient(baseURL: server.baseURL)
    }

    private func startSampleTransport() throws {
        let sampleIdentity = try ForkSamplePlace.authorIdentity()
        samplePeer.useAuthorIdentity(sampleIdentity)
        sampleAddress = sampleIdentity.address
        samplePlaceAddress = sampleIdentity.address.rawValue

        let publication = try ForkSamplePlace.publications()
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
            updatedAt: Date(),
            pageOrder: currentDraftPageOrder()
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
        refreshUnpublishedDraftState()
    }

    private func refreshDrafts() throws {
        drafts = try draftProvider.loadDrafts()
        refreshDraftDocumentAddresses()
    }

    private func refreshDraftDocumentAddress() {
        do {
            let identity = try loadDocumentIdentity(account: selectedDraftID)
            draftDocumentAddress = identity.address.rawValue
            draftDocumentAddresses[selectedDraftID] = identity.address.rawValue
        } catch {
            draftDocumentAddress = ""
            errorMessage = error.localizedDescription
        }
    }

    private func refreshDraftDocumentAddresses() {
        var addresses: [String: String] = [:]
        for draft in drafts {
            do {
                let identity = try loadDocumentIdentity(account: draft.id)
                addresses[draft.id] = identity.address.rawValue
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        draftDocumentAddresses = addresses
    }

    private func publicationDocuments(currentDraft: DraftDocument) throws -> [(draftID: String, publication: LocalDocumentPublication)] {
        let storedDrafts = try draftProvider.loadDrafts()
        let publicationDrafts = mergedDrafts(storedDrafts, replacingWith: currentDraft)
        return try publicationDrafts.map { draft in
            let identity = try loadDocumentIdentity(account: draft.id)
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

    private func draftForMarkdownLink(_ id: String) -> DraftDocument? {
        if id == selectedDraftID {
            return DraftDocument(
                id: selectedDraftID,
                title: draftTitle,
                markdown: draftMarkdown,
                updatedAt: Date(),
                pageOrder: currentDraftPageOrder()
            )
        }
        return drafts.first { $0.id == id }
    }

    private func markdownLinkTitle(_ title: String) -> String {
        title.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
    }

    private func mergedDrafts(_ drafts: [DraftDocument], replacingWith currentDraft: DraftDocument) -> [DraftDocument] {
        var merged = drafts.filter { $0.id != currentDraft.id }
        merged.append(currentDraft)
        return merged.sorted(by: StoredDraftProvider.sortDrafts)
    }

    private func currentDraftPageOrder() -> Int {
        if let draft = drafts.first(where: { $0.id == selectedDraftID }) {
            return draft.pageOrder
        }
        guard selectedDraftID != "home" else {
            return 0
        }
        return (drafts.filter { $0.id != "home" }.map(\.pageOrder).max() ?? 0) + 1
    }

    private func selectedDraftStatusLabel() -> String {
        if selectedDraftID == "home" {
            return "home"
        }
        return draftTitle
    }

    private func show(_ renderedPage: RenderedPage, displayedAddress: String, addHistory: Bool) {
        page = renderedPage
        addressText = displayedAddress
        currentDisplayedAddress = displayedAddress
        bookmarkLabel = bookmarkLabel(for: displayedAddress) ?? renderedPage.title
        UserDefaults.standard.set(displayedAddress, forKey: Self.lastAddressKey)
        updatePlacePages(for: renderedPage)
        syncWriterSelection(for: renderedPage)
        refreshUnpublishedDraftState()

        if addHistory {
            if let index = historyIndex, index + 1 < history.count {
                history = Array(history.prefix(index + 1))
            }

            if history.last != displayedAddress {
                history.append(displayedAddress)
            }
            if history.count > Self.historyLimit {
                history = Array(history.suffix(Self.historyLimit))
            }
            historyIndex = history.count - 1
            saveHistory()
        }

        updateHistoryEntries()
        updateHistoryAvailability()
    }

    private func restoreLastAddressIfNeeded(_ storedAddress: String?) {
        guard let storedAddress,
              !storedAddress.isEmpty,
              storedAddress != addressText else {
            return
        }

        visit(storedAddress)
    }

    private func loadHistory() {
        let storedHistory = UserDefaults.standard.stringArray(forKey: Self.historyKey) ?? []
        history = storedHistory.compactMap { rawAddress in
            (try? ForkAddress(rawAddress))?.rawValue
        }
        if history.count > Self.historyLimit {
            history = Array(history.suffix(Self.historyLimit))
        }
        if history != storedHistory {
            saveHistory()
        }
        historyIndex = history.isEmpty ? nil : history.count - 1
        updateHistoryEntries()
        updateHistoryAvailability()
    }

    private func saveHistory() {
        UserDefaults.standard.set(history, forKey: Self.historyKey)
    }

    private func updatePlacePages(for renderedPage: RenderedPage) {
        guard let manifest = try? readerPeer.exportManifest(renderedPage.authorAddress) else {
            placePages = []
            currentPlaceHomeAddress = nil
            canVisitPlaceHome = false
            return
        }

        currentPlaceHomeAddress = renderedPage.authorAddress.rawValue
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

    private func syncWriterSelection(for renderedPage: RenderedPage) {
        guard renderedPage.authorAddress == authorAddress else {
            return
        }

        do {
            guard let draft = try localDraft(for: renderedPage.documentAddress),
                  draft.id != selectedDraftID else {
                return
            }

            _ = try persistDraft()
            applyDraft(draft)
            try refreshDrafts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshUnpublishedDraftState() {
        hasUnpublishedLocalDraft = selectedDraftHasUnpublishedChanges()
    }

    private func selectedDraftHasUnpublishedChanges() -> Bool {
        guard let page,
              page.authorAddress == authorAddress,
              let selectedDraftAddress = try? loadDocumentIdentity(account: selectedDraftID).address,
              selectedDraftAddress == page.documentAddress else {
            return false
        }

        let draft = DraftDocument(
            id: selectedDraftID,
            title: draftTitle,
            markdown: draftMarkdown,
            updatedAt: Date(),
            pageOrder: currentDraftPageOrder()
        )
        return draft.title != page.title || draft.markdown != page.markdown
    }

    private func loadAuthorIdentity(account: String = "author") throws -> ForkIdentity {
        if let identity = cachedAuthorIdentities[account] {
            return identity
        }
        let identity = try identityProvider.loadOrCreateAuthorIdentity(account: account)
        cachedAuthorIdentities[account] = identity
        return identity
    }

    private func loadDocumentIdentity(account: String) throws -> ForkIdentity {
        if let identity = cachedDocumentIdentities[account] {
            return identity
        }
        let identity = try identityProvider.loadOrCreateDocumentIdentity(account: account)
        cachedDocumentIdentities[account] = identity
        return identity
    }

    private func localDraft(for documentAddress: ForkAddress) throws -> DraftDocument? {
        let localDrafts = try draftProvider.loadDrafts()
        for draft in localDrafts {
            let identity = try loadDocumentIdentity(account: draft.id)
            if identity.address == documentAddress {
                return draft
            }
        }
        return nil
    }

    @discardableResult
    private func refreshCurrentPageIfNeeded(_ shouldRefresh: Bool) throws -> Bool {
        guard shouldRefresh else {
            return false
        }

        let address = try ForkAddress(addressText.trimmingCharacters(in: .whitespacesAndNewlines))
        let renderedPage = try renderAddress(address.rawValue)
        show(renderedPage, displayedAddress: address.rawValue, addHistory: false)
        statusMessage = statusText(for: renderedPage)
        return true
    }

    private func renderAddress(_ rawAddress: String) throws -> RenderedPage {
        let address = try ForkAddress(rawAddress.trimmingCharacters(in: .whitespacesAndNewlines))
        if address.kind == .author {
            return try readerPeer.renderAuthor(
                address,
                preferLiveSource: liveSource(for: address),
                fetchedAt: Date()
            )
        }
        return try readerPeer.render(address)
    }

    private func restoreHistorySelection() {
        guard let index = historyIndex else {
            return
        }

        do {
            let renderedPage = try renderAddress(history[index])
            show(renderedPage, displayedAddress: history[index], addHistory: false)
            statusMessage = statusText(for: renderedPage)
            updateHistoryEntries()
            updateHistoryAvailability()
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = unavailableStatusText(for: error)
            updateHistoryEntries()
            updateHistoryAvailability()
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
            let index = history.count - 1 - offset
            return ForkHistoryEntry(
                id: "\(offset)-\(address)",
                index: index,
                address: address,
                title: bookmarkLabel(for: address) ?? historyTitle(for: address),
                isCurrent: index == historyIndex
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
