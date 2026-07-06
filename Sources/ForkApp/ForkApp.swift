import ForkCore
import AppKit
import Foundation
import SwiftUI

@main
struct ForkApp: App {
    var body: some Scene {
        WindowGroup("fork") {
            ContentView(model: ForkAppModel())
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

struct ContentView: View {
    @StateObject var model: ForkAppModel

    var body: some View {
        ForkShell(model: model)
    }
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

private enum ForkTypography {
    static let h1: CGFloat = 38
    static let h2: CGFloat = 32
    static let h3: CGFloat = 26
    static let body: CGFloat = 21
    static let bodyLineSpacing: CGFloat = 6
    static let ui: CGFloat = 14
    static let uiSmall: CGFloat = 11
    static let headerControl: CGFloat = 12
}

enum EditorMode: String, CaseIterable, Identifiable {
    case view = "View"
    case edit = "Edit"

    var id: String {
        rawValue
    }
}

struct ForkShell: View {
    @ObservedObject var model: ForkAppModel

    var body: some View {
        NavigationSplitView {
            List {
                Section("Pages") {
                    ForEach(model.drafts) { draft in
                        HStack(spacing: 8) {
                            Button {
                                model.selectDraft(draft.id)
                            } label: {
                                SidebarRow(
                                    title: draft.title,
                                    subtitle: draftSubtitle(for: draft),
                                    iconName: draftIconName(for: draft),
                                    theme: model.theme
                                )
                            }
                            .buttonStyle(.plain)

                            Spacer()

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
            .navigationTitle("fork")
            .scrollContentBackground(.hidden)
            .background(model.theme.sidebarBackground)
        } detail: {
            EditorWorkspace(
                title: $model.draftTitle,
                markdown: $model.draftMarkdown,
                mode: $model.editorMode,
                status: model.statusMessage,
                theme: model.theme,
                autosaveDraft: model.autosaveDraft,
                openURL: model.openEditorMarkdownLink
            )
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        model.toggleEditorMode()
                    } label: {
                        Label(model.editorMode == .view ? "Edit" : "View", systemImage: "square.and.pencil")
                    }
                    .help("Toggle View/Edit")
                    .keyboardShortcut("e", modifiers: .command)

                    Picker("Theme", selection: $model.theme) {
                        ForEach(ForkEditorTheme.allCases) { theme in
                            Text(theme.title).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 290)
                }
            }
        }
        .tint(model.theme.accent)
        .preferredColorScheme(model.theme.colorScheme)
        .font(.system(size: ForkTypography.ui))
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
            Text("This removes \(model.pendingDraftDeletionTitle) from your local pages.")
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
            return "Page"
        }
        return "Page \(index + 1)"
    }

    private func draftIconName(for draft: DraftDocument) -> String {
        if draft.id == "home" {
            return draft.id == model.selectedDraftID ? "house.fill" : "house"
        }
        return draft.id == model.selectedDraftID ? "doc.text.fill" : "doc.text"
    }
}

struct SidebarRow: View {
    let title: String
    let subtitle: String
    let iconName: String
    let theme: ForkEditorTheme

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.uiFont(size: ForkTypography.ui, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                Text(subtitle)
                    .font(theme.uiFont(size: ForkTypography.uiSmall))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
            }
        } icon: {
            Image(systemName: iconName)
                .foregroundStyle(theme.accent)
        }
    }
}

enum ForkEditorTheme: String, CaseIterable, Identifiable {
    case system
    case starship
    case nvChad
    case oudh

    private static let storageKey = "ForkEditorTheme"

    static var saved: ForkEditorTheme {
        guard let rawValue = UserDefaults.standard.string(forKey: storageKey) else {
            return .oudh
        }
        return ForkEditorTheme(rawValue: rawValue) ?? .oudh
    }

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .system:
            "Classic"
        case .starship:
            "Starship"
        case .nvChad:
            "NvChad"
        case .oudh:
            "Oudh"
        }
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: Self.storageKey)
    }

    var appBackground: Color {
        switch self {
        case .system:
            Color(red: 0.94, green: 0.96, blue: 0.97)
        case .starship:
            Color(red: 0.07, green: 0.08, blue: 0.13)
        case .nvChad:
            Color(red: 0.05, green: 0.06, blue: 0.08)
        case .oudh:
            Color(red: 0.886, green: 0.933, blue: 0.886)
        }
    }

    var sidebarBackground: Color {
        switch self {
        case .system:
            Color(red: 0.95, green: 0.95, blue: 0.93)
        case .starship:
            Color(red: 0.06, green: 0.07, blue: 0.12)
        case .nvChad:
            Color(red: 0.04, green: 0.05, blue: 0.07)
        case .oudh:
            Color(red: 0.84, green: 0.90, blue: 0.84)
        }
    }

    var chromeBackground: Color {
        switch self {
        case .system:
            Color(red: 0.98, green: 0.97, blue: 0.94)
        case .starship:
            Color(red: 0.08, green: 0.09, blue: 0.15)
        case .nvChad:
            Color(red: 0.07, green: 0.08, blue: 0.11)
        case .oudh:
            Color(red: 0.886, green: 0.933, blue: 0.886)
        }
    }

    var editorSurface: Color {
        switch self {
        case .system:
            Color(red: 1.00, green: 0.99, blue: 0.97)
        case .starship:
            Color(red: 0.10, green: 0.11, blue: 0.18)
        case .nvChad:
            Color(red: 0.09, green: 0.10, blue: 0.14)
        case .oudh:
            Color(red: 0.95, green: 0.98, blue: 0.95)
        }
    }

    var primaryText: Color {
        switch self {
        case .system:
            Color(red: 0.12, green: 0.16, blue: 0.20)
        case .starship:
            Color(red: 0.88, green: 0.94, blue: 1.00)
        case .nvChad:
            Color(red: 0.82, green: 0.86, blue: 0.96)
        case .oudh:
            Color(red: 0.047, green: 0.212, blue: 0.376)
        }
    }

    var secondaryText: Color {
        switch self {
        case .system:
            Color(red: 0.38, green: 0.42, blue: 0.48)
        case .starship:
            Color(red: 0.64, green: 0.72, blue: 0.86)
        case .nvChad:
            Color(red: 0.55, green: 0.62, blue: 0.76)
        case .oudh:
            Color(red: 0.22, green: 0.37, blue: 0.50)
        }
    }

    var selectedControlText: Color {
        switch self {
        case .system, .oudh:
            Color.white
        case .starship:
            Color(red: 0.03, green: 0.05, blue: 0.08)
        case .nvChad:
            Color(red: 0.04, green: 0.05, blue: 0.07)
        }
    }

    var divider: Color {
        switch self {
        case .system:
            Color(red: 0.92, green: 0.48, blue: 0.42)
        case .starship:
            Color(red: 0.21, green: 0.84, blue: 0.88)
        case .nvChad:
            Color(red: 0.74, green: 0.48, blue: 0.96)
        case .oudh:
            Color(red: 1.00, green: 0.85, blue: 0.76)
        }
    }

    var accent: Color {
        switch self {
        case .system:
            Color(red: 0.10, green: 0.55, blue: 0.78)
        case .starship:
            Color(red: 0.39, green: 0.92, blue: 0.86)
        case .nvChad:
            Color(red: 0.58, green: 0.91, blue: 0.48)
        case .oudh:
            Color(red: 0.00, green: 0.00, blue: 0.93)
        }
    }

    var accentSecondary: Color {
        switch self {
        case .system:
            Color(red: 0.91, green: 0.24, blue: 0.45)
        case .starship:
            Color(red: 0.96, green: 0.63, blue: 0.23)
        case .nvChad:
            Color(red: 0.96, green: 0.43, blue: 0.72)
        case .oudh:
            Color(red: 1.00, green: 0.85, blue: 0.76)
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system, .oudh:
            nil
        case .starship, .nvChad:
            .dark
        }
    }

    func titleFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if self == .oudh {
            return .custom("Playfair Display", size: size).weight(weight)
        }
        return .system(size: size, weight: weight)
    }

    func bodyFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if self == .oudh {
            return .system(size: size, weight: weight, design: .serif)
        }
        return .system(size: size, weight: weight)
    }

    func uiFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if self == .oudh {
            return .system(size: size, weight: weight, design: .serif)
        }
        return .system(size: size, weight: weight)
    }

    func nsEditorFont(size: CGFloat) -> NSFont {
        if self == .oudh {
            return NSFont(name: "Georgia", size: size) ?? .systemFont(ofSize: size)
        }
        return .monospacedSystemFont(ofSize: size, weight: .regular)
    }
}

struct EditorWorkspace: View {
    @Binding var title: String
    @Binding var markdown: String
    @Binding var mode: EditorMode
    let status: String
    let theme: ForkEditorTheme
    let autosaveDraft: () -> Void
    let openURL: (URL) -> OpenURLAction.Result
    @State private var autosaveTask: Task<Void, Never>?
    @State private var hasPendingAutosave = false

    var body: some View {
        ZStack {
            EditorBackground(theme: theme)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedTitle)
                            .font(theme.titleFont(size: ForkTypography.h3, weight: .semibold))
                            .foregroundStyle(theme.primaryText)
                            .lineLimit(1)
                        Text(mode == .view ? "Viewing local page" : "Editing local page")
                            .font(theme.uiFont(size: ForkTypography.uiSmall))
                            .foregroundStyle(theme.secondaryText)
                    }

                    Spacer()

                    HStack(spacing: 2) {
                        ForEach(EditorMode.allCases) { mode in
                            Button {
                                self.mode = mode
                            } label: {
                                Text(mode.rawValue)
                                    .font(theme.uiFont(size: ForkTypography.headerControl, weight: .semibold))
                                    .frame(width: 62, height: 28)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(self.mode == mode ? theme.selectedControlText : theme.primaryText)
                            .background(self.mode == mode ? theme.accent : theme.editorSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding(2)
                    .background(theme.editorSurface.opacity(0.86))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(theme.chromeBackground.opacity(theme == .oudh ? 0.78 : 1))

                Divider().overlay(theme.divider)

                VStack(alignment: .leading, spacing: 16) {
                    switch mode {
                    case .view:
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                Text(selectedTitle)
                                    .font(theme.titleFont(size: ForkTypography.h1, weight: .semibold))
                                    .foregroundStyle(theme.primaryText)
                                    .lineLimit(2)

                                MarkdownBlocksView(markdown: markdown, theme: theme)
                                    .textSelection(.enabled)
                            }
                            .padding(.vertical, 30)
                            .frame(maxWidth: 860, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .top)
                        }
                    case .edit:
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Title", text: $title)
                                .font(theme.titleFont(size: ForkTypography.h1, weight: .semibold))
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 2)
                                .foregroundStyle(theme.primaryText)
                                .onChange(of: title) {
                                    scheduleAutosave()
                                }

                            Divider().overlay(theme.divider)

                            MarkdownEditor(
                                text: $markdown,
                                theme: theme,
                                onChange: scheduleAutosave,
                                onToggleMode: toggleMode
                            )
                            .frame(minHeight: 320)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .frame(maxWidth: 860, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .top)
                    }

                    Spacer(minLength: 0)

                    HStack {
                        Text(status)
                            .font(theme.uiFont(size: ForkTypography.uiSmall))
                            .foregroundStyle(theme.secondaryText)
                            .lineLimit(1)
                        Spacer()
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .background(ModeShortcutCatcher(onToggle: toggleMode))
        .onDisappear {
            autosaveTask?.cancel()
            flushAutosaveIfNeeded()
        }
        .onChange(of: mode) { _, newMode in
            if newMode == .view {
                flushAutosaveIfNeeded()
            }
        }
        .environment(\.openURL, OpenURLAction { url in
            let result = openURL(url)
            mode = .edit
            return result
        })
    }

    private var selectedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Page" : title
    }

    private func toggleMode() {
        mode = mode == .view ? .edit : .view
    }

    private func scheduleAutosave() {
        hasPendingAutosave = true
        autosaveTask?.cancel()
        autosaveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
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

private struct EditorBackground: View {
    let theme: ForkEditorTheme

    var body: some View {
        ZStack {
            theme.appBackground
            if theme == .oudh {
                OudhPattern()
                    .opacity(0.22)
            }
        }
        .ignoresSafeArea()
    }
}

private struct OudhPattern: View {
    var body: some View {
        Canvas { context, size in
            let color = Color(red: 0.61, green: 0.57, blue: 0.67)
            for x in stride(from: 1.0, through: size.width, by: 4.0) {
                for y in stride(from: 3.0, through: size.height, by: 4.0) {
                    context.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)), with: .color(color))
                }
            }
            for x in stride(from: 3.0, through: size.width, by: 4.0) {
                for y in stride(from: 1.0, through: size.height, by: 4.0) {
                    context.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)), with: .color(color))
                }
            }
        }
    }
}

private struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    let theme: ForkEditorTheme
    let onChange: () -> Void
    let onToggleMode: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        let textView = MarkdownNSTextView()
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.delegate = context.coordinator
        textView.onTextChange = {
            context.coordinator.parent.text = textView.string
            context.coordinator.parent.onChange()
        }
        textView.onToggleMode = onToggleMode
        scrollView.documentView = textView
        context.coordinator.textView = textView
        applyTheme(to: textView)
        textView.string = text
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? MarkdownNSTextView else {
            return
        }

        if textView.string != text {
            textView.string = text
        }
        textView.onTextChange = {
            context.coordinator.parent.text = textView.string
            context.coordinator.parent.onChange()
        }
        textView.onToggleMode = onToggleMode
        context.coordinator.parent = self
        applyTheme(to: textView)
    }

    private func applyTheme(to textView: NSTextView) {
        textView.font = theme.nsEditorFont(size: ForkTypography.body)
        textView.textColor = NSColor(theme.primaryText)
        textView.insertionPointColor = NSColor(theme.accent)
        textView.backgroundColor = NSColor(theme.editorSurface)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownEditor
        weak var textView: MarkdownNSTextView?

        init(_ parent: MarkdownEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? MarkdownNSTextView else {
                return
            }
            parent.text = textView.string
            parent.onChange()
        }
    }
}

private final class MarkdownNSTextView: NSTextView {
    var onTextChange: (() -> Void)?
    var onToggleMode: (() -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command),
              let key = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }

        switch key {
        case "b":
            wrapSelection(prefix: "**", suffix: "**")
            return true
        case "u":
            wrapSelection(prefix: "<u>", suffix: "</u>")
            return true
        case "e":
            onToggleMode?()
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }

    override func paste(_ sender: Any?) {
        if let pasted = NSPasteboard.general.string(forType: .string),
           let url = URL(string: pasted),
           ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
           selectedRange().length > 0 {
            let selected = (string as NSString).substring(with: selectedRange())
            replaceSelectedText(with: "[\(escapeMarkdownLinkText(selected))](\(pasted))", selectedTextOffset: 1, selectedTextLength: selected.count)
            return
        }

        super.paste(sender)
    }

    private func wrapSelection(prefix: String, suffix: String) {
        let range = selectedRange()
        let selected = range.length > 0 ? (string as NSString).substring(with: range) : ""
        replaceSelectedText(with: "\(prefix)\(selected)\(suffix)", selectedTextOffset: prefix.count, selectedTextLength: selected.count)
    }

    private func replaceSelectedText(with replacement: String, selectedTextOffset: Int, selectedTextLength: Int) {
        let range = selectedRange()
        shouldChangeText(in: range, replacementString: replacement)
        replaceCharacters(in: range, with: replacement)
        didChangeText()
        setSelectedRange(NSRange(location: range.location + selectedTextOffset, length: selectedTextLength))
        onTextChange?()
    }

    private func escapeMarkdownLinkText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
    }
}

private struct ModeShortcutCatcher: NSViewRepresentable {
    let onToggle: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = ModeShortcutView()
        view.onToggle = onToggle
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? ModeShortcutView {
            view.onToggle = onToggle
        }
    }
}

private final class ModeShortcutView: NSView {
    var onToggle: (() -> Void)?
    private var sawColon = false

    override var acceptsFirstResponder: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "e" {
            onToggle?()
            return
        }

        if event.characters == ":" {
            sawColon = true
            return
        }

        if sawColon, event.charactersIgnoringModifiers?.lowercased() == "e" {
            sawColon = false
            onToggle?()
            return
        }

        sawColon = false
        super.keyDown(with: event)
    }
}

private struct MarkdownBlocksView: View {
    let markdown: String
    let theme: ForkEditorTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(MarkdownBlock.parse(markdown)) { block in
                switch block.kind {
                case .heading(let level, let text):
                    Text(inlineMarkdown(text))
                        .font(headingFont(for: level))
                        .fontWeight(.semibold)
                        .foregroundStyle(theme.primaryText)
                case .paragraph(let text):
                    Text(inlineMarkdown(text))
                        .font(theme.bodyFont(size: ForkTypography.body))
                        .foregroundStyle(theme.primaryText)
                        .lineSpacing(ForkTypography.bodyLineSpacing)
                }
            }
        }
    }

    private func inlineMarkdown(_ markdown: String) -> AttributedString {
        let forkMarkdown = markdownWithWikiLinks(markdown)
        return (try? AttributedString(markdown: forkMarkdown)) ?? AttributedString(markdown)
    }

    private func markdownWithWikiLinks(_ markdown: String) -> String {
        var output = ""
        var cursor = markdown.startIndex

        while cursor < markdown.endIndex {
            guard let opening = markdown[cursor...].range(of: "[[") else {
                output += markdown[cursor...]
                break
            }

            output += markdown[cursor..<opening.lowerBound]
            let titleStart = opening.upperBound
            guard let closing = markdown[titleStart...].range(of: "]]") else {
                output += markdown[opening.lowerBound...]
                break
            }

            let rawTitle = String(markdown[titleStart..<closing.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if rawTitle.isEmpty {
                output += markdown[opening.lowerBound..<closing.upperBound]
            } else {
                output += markdownLink(forWikiTitle: rawTitle)
            }
            cursor = closing.upperBound
        }

        return output
    }

    private func markdownLink(forWikiTitle title: String) -> String {
        let escapedTitle = title
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
        let destination = title
            .addingPercentEncoding(withAllowedCharacters: .forkWikiLinkDestinationAllowed) ?? title
        return "[\(escapedTitle)](\(destination))"
    }

    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1:
            return theme.titleFont(size: ForkTypography.h1, weight: .semibold)
        case 2:
            return theme.titleFont(size: ForkTypography.h2, weight: .semibold)
        case 3:
            return theme.titleFont(size: ForkTypography.h3, weight: .semibold)
        default:
            return theme.bodyFont(size: ForkTypography.body, weight: .semibold)
        }
    }
}

private extension CharacterSet {
    static var forkWikiLinkDestinationAllowed: CharacterSet {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "#?[]()")
        return allowed
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

@MainActor
final class ForkAppModel: ObservableObject {
    @Published var draftTitle = ""
    @Published var draftMarkdown = ""
    @Published var statusMessage = "Ready."
    @Published var errorMessage: String?
    @Published var drafts: [DraftDocument] = []
    @Published var selectedDraftID = "home"
    @Published var editorMode: EditorMode = .view
    @Published var theme = ForkEditorTheme.saved {
        didSet {
            theme.save()
        }
    }
    @Published var isConfirmingDraftDeletion = false
    @Published var pendingDraftDeletionTitle = "this page"

    private var draftProvider: StoredDraftProvider
    private var pendingDraftDeletionID: String?

    init() {
        do {
            draftProvider = try StoredDraftProvider(
                store: FileDraftStore(rootDirectory: forkDraftDirectory())
            )
            try load()
        } catch {
            draftProvider = StoredDraftProvider(store: MemoryDraftStore())
            errorMessage = error.localizedDescription
            try? load()
        }
    }

    func toggleEditorMode() {
        editorMode = editorMode == .view ? .edit : .view
    }

    func autosaveDraft() {
        do {
            _ = try persistDraft()
            try refreshDrafts()
            statusMessage = "Local edits saved."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Page could not be autosaved."
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

    func openEditorMarkdownLink(_ url: URL) -> OpenURLAction.Result {
        if let scheme = url.scheme?.lowercased(), !scheme.isEmpty {
            guard ["http", "https"].contains(scheme) else {
                statusMessage = "Only local wiki links and web links open here."
                return .discarded
            }
            NSWorkspace.shared.open(url)
            return .handled
        }

        return openLocalPageLink(url)
    }

    private func load() throws {
        let draft = try draftProvider.loadOrCreateHomeDraft()
        try refreshDrafts()
        applyDraft(draft)
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
    }

    private func refreshDrafts() throws {
        drafts = try draftProvider.loadDrafts()
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
            statusMessage = "Page deleted."
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
            statusMessage = "Page order updated."
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

    private func openLocalPageLink(_ url: URL) -> OpenURLAction.Result {
        guard let target = localPageTarget(from: url) else {
            statusMessage = "Local page link could not be opened."
            return .discarded
        }

        do {
            _ = try persistDraft()
            let localDrafts = try draftProvider.loadDrafts()
            if let existingDraft = localDrafts.first(where: { wikiSlug(for: $0.title) == target.slug }) {
                try loadDraft(existingDraft.id)
                try refreshDrafts()
                editorMode = .edit
                statusMessage = "Editing \(existingDraft.title)."
                return .handled
            }

            let draft = DraftDocument(
                id: UUID().uuidString,
                title: target.title,
                markdown: "# \(target.title)\n\n",
                updatedAt: Date(),
                pageOrder: nextPageOrder(in: localDrafts)
            )
            try draftProvider.saveDraft(draft)
            try refreshDrafts()
            try loadDraft(draft.id)
            editorMode = .edit
            statusMessage = "Created \(draft.title)."
            return .handled
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Local page link could not be opened."
            return .discarded
        }
    }

    private func localPageTarget(from url: URL) -> (title: String, slug: String)? {
        var target = (url.absoluteString.removingPercentEncoding ?? url.absoluteString)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let fragment = target.firstIndex(of: "#") {
            target = String(target[..<fragment])
        }
        if let query = target.firstIndex(of: "?") {
            target = String(target[..<query])
        }
        target = target.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if target.hasSuffix(".md") {
            target.removeLast(3)
        }
        guard !target.isEmpty else {
            return nil
        }

        let titleSeed = target
            .split(separator: "/")
            .last
            .map(String.init) ?? target
        let title = titleSeed
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .capitalized
        let slug = wikiSlug(for: title)
        return slug.isEmpty ? nil : (title, slug)
    }

    private func wikiSlug(for title: String) -> String {
        title
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    private func nextPageOrder(in drafts: [DraftDocument]) -> Int {
        (drafts.filter { $0.id != "home" }.map(\.pageOrder).max() ?? 0) + 1
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
}
