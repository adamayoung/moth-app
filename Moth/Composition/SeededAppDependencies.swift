//  SeededAppDependencies.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import HTTPKit
import MothCore

final class SeededAppDependencies: AppDependencies {

    let transport: any HTTPTransport = StubHTTPTransport()
    let secretStore: any SecretStore = InMemorySecretStore()
    let iCloudContainerIdentifier: String? = nil

}
