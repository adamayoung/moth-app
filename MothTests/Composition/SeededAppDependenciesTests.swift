//  SeededAppDependenciesTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import Testing

@MainActor
final class SeededAppDependenciesTests {

    private let suiteName = "SeededAppDependenciesTests.\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() throws {
        self.defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    isolated deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func saveATab() throws -> RequestTabs {
        var tabs = RequestTabs()
        tabs.open(UUID())
        try SeededAppDependencies(seed: nil, tabDefaults: defaults).requestTabStore.save(tabs)
        return tabs
    }

    @Test("A seeded launch starts with no tabs, so one UI test's tabs never reach the next")
    func seededLaunchClearsTabs() throws {
        _ = try saveATab()

        let dependencies = try SeededAppDependencies(seed: nil, tabDefaults: defaults)

        #expect(dependencies.requestTabStore.load() == RequestTabs())
    }

    @Test("A launch that restores tabs keeps what the last launch saved")
    func restoringLaunchKeepsTabs() throws {
        let tabs = try saveATab()

        let dependencies = try SeededAppDependencies(seed: nil, restoresTabs: true, tabDefaults: defaults)

        #expect(dependencies.requestTabStore.load() == tabs)
    }

}
