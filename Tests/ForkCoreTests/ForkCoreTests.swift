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

    @Test("author and document addresses are key-derived")
    func addressesAreKeyDerived() throws {
        let author = ForkIdentity(role: .author)
        let document = ForkIdentity(role: .document)

        #expect(author.address.rawValue.hasPrefix("fork://author/"))
        #expect(document.address.rawValue.hasPrefix("fork://doc/"))
        #expect(try author.address.publicKeyData == author.publicKeyData)
        #expect(try document.address.publicKeyData == document.publicKeyData)
    }
}
