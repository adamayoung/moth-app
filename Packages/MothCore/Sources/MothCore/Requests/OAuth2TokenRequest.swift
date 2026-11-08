//  OAuth2TokenRequest.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit

/// A token request to RFC 6749's token endpoint: the client credentials grant (section 4.4), an authorization code
/// exchange (section 4.1.3, with RFC 7636's verifier) or a refresh (section 6).
nonisolated struct OAuth2TokenRequest: Sendable {

    enum Grant: Sendable, Hashable {

        case clientCredentials
        case authorizationCode(code: String, redirectURI: String, verifier: String)
        case refreshToken(String)

    }

    let tokenURL: String
    let clientID: String
    let clientSecret: String
    let scope: String
    var grant = Grant.clientCredentials

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
        if sendsBasicCredentials {
            request.setValue("Basic \(basicCredentials)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = Data(form.utf8)
        return request
    }

    /// A client with no secret is a public client, which names itself in the form (section 4.1.3). Client
    /// Credentials always authenticates, because RFC 6749 lets that grant be used only by a confidential client.
    private var sendsBasicCredentials: Bool {
        grant == .clientCredentials || !clientSecret.isEmpty
    }

    /// Section 2.3.1: the identifier and secret are form-encoded before Basic joins them, so a colon survives.
    private var basicCredentials: String {
        Data("\(clientID.percentEncoded):\(clientSecret.percentEncoded)".utf8).base64EncodedString()
    }

    private var form: String {
        let clientField = sendsBasicCredentials ? [] : [("client_id", clientID)]
        return (grantFields + clientField)
            .map { "\($0.percentEncoded)=\($1.percentEncoded)" }
            .joined(separator: "&")
    }

    private var grantFields: [(String, String)] {
        switch grant {
        case .clientCredentials:
            [("grant_type", "client_credentials")] + (scope.isEmpty ? [] : [("scope", scope)])
        case .authorizationCode(let code, let redirectURI, let verifier):
            [
                ("grant_type", "authorization_code"),
                ("code", code),
                ("redirect_uri", redirectURI),
                ("code_verifier", verifier)
            ]
        case .refreshToken(let refreshToken):
            [("grant_type", "refresh_token"), ("refresh_token", refreshToken)]
        }
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
        return OAuth2Token(
            value: value,
            expiresAt: answer?.expiresIn.map { receivedAt.addingTimeInterval($0) },
            refreshToken: answer?.refreshToken.flatMap { $0.isEmpty ? nil : $0 }
        )
    }

}

private nonisolated struct TokenAnswer: Decodable {

    enum CodingKeys: String, CodingKey {

        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case error
        case errorDescription = "error_description"

    }

    var accessToken: String?
    var refreshToken: String?
    var expiresIn: TimeInterval?
    var error: String?
    var errorDescription: String?

    /// Some servers send `expires_in` as a string, though RFC 6749 says a number.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.accessToken = try? container.decodeIfPresent(String.self, forKey: .accessToken)
        self.refreshToken = try? container.decodeIfPresent(String.self, forKey: .refreshToken)
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
    case invalidAuthorizationURL
    case callbackNotCustomScheme
    case stateMismatch
    case noAuthorizationCode
    case signInRefused(error: String, description: String?)
    case tokenExpired
    case signInNeeded
    case issuedForOtherFields

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
        case .invalidAuthorizationURL:
            String(localized: "OAUTH2_SIGN_IN_ERROR_INVALID_URL", bundle: .module)
        case .callbackNotCustomScheme:
            String(localized: "OAUTH2_SIGN_IN_ERROR_CALLBACK_SCHEME", bundle: .module)
        case .stateMismatch:
            String(localized: "OAUTH2_SIGN_IN_ERROR_STATE", bundle: .module)
        case .noAuthorizationCode:
            String(localized: "OAUTH2_SIGN_IN_ERROR_NO_CODE", bundle: .module)
        case .signInRefused(let error, let description?):
            "\(error): \(description)"
        case .signInRefused(let error, nil):
            error
        case .tokenExpired:
            String(localized: "OAUTH2_TOKEN_ERROR_EXPIRED", bundle: .module)
        case .signInNeeded:
            String(localized: "OAUTH2_TOKEN_ERROR_SIGN_IN_NEEDED", bundle: .module)
        case .issuedForOtherFields:
            String(localized: "OAUTH2_TOKEN_ERROR_OTHER_FIELDS", bundle: .module)
        }
    }

}
