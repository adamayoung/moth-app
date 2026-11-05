//  LiveAppDependencies.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import MothCore

final class LiveAppDependencies: AppDependencies {

    let transport: any HTTPTransport = URLSessionHTTPTransport(session: makeSession())
    let secretStore: any SecretStore = InMemorySecretStore()
    let iCloudContainerIdentifier: String?

    init(infoDictionary: [String: Any]) {
        let configuredIdentifier = infoDictionary["MothICloudContainer"] as? String ?? ""
        let identifier = configuredIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        self.iCloudContainerIdentifier = identifier.isEmpty ? nil : identifier
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
