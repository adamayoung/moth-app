//  AWSSigV4AuthProvider.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated struct AWSSigV4AuthProvider: AuthProvider {

    /// URLSession reserves these and can rewrite them, and a server rejects a signature over a value it never received.
    /// The transport adds the cookie jar's cookies to `Cookie` after signing.
    private static let unsignedHeaders: Set<String> = [
        "authorization", "connection", "content-length", "cookie", "proxy-authenticate", "proxy-authorization",
        "www-authenticate"
    ]

    private let credentials: AWSSigV4Signer.Credentials
    private let sessionToken: String
    private let date: Date

    public init(
        accessKey: String,
        secretKey: String,
        sessionToken: String?,
        region: String,
        service: String,
        date: Date
    ) {
        self.credentials = AWSSigV4Signer.Credentials(
            accessKey: accessKey,
            secretKey: secretKey,
            region: region,
            service: service
        )
        self.sessionToken = sessionToken ?? ""
        self.date = date
    }

    var headersSet: [String] {
        ["Authorization", "X-Amz-Date"]
            + (sessionToken.isEmpty ? [] : ["X-Amz-Security-Token"])
            + (credentials.isS3 ? ["X-Amz-Content-Sha256"] : [])
    }

    public func apply(to request: inout URLRequest) async throws {
        let fields = [credentials.accessKey, credentials.secretKey, credentials.region, credentials.service]

        guard !fields.contains(where: \.isEmpty) else {
            throw RequestBuildError.incompleteAWSSignature
        }
        let headerText = [credentials.accessKey, credentials.region, credentials.service, sessionToken]
        guard headerText.allSatisfy(\.isSendableHeaderValue) else {
            throw RequestBuildError.unsendableAWSSignature
        }

        let payloadHash = AWSSigV4Signer.hash(request.httpBody ?? Data())

        request.setValue(date.formatted(.awsSigV4Timestamp), forHTTPHeaderField: "X-Amz-Date")
        if !sessionToken.isEmpty {
            request.setValue(sessionToken, forHTTPHeaderField: "X-Amz-Security-Token")
        }
        if credentials.isS3 {
            request.setValue(payloadHash, forHTTPHeaderField: "X-Amz-Content-Sha256")
        }

        let signer = signer(of: request, payloadHash: payloadHash)
        request.setValue(signer.authorization, forHTTPHeaderField: "Authorization")
    }

    private func signer(of request: URLRequest, payloadHash: String) -> AWSSigV4Signer {
        let components = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }

        return AWSSigV4Signer(
            method: request.httpMethod ?? "GET",
            path: components?.percentEncodedPath ?? "",
            query: components?.percentEncodedQuery,
            headers: signedHeaders(of: request, at: components),
            payloadHash: payloadHash,
            date: date,
            credentials: credentials
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

    /// In the form URLSession sends: lowercase, and with an international name in Punycode.
    private static func host(of components: URLComponents?) -> String {
        let host = components?.encodedHost?.lowercased() ?? ""

        guard let port = components?.port, port != HTTPDefaultPort.of(scheme: components?.scheme) else {
            return host
        }

        return "\(host):\(port)"
    }

}
