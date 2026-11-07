//  PostmanMapper+Auth.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore
import PostmanKit

nonisolated extension PostmanMapper {

    /// What Postman signs with for a blank field. An export leaves a blank `service` out, so the row needs a value.
    private static let postmanDefaultRegion = "us-east-1"
    private static let postmanDefaultService = "execute-api"

    mutating func auth(_ postman: PostmanAuth?, whenUnset unset: Auth) -> Auth {
        guard let postman else {
            return unset
        }

        switch postman.type {
        case .noauth:
            return .none
        case .basic:
            return basic(postman)
        case .bearer:
            return .bearer(BearerAuth(token: secret(postman.text("token"))))
        case .apikey:
            return apiKey(postman)
        case .awsv4:
            return sigV4(postman)
        case .digest:
            return digest(postman)
        case .oauth2:
            return storedButUnsupported(.oauth2, oauth2(postman))
        case .edgegrid:
            return dropped(.edgeGrid)
        case .hawk:
            return dropped(.hawk)
        case .ntlm:
            return dropped(.ntlm)
        case .oauth1:
            return dropped(.oauth1)
        case .unknown(let name):
            return dropped(.other(name))
        }
    }

    private mutating func storedButUnsupported(_ kind: PostmanAuthKind, _ auth: Auth) -> Auth {
        imported.unsupportedAuth[kind, default: 0] += 1
        return auth
    }

    /// `.none` stops the walk up the tree, so a parent's credential can't reach what asked for another scheme.
    private mutating func dropped(_ kind: PostmanAuthKind) -> Auth {
        skipped.auth[kind, default: 0] += 1
        return .none
    }

    private mutating func basic(_ postman: PostmanAuth) -> Auth {
        .basic(BasicAuth(username: postman.text("username") ?? "", password: password(postman.text("password"))))
    }

    private mutating func digest(_ postman: PostmanAuth) -> Auth {
        .digest(DigestAuth(username: postman.text("username") ?? "", password: password(postman.text("password"))))
    }

    private mutating func apiKey(_ postman: PostmanAuth) -> Auth {
        .apiKey(APIKeyAuth(
            name: postman.text("key") ?? "",
            value: secret(postman.text("value")),
            location: postman.text("in") == "query" ? .query : .header
        ))
    }

    private mutating func sigV4(_ postman: PostmanAuth) -> Auth {
        .awsSigV4(AWSSigV4Auth(
            accessKeyID: secret(postman.text("accessKey")),
            secretAccessKey: secret(postman.text("secretKey")),
            sessionToken: optionalSecret(postman.text("sessionToken")),
            region: postman.nonEmptyText("region") ?? Self.postmanDefaultRegion,
            service: postman.nonEmptyText("service") ?? Self.postmanDefaultService
        ))
    }

    private mutating func oauth2(_ postman: PostmanAuth) -> Auth {
        .oauth2(OAuth2Auth(
            grantType: Self.grantType(named: postman.text("grant_type", "grantType")),
            authorizationURL: postman.text("authUrl") ?? "",
            accessTokenURL: postman.text("accessTokenUrl") ?? "",
            callbackURL: postman.text("redirect_uri", "callBackUrl", "redirectUri") ?? "",
            clientID: postman.text("clientId") ?? "",
            clientSecret: optionalSecret(postman.text("clientSecret")),
            scope: postman.text("scope") ?? "",
            username: postman.text("username") ?? "",
            password: optionalSecret(postman.text("password")),
            accessToken: optionalSecret(postman.text("accessToken")),
            refreshToken: optionalSecret(postman.text("refreshToken"))
        ))
    }

    private static func grantType(named name: String?) -> OAuth2GrantType {
        switch name {
        case "authorization_code_with_pkce": .authorizationCodeWithPKCE
        case "implicit": .implicit
        case "password_credentials": .passwordCredentials
        case "client_credentials": .clientCredentials
        default: .authorizationCode
        }
    }

}

private nonisolated extension PostmanAuth {

    /// Takes several keys because the name of an OAuth2 parameter has changed between Postman versions.
    func text(_ keys: String...) -> String? {
        keys.lazy.compactMap { key in
            parameters.first { $0.key == key }?.value?.text
        }.first
    }

    func nonEmptyText(_ key: String) -> String? {
        text(key).flatMap { $0.isEmpty ? nil : $0 }
    }

}
