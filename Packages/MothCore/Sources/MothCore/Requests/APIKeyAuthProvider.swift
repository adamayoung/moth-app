//  APIKeyAuthProvider.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated struct APIKeyAuthProvider: AuthProvider {

    private let name: String
    private let value: String
    private let location: APIKeyLocation

    public init(name: String, value: String, location: APIKeyLocation) {
        self.name = name
        self.value = value
        self.location = location
    }

    public func apply(to request: inout URLRequest) async throws {
        switch location {
        case .header:
            guard name.isHTTPToken, value.isSendableHeaderValue else {
                throw RequestBuildError.invalidAPIKey
            }

            request.setValue(value, forHTTPHeaderField: name)
        case .query:
            try addToQuery(of: &request)
        }
    }

    /// Works on the query's text because `percentEncodedQueryItems`' setter traps on a typed `a=b=c`.
    private func addToQuery(of request: inout URLRequest) throws {
        guard
            let url = request.url,
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            throw RequestBuildError.invalidURL
        }

        let others = (components.percentEncodedQuery ?? "")
            .split(separator: "&")
            .filter { Self.decodedName(ofPair: $0) != name }
            .map(String.init)
        components.percentEncodedQuery = (others + [KeyValue(key: name, value: value).percentEncodedPair])
            .joined(separator: "&")

        guard let replaced = components.url else {
            throw RequestBuildError.invalidURL
        }

        request.url = replaced
    }

    /// A `+` is a space to a server.
    private static func decodedName(ofPair pair: Substring) -> String? {
        pair.prefix { $0 != "=" }.replacing("+", with: " ").removingPercentEncoding
    }

}
