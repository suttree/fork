import Foundation
import Security

public enum KeychainIdentityStoreError: Error, Equatable, LocalizedError {
    case unexpectedItemData
    case keychainStatus(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .unexpectedItemData:
            "The saved identity could not be read from Keychain."
        case .keychainStatus(let status):
            "Keychain returned status \(status)."
        }
    }
}

public final class KeychainIdentityStore: IdentityStore, @unchecked Sendable {
    private let service: String

    public init(service: String = "app.fork.identity") {
        self.service = service
    }

    public func loadIdentity(role: ForkIdentity.Role, account: String) throws -> ForkIdentity? {
        var query = baseQuery(role: role, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainIdentityStoreError.keychainStatus(status)
        }
        guard let data = result as? Data else {
            throw KeychainIdentityStoreError.unexpectedItemData
        }
        return try ForkIdentity(role: role, rawPrivateKey: data)
    }

    public func saveIdentity(_ identity: ForkIdentity, account: String) throws {
        let query = baseQuery(role: identity.role, account: account)
        let update: [String: Any] = [
            kSecValueData as String: identity.rawPrivateKey
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainIdentityStoreError.keychainStatus(updateStatus)
        }

        var addQuery = query
        addQuery[kSecValueData as String] = identity.rawPrivateKey
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainIdentityStoreError.keychainStatus(addStatus)
        }
    }

    private func baseQuery(role: ForkIdentity.Role, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(role.storageName):\(account)"
        ]
    }
}
