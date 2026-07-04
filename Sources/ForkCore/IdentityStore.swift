import Foundation

public protocol IdentityStore: Sendable {
    func loadIdentity(role: ForkIdentity.Role, account: String) throws -> ForkIdentity?
    func saveIdentity(_ identity: ForkIdentity, account: String) throws
}

public struct StoredIdentityProvider: Sendable {
    private let store: any IdentityStore

    public init(store: any IdentityStore) {
        self.store = store
    }

    public func loadOrCreateAuthorIdentity(account: String = "author") throws -> ForkIdentity {
        if let identity = try store.loadIdentity(role: .author, account: account) {
            return identity
        }

        let identity = ForkIdentity(role: .author)
        try store.saveIdentity(identity, account: account)
        return identity
    }

    public func loadOrCreateDocumentIdentity(account: String) throws -> ForkIdentity {
        if let identity = try store.loadIdentity(role: .document, account: account) {
            return identity
        }

        let identity = ForkIdentity(role: .document)
        try store.saveIdentity(identity, account: account)
        return identity
    }
}

public final class MemoryIdentityStore: IdentityStore, @unchecked Sendable {
    private var keysByAccount: [String: Data] = [:]

    public init() {}

    public func loadIdentity(role: ForkIdentity.Role, account: String) throws -> ForkIdentity? {
        guard let rawPrivateKey = keysByAccount[key(for: role, account: account)] else {
            return nil
        }
        return try ForkIdentity(role: role, rawPrivateKey: rawPrivateKey)
    }

    public func saveIdentity(_ identity: ForkIdentity, account: String) throws {
        keysByAccount[key(for: identity.role, account: account)] = identity.rawPrivateKey
    }

    private func key(for role: ForkIdentity.Role, account: String) -> String {
        "\(role.storageName):\(account)"
    }
}

extension ForkIdentity.Role {
    var storageName: String {
        switch self {
        case .author:
            "author"
        case .document:
            "document"
        }
    }
}
