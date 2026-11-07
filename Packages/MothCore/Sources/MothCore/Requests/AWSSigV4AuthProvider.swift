//  AWSSigV4AuthProvider.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated struct AWSSigV4AuthProvider: AuthProvider {

    /// URLSession reserves these and can rewrite them, and a server rejects a signature over a value it never received.
    private static let unsignedHeaders: Set<String> = [
        "authorization", "connection", "content-length", "proxy-authenticate", "proxy-authorization", "www-authenticate"
    ]

    private static let defaultPorts = ["http": 80, "https": 443]

    private let accessKey: String
    private let secretKey: String
    private let sessionToken: String?
    private let region: String
    private let service: String
    private let date: Date

    public init(
        accessKey: String,
        secretKey: String,
        sessionToken: String?,
        region: String,
        service: String,
        date: Date
    ) {
        self.accessKey = accessKey
        self.secretKey = secretKey
        self.sessionToken = sessionToken
        self.region = region
        self.service = service
        self.date = date
    }

    public func apply(to request: inout URLRequest) async throws {
        let token = sessionToken ?? ""

        guard ![accessKey, secretKey, region, service].contains(where: \.isEmpty) else {
            throw RequestBuildError.incompleteAWSSignature
        }
        guard [accessKey, region, service, token].allSatisfy(\.isSendableHeaderValue) else {
            throw RequestBuildError.unsendableAWSSignature
        }

        request.setValue(date.formatted(.awsSigV4Timestamp), forHTTPHeaderField: "X-Amz-Date")
        if !token.isEmpty {
            request.setValue(token, forHTTPHeaderField: "X-Amz-Security-Token")
        }
        if service == AWSSigV4Signer.s3 {
            let payloadHash = AWSSigV4Signer.hash(request.httpBody ?? Data())
            request.setValue(payloadHash, forHTTPHeaderField: "X-Amz-Content-Sha256")
        }

        request.setValue(signer(of: request).authorization, forHTTPHeaderField: "Authorization")
    }

    private func signer(of request: URLRequest) -> AWSSigV4Signer {
        let components = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }

        return AWSSigV4Signer(
            method: request.httpMethod ?? "GET",
            path: components?.percentEncodedPath ?? "",
            query: components?.percentEncodedQuery,
            headers: signedHeaders(of: request, at: components),
            payload: request.httpBody ?? Data(),
            date: date,
            credentials: AWSSigV4Signer.Credentials(
                accessKey: accessKey,
                secretKey: secretKey,
                region: region,
                service: service
            )
        )
    }

    private func signedHeaders(of request: URLRequest, at components: URLComponents?) -> [String: String] {
        var headers = request.allHTTPHeaderFields ?? [:]
        headers = headers.filter { !Self.unsignedHeaders.contains($0.key.lowercased()) }

        if request.value(forHTTPHeaderField: "Host") == nil {
            headers["Host"] = Self.host(of: components)
        }

        return headers
    }

    private static func host(of components: URLComponents?) -> String {
        let host = components?.percentEncodedHost ?? ""

        guard let port = components?.port, port != defaultPorts[components?.scheme?.lowercased() ?? ""] else {
            return host
        }

        return "\(host):\(port)"
    }

}
