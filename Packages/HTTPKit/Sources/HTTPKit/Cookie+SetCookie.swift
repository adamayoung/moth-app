//  Cookie+SetCookie.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation

public extension Cookie {

    /// `HTTPCookie` splits URLSession's comma-joined header, but keeps a `Domain` the host isn't in and a `Path`
    /// that isn't one, so those rules are applied here. There is no public suffix list: a domain needs a dot.
    static func received(in headers: [String: String], from url: URL, at now: Date) -> [Cookie] {
        guard let header = headers.first(where: { $0.key.caseInsensitiveCompare("Set-Cookie") == .orderedSame }),
              let host = url.host(percentEncoded: false)?.lowercased()
        else {
            return []
        }

        return HTTPCookie.cookies(withResponseHeaderFields: ["Set-Cookie": header.value], for: url).compactMap {
            Cookie($0, host: host, defaultPath: defaultPath(of: url), at: now)
        }
    }

    private init?(_ cookie: HTTPCookie, host: String, defaultPath: String, at now: Date) {
        let domain = cookie.domain.lowercased()
        let isHostOnly = !domain.hasPrefix(".")
        let bareDomain = isHostOnly ? domain : String(domain.dropFirst())

        if isHostOnly {
            guard bareDomain == host else {
                return nil
            }
        } else if bareDomain != host {
            guard bareDomain.contains("."), Self.host(host, isIn: bareDomain) else {
                return nil
            }
        }

        self.init(
            name: cookie.name,
            value: cookie.value,
            domain: bareDomain,
            isHostOnly: isHostOnly || host.isIPAddress,
            path: cookie.path.hasPrefix("/") ? cookie.path : defaultPath,
            expiresAt: cookie.expiresDate,
            isSecure: cookie.isSecure,
            isHTTPOnly: cookie.isHTTPOnly,
            createdAt: now
        )
    }

    /// RFC 6265 section 5.1.4.
    private static func defaultPath(of url: URL) -> String {
        let path = requestPath(of: url)
        guard let lastSlash = path.lastIndex(of: "/"), lastSlash != path.startIndex else {
            return "/"
        }
        return String(path[..<lastSlash])
    }

}
