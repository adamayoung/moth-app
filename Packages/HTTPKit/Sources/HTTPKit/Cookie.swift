//  Cookie.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation

/// `value` is a credential as often as not, so never log one. `domain` is lower case, with no leading dot.
public struct Cookie: Sendable, Hashable {

    public struct Identity: Sendable, Hashable {

        public let name: String
        public let domain: String
        public let path: String

    }

    public var name: String
    public var value: String
    public var domain: String
    public var isHostOnly: Bool
    public var path: String
    public var expiresAt: Date?
    public var isSecure: Bool
    public var isHTTPOnly: Bool
    public var createdAt: Date

    public init(
        name: String,
        value: String,
        domain: String,
        isHostOnly: Bool,
        path: String,
        expiresAt: Date?,
        isSecure: Bool = false,
        isHTTPOnly: Bool = false,
        createdAt: Date
    ) {
        self.name = name
        self.value = value
        self.domain = domain
        self.isHostOnly = isHostOnly
        self.path = path
        self.expiresAt = expiresAt
        self.isSecure = isSecure
        self.isHTTPOnly = isHTTPOnly
        self.createdAt = createdAt
    }

    public var identity: Identity {
        Identity(name: name, domain: domain, path: path)
    }

    /// Dates compare as intervals: the 27.2 SDK binds `Date`'s `<=`, `>=` and `>` to symbols macOS 27.0's Foundation
    /// lacks, and a binary that uses one won't load there.
    public func isExpired(at now: Date) -> Bool {
        expiresAt.map { $0.timeIntervalSince(now) <= 0 } ?? false
    }

    /// RFC 6265 section 5.4's order: longer paths first, then older cookies.
    func sendsBefore(_ other: Cookie) -> Bool {
        guard path.count == other.path.count else {
            return path.count > other.path.count
        }
        return createdAt.timeIntervalSince(other.createdAt) < 0
    }

    /// RFC 6265 section 5.4. `HttpOnly` and `SameSite` don't apply: there are no scripts and no browsing context.
    public func matches(_ url: URL, at now: Date) -> Bool {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host(percentEncoded: false)?.lowercased()
        else {
            return false
        }

        return !isExpired(at: now)
            && (!isSecure || scheme == "https")
            && matchesDomain(of: host)
            && Self.path(path, matches: Self.requestPath(of: url))
    }

    private func matchesDomain(of host: String) -> Bool {
        if isHostOnly {
            return host == domain
        }
        return Self.host(host, isIn: domain)
    }

    /// RFC 6265bis section 5.7's test for a cookie a plain HTTP response may not set: either domain within the other,
    /// on any path.
    func sharesName(with other: Cookie) -> Bool {
        name == other.name && (Self.host(domain, isIn: other.domain) || Self.host(other.domain, isIn: domain))
    }

    static func host(_ host: String, isIn domain: String) -> Bool {
        host == domain || (host.hasSuffix(".\(domain)") && !host.isIPAddress)
    }

    private static func path(_ cookiePath: String, matches requestPath: String) -> Bool {
        guard requestPath.hasPrefix(cookiePath) else {
            return false
        }
        return requestPath.count == cookiePath.count
            || cookiePath.hasSuffix("/")
            || requestPath.dropFirst(cookiePath.count).hasPrefix("/")
    }

    static func requestPath(of url: URL) -> String {
        let path = url.path(percentEncoded: true)
        return path.isEmpty ? "/" : path
    }

}

extension String {

    var isIPAddress: Bool {
        contains(":") || allSatisfy { $0.isNumber || $0 == "." }
    }

}
