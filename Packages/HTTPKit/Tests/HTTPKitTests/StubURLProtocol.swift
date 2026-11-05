//  StubURLProtocol.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation
import Synchronization

final class StubURLProtocol: URLProtocol {

    enum Reply {
        case http(status: Int, headers: [String: String], body: Data)
        case notHTTP(body: Data)
        case failure(any Error)
        case neverFinishes
    }

    private struct State {
        var reply: Reply?
        var requests: [URLRequest] = []
        var loadsStarted = AsyncStream<Void>.makeStream()
    }

    private static let state = Mutex(State())

    static func session(replying reply: Reply) -> URLSession {
        state.withLock { $0 = State(reply: reply) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static var receivedRequests: [URLRequest] {
        state.withLock(\.requests)
    }

    static var loadsStarted: AsyncStream<Void> {
        state.withLock(\.loadsStarted.stream)
    }

    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let reply = Self.state.withLock { state in
            state.requests.append(request)
            state.loadsStarted.continuation.yield()
            return state.reply
        }

        switch reply {
        case .http(let status, let headers, let body):
            guard
                let response = HTTPURLResponse(
                    url: requestURL, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers
                )
            else {
                client?.urlProtocol(self, didFailWithError: URLError(.cannotParseResponse))
                return
            }
            finish(response, body: body)

        case .notHTTP(let body):
            let response = URLResponse(
                url: requestURL, mimeType: nil, expectedContentLength: body.count, textEncodingName: nil
            )
            finish(response, body: body)

        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)

        case .neverFinishes:
            break

        case nil:
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
        }
    }

    override func stopLoading() {}

    private var requestURL: URL {
        request.url ?? URL(filePath: "/")
    }

    private func finish(_ response: URLResponse, body: Data) {
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

}
