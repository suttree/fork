import CryptoKit
import Foundation

public struct ForkIdentity: Sendable {
    public enum Role: Sendable {
        case author
        case document
    }

    public let role: Role
    private let privateKey: Curve25519.Signing.PrivateKey

    public var publicKeyData: Data {
        privateKey.publicKey.rawRepresentation
    }

    public var address: ForkAddress {
        ForkAddress(
            kind: role == .author ? .author : .document,
            publicKeyData: publicKeyData
        )
    }

    public init(role: Role) {
        self.role = role
        self.privateKey = Curve25519.Signing.PrivateKey()
    }

    public init(role: Role, rawPrivateKey: Data) throws {
        self.role = role
        self.privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: rawPrivateKey)
    }

    public var rawPrivateKey: Data {
        privateKey.rawRepresentation
    }

    public func sign(_ data: Data) throws -> Data {
        try privateKey.signature(for: data)
    }

    public static func verify(signature: Data, for data: Data, publicKeyData: Data) throws -> Bool {
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
        return publicKey.isValidSignature(signature, for: data)
    }
}
