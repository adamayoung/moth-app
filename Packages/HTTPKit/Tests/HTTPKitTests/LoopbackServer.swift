//  LoopbackServer.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation
import Network

/// Writes raw responses on 127.0.0.1, for what `StubURLProtocol` cannot show: wire bytes, protocol, redirects
/// and repeated header names. A path with no route gets `fallback`, or no answer at all.
final class LoopbackServer: Sendable {

    private let listener: NWListener

    init(routes: [String: String], fallback: String? = nil) async throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        let listener = try NWListener(using: parameters)
        let queue = DispatchQueue(label: "LoopbackServer")

        listener.newConnectionHandler = { connection in
            connection.start(queue: queue)
            Self.serve(connection, routes: routes, fallback: fallback)
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    listener.stateUpdateHandler = nil
                    continuation.resume()

                case .failed(let error), .waiting(let error):
                    listener.stateUpdateHandler = nil
                    continuation.resume(throwing: error)

                default:
                    break
                }
            }
            listener.start(queue: queue)
        }
        self.listener = listener
    }

    deinit {
        listener.cancel()
    }

    func url(path: String, scheme: String = "http") throws -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "127.0.0.1"
        components.port = listener.port.map { Int($0.rawValue) }
        components.path = path
        return try components.url ?? { throw URLError(.badURL) }()
    }

    private static func serve(_ connection: NWConnection, routes: [String: String], fallback: String?) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, _ in
            guard let data, !data.isEmpty else {
                connection.cancel()
                return
            }
            guard let reply = routes[path(of: data)] ?? fallback else {
                serve(connection, routes: routes, fallback: fallback)
                return
            }
            connection.send(
                content: Data(reply.utf8),
                completion: .contentProcessed { _ in serve(connection, routes: routes, fallback: fallback) }
            )
        }
    }

    private static func path(of request: Data) -> String {
        String(bytes: request, encoding: .utf8)?.split(separator: " ").dropFirst().first.map(String.init) ?? ""
    }

}
