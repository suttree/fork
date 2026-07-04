import Foundation

public struct ForkAddress: Codable, Equatable, Hashable, Sendable, CustomStringConvertible {
    public enum Kind: String, Codable, Sendable {
        case author
        case document = "doc"
    }

    public let kind: Kind
    public let key: String

    public var rawValue: String {
        "fork://\(kind.rawValue)/\(key)"
    }

    public var description: String {
        rawValue
    }

    public init(kind: Kind, publicKeyData: Data) {
        self.kind = kind
        self.key = Base64URL.encode(publicKeyData)
    }

    public init(_ rawValue: String) throws {
        let prefix = "fork://"
        guard rawValue.hasPrefix(prefix) else {
            throw ForkError.invalidAddress(rawValue)
        }

        let remainder = rawValue.dropFirst(prefix.count)
        let parts = remainder.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let kind = Kind(rawValue: String(parts[0])),
              !parts[1].isEmpty else {
            throw ForkError.invalidAddress(rawValue)
        }

        self.kind = kind
        self.key = String(parts[1])
    }

    public var publicKeyData: Data {
        get throws {
            try Base64URL.decode(key)
        }
    }
}
