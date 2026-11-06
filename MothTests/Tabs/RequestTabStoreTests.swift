//  RequestTabStoreTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import Testing

@MainActor
final class RequestTabStoreTests {

    private let suiteName = "RequestTabStoreTests.\(UUID().uuidString)"
    private let key = "Tabs"
    private let defaults: UserDefaults
    private let store: RequestTabStore

    init() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        self.defaults = defaults
        self.store = RequestTabStore(defaults: defaults, key: key)
    }

    isolated deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test("Tab state round-trips through its store")
    func roundTrips() {
        let first = UUID()
        var tabs = RequestTabs()
        tabs.open(first)
        tabs.open(UUID())
        tabs.select(first)

        store.save(tabs)

        #expect(store.load() == tabs)
    }

    @Test("A store with nothing saved loads no tabs")
    func emptyStoreLoadsNoTabs() {
        #expect(store.load() == RequestTabs())
    }

    @Test("A store with unreadable data loads no tabs")
    func unreadableDataLoadsNoTabs() {
        defaults.set(Data("not tabs".utf8), forKey: key)

        #expect(store.load() == RequestTabs())
    }

    @Test("Clearing a store forgets its tabs")
    func clearForgetsTabs() {
        var tabs = RequestTabs()
        tabs.open(UUID())
        store.save(tabs)

        store.clear()

        #expect(store.load() == RequestTabs())
    }

}
