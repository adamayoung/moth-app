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
    let cookieJars: CookieJars
    let dataModel: DataModel
    let iCloudContainerIdentifier: String? = nil
    let isSyncedToICloud: Bool
    let activeEnvironment: ActiveEnvironment
    let requestTabStore: RequestTabStore
    let requestDrafts: RequestDrafts
    let importFileSource: ImportFileSource
    let clipboard: Clipboard

    init(
        seed: Workspace?,
        isSyncedToICloud: Bool = false,
        restoresTabs: Bool = false,
        tabDefaults: UserDefaults = .standard,
        importFile: Data? = nil,
        clipboard: Clipboard = .uiTest
    ) throws {
        let dataModel = try DataModel.inMemory(seed: seed)
        self.dataModel = dataModel
        self.cookieJars = CookieJars(
            writer: dataModel.writer,
            secretStore: InMemorySecretStore(),
            seed: seed.map { [$0.id: SeedData.cookies] } ?? [:]
        )
        self.requestDrafts = RequestDrafts(writer: dataModel.writer, secretStore: secretStore)
        self.importFileSource = importFile.map(ImportFileSource.uiTest) ?? .panel
        self.clipboard = clipboard
        self.isSyncedToICloud = isSyncedToICloud
        self.activeEnvironment = ActiveEnvironment(inMemory: seed?.activeEnvironmentID)
        self.requestTabStore = RequestTabStore(defaults: tabDefaults, key: "SeededRequestTabs")
        if !restoresTabs {
            requestTabStore.clear()
        }
    }

}
