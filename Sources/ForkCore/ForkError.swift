import Foundation

public enum ForkError: Error, Equatable, LocalizedError {
    case invalidAddress(String)
    case invalidBase64URL
    case invalidPublicKey
    case invalidSignature
    case protectedDraft(String)
    case missingPublicationDocuments
    case missingDocument(ForkAddress)
    case missingManifest(ForkAddress)

    public var errorDescription: String? {
        switch self {
        case .invalidAddress(let address):
            "Invalid Fork address: \(address)"
        case .invalidBase64URL:
            "Invalid base64url data."
        case .invalidPublicKey:
            "Invalid public key."
        case .invalidSignature:
            "This record was not signed by the expected key."
        case .protectedDraft(let id):
            "The \(id) draft cannot be deleted."
        case .missingPublicationDocuments:
            "A Fork place needs at least one document to publish."
        case .missingDocument(let address):
            "No verified cached document for \(address.rawValue)."
        case .missingManifest(let address):
            "No verified cached manifest for \(address.rawValue)."
        }
    }
}
