//  LoopbackServer.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation
import Network
import Synchronization

/// Writes raw responses on 127.0.0.1, for what `StubURLProtocol` cannot show: wire bytes, protocol, redirects,
/// repeated header names and, given an identity, TLS.
final class LoopbackServer: Sendable {

    private let listener: NWListener
    private final class Received: Sendable {

        let requests = Mutex<[String]>([])

    }

    private let received: Received

    /// What each read from a connection held, in order: a small request arrives whole.
    var requests: [String] {
        received.requests.withLock(\.self)
    }

    init(routes: [String: String], fallback: String? = nil, identity: SecIdentity? = nil) async throws {
        let parameters = Self.parameters(identity: identity)
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        let listener = try NWListener(using: parameters)
        let queue = DispatchQueue(label: "LoopbackServer")
        let received = Received()

        listener.newConnectionHandler = { connection in
            connection.start(queue: queue)
            Self.serve(connection, routes: routes, fallback: fallback) { request in
                received.requests.withLock { $0.append(request) }
            }
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
        self.received = received
    }

    deinit {
        listener.cancel()
    }

    private static func parameters(identity: SecIdentity?) -> NWParameters {
        guard let identity, let secIdentity = sec_identity_create(identity) else {
            return .tcp
        }
        let tls = NWProtocolTLS.Options()
        sec_protocol_options_set_local_identity(tls.securityProtocolOptions, secIdentity)
        return NWParameters(tls: tls)
    }

    func url(path: String, scheme: String = "http", host: String = "127.0.0.1") throws -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = listener.port.map { Int($0.rawValue) }
        components.path = path
        return try components.url ?? { throw URLError(.badURL) }()
    }

    func request(to path: String) -> String? {
        requests.last { Self.path(of: Data($0.utf8)) == path }
    }

    private static func serve(
        _ connection: NWConnection,
        routes: [String: String],
        fallback: String?,
        record: @escaping @Sendable (String) -> Void
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, _ in
            guard let data, !data.isEmpty else {
                connection.cancel()
                return
            }
            record(String(bytes: data, encoding: .utf8) ?? "")
            guard let reply = routes[path(of: data)] ?? fallback else {
                serve(connection, routes: routes, fallback: fallback, record: record)
                return
            }
            connection.send(
                content: Data(reply.utf8),
                completion: .contentProcessed { _ in
                    serve(connection, routes: routes, fallback: fallback, record: record)
                }
            )
        }
    }

    private static func path(of request: Data) -> String {
        String(bytes: request, encoding: .utf8)?.split(separator: " ").dropFirst().first.map(String.init) ?? ""
    }

}
