//  HTTPMethod.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

/// A struct rather than an enum with a custom case, so `GET` has one representation.
/// RFC 9110 makes methods case-sensitive, so `get` is a custom method.
public nonisolated struct HTTPMethod: RawRepresentable, Sendable, Hashable, Codable {

    public static let get = HTTPMethod(rawValue: "GET")
    public static let post = HTTPMethod(rawValue: "POST")
    public static let put = HTTPMethod(rawValue: "PUT")
    public static let patch = HTTPMethod(rawValue: "PATCH")
    public static let delete = HTTPMethod(rawValue: "DELETE")
    public static let head = HTTPMethod(rawValue: "HEAD")
    public static let options = HTTPMethod(rawValue: "OPTIONS")
    public static let trace = HTTPMethod(rawValue: "TRACE")
    public static let connect = HTTPMethod(rawValue: "CONNECT")

    public static let standard = [get, post, put, patch, delete, head, options, trace, connect]

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

}
