//  LiveAppDependencies.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import MothCore

final class LiveAppDependencies: AppDependencies {

    // Ephemeral, so nothing a request returns is written to disk.
    let transport: any HTTPTransport = URLSessionHTTPTransport(session: URLSession(configuration: .ephemeral))
    let secretStore: any SecretStore = InMemorySecretStore()
    let iCloudContainerIdentifier: String?

    init(infoDictionary: [String: Any]) {
        let configuredIdentifier = infoDictionary["MothICloudContainer"] as? String ?? ""
        let identifier = configuredIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        self.iCloudContainerIdentifier = identifier.isEmpty ? nil : identifier
    }

}
