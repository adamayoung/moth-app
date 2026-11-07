//  ResolvedRequest+URL.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

nonisolated struct SendableAddress {

    let url: URL
    let omissions: BuildOmissions

}

nonisolated extension ResolvedRequest {

    private static let sendableSchemes: Set<String> = ["http", "https"]
    private static let sendablePorts = 1 ... 65535

    func sendableAddress() throws -> SendableAddress {
        let address = url.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !address.isEmpty, var components = URLComponents(string: Self.withScheme(address)),
              let scheme = components.scheme?.lowercased(),
              Self.sendableSchemes.contains(scheme),
              components.host?.isEmpty == false,
              components.port.map({ Self.sendablePorts.contains($0) }) ?? true
        else {
            throw RequestBuildError.invalidURL
        }

        var omissions = fillPathVariables(of: &components)
        omissions.leftOut.formUnion(queryParameters.filter { !$0.isSent }.map { .row($0.id) })
        components.percentEncodedQuery = appendingQueryParameters(to: components.percentEncodedQuery)

        guard let url = components.url else {
            throw RequestBuildError.invalidURL
        }

        return SendableAddress(url: url, omissions: omissions)
    }

    /// Only digits make `name:` a port. `URLComponents` reads the `localhost` of `localhost:8080` as a scheme,
    /// and `http://` in front of `mailto:a@b.com` would send a request to `b.com`.
    static func withScheme(_ address: String) -> String {
        address.prefixMatch(of: /[A-Za-z][A-Za-z0-9+.\-]*:(?!\d)/) == nil ? "http://\(address)" : address
    }

    private func fillPathVariables(of components: inout URLComponents) -> BuildOmissions {
        var unusedRows = pathParameters
        var namesWithoutValues: [String] = []

        components.percentEncodedPath = components.percentEncodedPath
            .split(separator: "/", omittingEmptySubsequences: false)
            .map { segment in
                guard let name = segment.pathVariableName else {
                    return String(segment)
                }

                guard let row = pathParameters.row(filling: name) else {
                    if !namesWithoutValues.contains(name) {
                        namesWithoutValues.append(name)
                    }
                    return String(segment)
                }

                unusedRows.removeAll { $0.id == row.id }
                return row.value.percentEncoded
            }
            .joined(separator: "/")

        return BuildOmissions(
            notices: namesWithoutValues.map { .pathVariableWithoutValue(name: $0) },
            leftOut: Set(unusedRows.map { .row($0.id) })
        )
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

nonisolated extension Substring {

    var pathVariableName: String? {
        guard hasPrefix(":"), let name = dropFirst().removingPercentEncoding, !name.isEmpty else {
            return nil
        }
        return name
    }

}
