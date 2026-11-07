//  OAuth2TokenRequest.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit

/// The client credentials grant, RFC 6749 section 4.4, with the client authenticated by a Basic header.
nonisolated struct OAuth2TokenRequest: Sendable {

    let tokenURL: String
    let clientID: String
    let clientSecret: String
    let scope: String

    var fingerprint: String {
        [tokenURL, clientID, scope].joined(separator: "\n")
    }

    func urlRequest(timeout: Duration) throws -> URLRequest {
        guard
            let url = URL(string: tokenURL),
            let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
            url.host() != nil
        else {
            throw OAuth2TokenError.invalidTokenURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout / .seconds(1)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Basic \(basicCredentials)", forHTTPHeaderField: "Authorization")
        request.httpBody = Data(form.utf8)
        return request
    }

    /// Section 2.3.1: the identifier and secret are form-encoded before Basic joins them, so a colon survives.
    private var basicCredentials: String {
        Data("\(clientID.percentEncoded):\(clientSecret.percentEncoded)".utf8).base64EncodedString()
    }

    private var form: String {
        let scopeField = scope.isEmpty ? [] : ["scope=\(scope.percentEncoded)"]
        return (["grant_type=client_credentials"] + scopeField).joined(separator: "&")
    }

    static func token(from response: HTTPResponse, receivedAt: Date) throws -> OAuth2Token {
        let answer = try? JSONDecoder().decode(TokenAnswer.self, from: response.body)
        guard (200 ..< 300).contains(response.status) else {
            throw OAuth2TokenError.refused(
                status: response.status,
                error: answer?.error,
                description: answer?.errorDescription
            )
        }
        guard let value = answer?.accessToken, !value.isEmpty else {
            throw OAuth2TokenError.noAccessToken
        }
        return OAuth2Token(value: value, expiresAt: answer?.expiresIn.map { receivedAt.addingTimeInterval($0) })
    }

}

private nonisolated struct TokenAnswer: Decodable {

    enum CodingKeys: String, CodingKey {

        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case error
        case errorDescription = "error_description"

    }

    var accessToken: String?
    var expiresIn: TimeInterval?
    var error: String?
    var errorDescription: String?

    /// Some servers send `expires_in` as a string, though RFC 6749 says a number.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.accessToken = try? container.decodeIfPresent(String.self, forKey: .accessToken)
        self.expiresIn = (try? container.decodeIfPresent(TimeInterval.self, forKey: .expiresIn))
            ?? (try? container.decodeIfPresent(String.self, forKey: .expiresIn))
            .flatMap { $0.flatMap(TimeInterval.init) }
        self.error = try? container.decodeIfPresent(String.self, forKey: .error)
        self.errorDescription = try? container.decodeIfPresent(String.self, forKey: .errorDescription)
    }

}

public nonisolated enum OAuth2TokenError: LocalizedError, Hashable {

    case invalidTokenURL
    case noAccessToken
    case unsupportedGrant
    case refused(status: Int, error: String?, description: String?)

    public var errorDescription: String? {
        switch self {
        case .invalidTokenURL:
            String(localized: "OAUTH2_TOKEN_ERROR_INVALID_URL", bundle: .module)
        case .noAccessToken:
            String(localized: "OAUTH2_TOKEN_ERROR_NO_TOKEN", bundle: .module)
        case .unsupportedGrant:
            String(localized: "OAUTH2_TOKEN_ERROR_UNSUPPORTED_GRANT", bundle: .module)
        case .refused(_, let error?, let description?):
            "\(error): \(description)"
        case .refused(_, let error?, nil):
            error
        case .refused(let status, nil, _):
            String(localized: "OAUTH2_TOKEN_ERROR_STATUS_\(status)", bundle: .module)
        }
    }

}
