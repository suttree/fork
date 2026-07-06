import Foundation

public enum ForkError: Error, Equatable, LocalizedError {
    case protectedDraft(String)

    public var errorDescription: String? {
        switch self {
        case .protectedDraft(let id):
            "The \(id) draft cannot be deleted."
        }
    }
}
