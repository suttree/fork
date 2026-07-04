import ForkCore
import SwiftUI

@main
struct ForkApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var result: Result<VerticalSliceResult, Error> = Result {
        try VerticalSliceDemo.run()
    }

    var body: some View {
        switch result {
        case .success(let slice):
            ForkShell(slice: slice)
        case .failure(let error):
            VStack(alignment: .leading, spacing: 12) {
                Text("Fork")
                    .font(.largeTitle)
                Text("The first local peer loop could not start.")
                    .foregroundStyle(.secondary)
                Text(error.localizedDescription)
                    .font(.callout)
            }
            .padding(28)
            .frame(minWidth: 760, minHeight: 520)
        }
    }
}

struct ForkShell: View {
    let slice: VerticalSliceResult

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
                ReaderView(page: slice.cachedPage)
                    .frame(minWidth: 420)

                Divider()

                WriterPreview(markdown: slice.cachedPage.markdown)
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
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Write")
                .font(.title2)
                .fontWeight(.semibold)
            TextEditor(text: .constant(markdown))
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Button {
            } label: {
                Label("Publish Signed Record", systemImage: "signature")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
}
