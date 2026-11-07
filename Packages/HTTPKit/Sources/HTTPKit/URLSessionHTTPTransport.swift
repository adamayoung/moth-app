//  URLSessionHTTPTransport.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation

public struct URLSessionHTTPTransport: HTTPTransport {

    let session: URLSession

    public init(session: URLSession) {
        self.session = session
    }

    /// An API client shows what the server sent, so URLSession keeps no cache, credential or cookie of its own:
    /// cookies go through the ``CookieJar`` a send is given.
    public static var sessionConfiguration: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        return configuration
    }

    @concurrent
    public func send(_ request: URLRequest, cookies jar: any CookieJar?) async throws -> HTTPResponse {
        let cookies = jar.map { CookieExchange(jar: $0, request: request) }
        let request = await cookies?.preparing(request) ?? request
        let recorder = TaskMetricsRecorder(cookies: cookies)
        let body: Data
        let response: URLResponse
        do {
            (body, response) = try await session.data(for: request, delegate: recorder)
        } catch {
            throw HTTPTransportError.translating(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPTransportError.notHTTP
        }
        await cookies?.receive(httpResponse)

        return HTTPResponse(
            status: httpResponse.statusCode,
            headers: httpResponse.stringHeaders,
            body: body,
            metrics: recorder.metrics,
            url: httpResponse.url
        )
    }

}
