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
    let requestDrafts: RequestDrafts

    init(
        seed: Workspace?,
        isSyncedToICloud: Bool = false,
        restoresTabs: Bool = false,
        tabDefaults: UserDefaults = .standard
    ) throws {
        let dataModel = try DataModel.inMemory(seed: seed)
        self.dataModel = dataModel
        self.requestDrafts = RequestDrafts(writer: dataModel.writer)
        self.isSyncedToICloud = isSyncedToICloud
        self.activeEnvironment = ActiveEnvironment(inMemory: seed?.activeEnvironmentID)
        self.requestTabStore = RequestTabStore(defaults: tabDefaults, key: "SeededRequestTabs")
        if !restoresTabs {
            requestTabStore.clear()
        }
    }

}
