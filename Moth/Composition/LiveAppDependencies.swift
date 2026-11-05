//  LiveAppDependencies.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import MothCore

final class LiveAppDependencies: AppDependencies {

    private static let secretService = "uk.co.adam-young.Moth.secrets"

    let transport: any HTTPTransport = URLSessionHTTPTransport(session: makeSession())
    let secretStore: any SecretStore
    let iCloudContainerIdentifier: String?

    init(infoDictionary: [String: Any], signature: AppSignature) {
        let configuredIdentifier = infoDictionary["MothICloudContainer"] as? String ?? ""
        let identifier = configuredIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        self.iCloudContainerIdentifier = identifier.isEmpty ? nil : identifier
        self.secretStore = Self.makeSecretStore(hasICloudContainer: !identifier.isEmpty, signature: signature)
    }

    /// An ad hoc build is a new app to the Keychain after every rebuild, so reading a saved item would prompt.
    private static func makeSecretStore(hasICloudContainer: Bool, signature: AppSignature) -> any SecretStore {
        guard signature.teamIdentifier != nil else {
            return InMemorySecretStore()
        }
        if hasICloudContainer, let accessGroup = signature.keychainAccessGroup {
            return KeychainSecretStore(service: secretService, mode: .synchronised(accessGroup: accessGroup))
        }
        return KeychainSecretStore(service: secretService, mode: .localOnly)
    }

    /// An API client shows what the server sent, so no cached response, cookie or credential carries between requests.
    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        return URLSession(configuration: configuration)
    }

}
