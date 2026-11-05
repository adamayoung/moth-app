//  ResolvedRequest+URL.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

nonisolated extension ResolvedRequest {

    private static let sendableSchemes: Set<String> = ["http", "https"]

    func sendableURL() throws -> URL {
        let address = url.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !address.isEmpty, var components = URLComponents(string: Self.withScheme(address)),
              let scheme = components.scheme?.lowercased(),
              Self.sendableSchemes.contains(scheme),
              components.host?.isEmpty == false
        else {
            throw RequestBuildError.invalidURL
        }

        components.percentEncodedPath = substitutingPathVariables(in: components.percentEncodedPath)
        components.percentEncodedQuery = appendingQueryParameters(to: components.percentEncodedQuery)

        guard let url = components.url else {
            throw RequestBuildError.invalidURL
        }

        return url
    }

    /// Needs `://`, because `URLComponents` reads the `localhost` of `localhost:8080` as a scheme.
    private static func withScheme(_ address: String) -> String {
        address.prefixMatch(of: /[A-Za-z][A-Za-z0-9+.\-]*:\/\//) == nil ? "http://\(address)" : address
    }

    private func substitutingPathVariables(in path: String) -> String {
        path.split(separator: "/", omittingEmptySubsequences: false)
            .map(substitutingPathVariable)
            .joined(separator: "/")
    }

    private func substitutingPathVariable(in segment: Substring) -> String {
        guard
            segment.hasPrefix(":"),
            let name = segment.dropFirst().removingPercentEncoding,
            let variable = pathParameters.first(where: { $0.isSent && $0.key == name })
        else {
            return String(segment)
        }

        return variable.value.percentEncoded
    }

    private func appendingQueryParameters(to query: String?) -> String? {
        let parameters = queryParameters.filter(\.isSent).map(\.percentEncodedPair)

        guard !parameters.isEmpty else {
            return query
        }

        let existing = query.map { [$0] } ?? []
        return (existing + parameters).filter { !$0.isEmpty }.joined(separator: "&")
    }

}
