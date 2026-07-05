import Foundation
import Network

public enum LoopbackAuthorBundleTransportError: Error, Equatable, LocalizedError {
    case invalidPort
    case invalidRequest
    case listenerFailed(String)
    case listenerTimedOut
    case serverDidNotPublishBaseURL

    public var errorDescription: String? {
        switch self {
        case .invalidPort:
            "The loopback transport could not reserve a local port."
        case .invalidRequest:
            "The loopback transport received an invalid request."
        case .listenerFailed(let message):
            "The loopback transport listener failed: \(message)"
        case .listenerTimedOut:
            "The loopback transport listener did not become ready in time."
        case .serverDidNotPublishBaseURL:
            "The loopback transport did not publish a usable local URL."
        }
    }
}

public final class LoopbackAuthorBundleServer: @unchecked Sendable {
    private let peer: LocalPeer
    private let listener: NWListener
    private let queue = DispatchQueue(label: "Fork.LoopbackAuthorBundleServer")
    private let state = LoopbackServerState()

    public var baseURL: URL {
        get throws {
            guard let url = state.baseURL else {
                throw LoopbackAuthorBundleTransportError.serverDidNotPublishBaseURL
            }
            return url
        }
    }

    public init(peer: LocalPeer, port: UInt16 = 0) throws {
        guard let port = NWEndpoint.Port(rawValue: port) else {
            throw LoopbackAuthorBundleTransportError.invalidPort
        }

        self.peer = peer
        self.listener = try NWListener(using: .tcp, on: port)
    }

    public func start(timeout: TimeInterval = 2) throws {
        let ready = DispatchSemaphore(value: 0)

        listener.stateUpdateHandler = { [weak self] state in
            guard let self else {
                return
            }

            switch state {
            case .ready:
                if let port = listener.port?.rawValue {
                    self.state.baseURL = URL(string: "http://127.0.0.1:\(port)")
                }
                ready.signal()
            case .failed(let error):
                self.state.error = error
                ready.signal()
            default:
                break
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }

        listener.start(queue: queue)

        if ready.wait(timeout: .now() + timeout) == .timedOut {
            throw LoopbackAuthorBundleTransportError.listenerTimedOut
        }

        if let error = state.error {
            throw LoopbackAuthorBundleTransportError.listenerFailed(error.localizedDescription)
        }

        guard state.baseURL != nil else {
            throw LoopbackAuthorBundleTransportError.serverDidNotPublishBaseURL
        }
    }

    public func stop() {
        listener.cancel()
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8_192) { [weak self] data, _, _, _ in
            guard let self else {
                connection.cancel()
                return
            }

            let response = self.response(for: data)
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    private func response(for data: Data?) -> Data {
        do {
            guard let data,
                  let request = String(data: data, encoding: .utf8) else {
                throw LoopbackAuthorBundleTransportError.invalidRequest
            }

            let address = try authorAddress(from: request)
            let body = try peer.authorBundleData(for: address)
            return httpResponse(
                status: "200 OK",
                contentType: "application/vnd.fork.author-bundle+json",
                body: body
            )
        } catch {
            return httpResponse(
                status: "404 Not Found",
                contentType: "text/plain; charset=utf-8",
                body: Data("No verified author bundle found.".utf8)
            )
        }
    }

    private func authorAddress(from request: String) throws -> ForkAddress {
        guard let requestLine = request.components(separatedBy: "\r\n").first else {
            throw LoopbackAuthorBundleTransportError.invalidRequest
        }

        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2,
              parts[0] == "GET" else {
            throw LoopbackAuthorBundleTransportError.invalidRequest
        }

        let path = String(parts[1]).removingPercentEncoding ?? String(parts[1])
        let pathParts = path.split(separator: "/").map(String.init)
        guard pathParts.count == 3,
              pathParts[0] == "authors",
              pathParts[2] == "bundle" else {
            throw LoopbackAuthorBundleTransportError.invalidRequest
        }

        return try ForkAddress("fork://author/\(pathParts[1])")
    }

    private func httpResponse(status: String, contentType: String, body: Data) -> Data {
        var response = Data(
            """
            HTTP/1.1 \(status)\r
            Content-Type: \(contentType)\r
            Content-Length: \(body.count)\r
            Connection: close\r
            \r

            """.utf8
        )
        response.append(body)
        return response
    }
}

public struct LoopbackAuthorBundleClient: AuthorBundleSource, Sendable {
    public let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    public func authorBundleData(for address: ForkAddress) throws -> Data {
        let url = baseURL
            .appendingPathComponent("authors", isDirectory: true)
            .appendingPathComponent(address.key, isDirectory: true)
            .appendingPathComponent("bundle")
        return try Data(contentsOf: url)
    }
}

private final class LoopbackServerState: @unchecked Sendable {
    private let lock = NSLock()
    private var _baseURL: URL?
    private var _error: NWError?

    var baseURL: URL? {
        get {
            lock.withLock { _baseURL }
        }
        set {
            lock.withLock { _baseURL = newValue }
        }
    }

    var error: NWError? {
        get {
            lock.withLock { _error }
        }
        set {
            lock.withLock { _error = newValue }
        }
    }
}
