import Foundation

public struct VerticalSliceResult: Equatable, Sendable {
    public var authorAddress: ForkAddress
    public var documentAddress: ForkAddress
    public var livePage: RenderedPage
    public var cachedPage: RenderedPage
}

public enum VerticalSliceDemo {
    public static func run(now: Date = Date()) throws -> VerticalSliceResult {
        let authorPeer = LocalPeer(name: "Author")
        let readerPeer = LocalPeer(name: "Reader")

        let authorAddress = authorPeer.createAuthorIdentity()
        try authorPeer.publishHomePage(
            title: "A Small Fork Place",
            markdown: """
            # A Small Fork Place

            This page was written as Markdown, signed by its document key, exchanged with another local peer, and rendered after the author peer went offline.
            """,
            createdAt: now
        )

        let livePage = try readerPeer.renderAuthor(
            authorAddress,
            preferLivePeer: authorPeer,
            fetchedAt: now
        )
        let cachedPage = try readerPeer.renderAuthor(authorAddress, preferLivePeer: nil)

        return VerticalSliceResult(
            authorAddress: authorAddress,
            documentAddress: livePage.documentAddress,
            livePage: livePage,
            cachedPage: cachedPage
        )
    }
}
