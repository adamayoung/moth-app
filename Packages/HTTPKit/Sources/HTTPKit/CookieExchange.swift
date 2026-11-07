//  CookieExchange.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation

/// One send's cookies: the `Cookie` header the person typed, and the jar that adds to it and keeps what comes back.
/// The typed header goes only to the origin it was typed for.
struct CookieExchange: Sendable {

    let jar: any CookieJar
    let manualHeader: String?
    let origin: URL?

    init(jar: any CookieJar, request: URLRequest) {
        self.jar = jar
        self.manualHeader = request.value(forHTTPHeaderField: "Cookie")
        self.origin = request.url
    }

    func preparing(_ request: URLRequest) async -> URLRequest {
        guard let url = request.url else {
            return request
        }
        var request = request
        let manual = url.hasSameOrigin(as: origin) ? manualHeader : nil
        await request.setValue(
            CookieHeader.merging(manual: manual, jar: jar.cookies(for: url)),
            forHTTPHeaderField: "Cookie"
        )
        return request
    }

    func receive(_ response: HTTPURLResponse) async {
        guard let url = response.url else {
            return
        }
        let cookies = Cookie.received(in: response.stringHeaders, from: url, at: Date())
        if !cookies.isEmpty {
            await jar.receive(cookies, from: url)
        }
    }

}

extension HTTPURLResponse {

    var stringHeaders: [String: String] {
        var headers: [String: String] = [:]
        for (name, value) in allHeaderFields {
            if let name = name as? String, let value = value as? String {
                headers[name] = value
            }
        }
        return headers
    }

}
