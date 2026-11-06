//  SeededAppDependencies.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import MothCore

final class SeededAppDependencies: AppDependencies {

    let transport: any HTTPTransport = StubHTTPTransport()
    let secretStore: any SecretStore = InMemorySecretStore()
    let dataModel: DataModel
    let iCloudContainerIdentifier: String? = nil
    let isSyncedToICloud: Bool
    let activeEnvironment: ActiveEnvironment
    let requestTabStore: RequestTabStore

    init(
        seed: Workspace?,
        isSyncedToICloud: Bool = false,
        restoresTabs: Bool = false,
        tabDefaults: UserDefaults = .standard
    ) throws {
        self.dataModel = try .inMemory(seed: seed)
        self.isSyncedToICloud = isSyncedToICloud
        self.activeEnvironment = ActiveEnvironment(inMemory: seed?.activeEnvironmentID)
        self.requestTabStore = RequestTabStore(defaults: tabDefaults, key: "SeededRequestTabs")
        if !restoresTabs {
            requestTabStore.clear()
        }
    }

}
