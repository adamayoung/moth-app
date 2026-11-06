//  ActiveEnvironmentTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import Testing

@MainActor
struct ActiveEnvironmentTests {

    private let suiteName = "ActiveEnvironmentTests.\(UUID().uuidString)"
    private let staging = UUID()
    private let production = UUID()

    private var defaults: UserDefaults {
        get throws {
            try #require(UserDefaults(suiteName: suiteName))
        }
    }

    @Test("A Mac that has chosen nothing has no active environment")
    func startsWithNone() throws {
        #expect(try ActiveEnvironment(defaults: defaults).id == nil)
    }

    @Test("The choice round-trips through this Mac's defaults")
    func roundTrips() throws {
        try ActiveEnvironment(defaults: defaults).select(staging)

        #expect(try ActiveEnvironment(defaults: defaults).id == staging)
    }

    @Test("Choosing No Environment round-trips too")
    func noEnvironmentRoundTrips() throws {
        let active = try ActiveEnvironment(defaults: defaults)
        active.select(staging)

        active.select(nil)

        #expect(try ActiveEnvironment(defaults: defaults).id == nil)
    }

    @Test("Deleting the active environment clears it, here and in defaults")
    func deleteClears() throws {
        let active = try ActiveEnvironment(defaults: defaults)
        active.select(staging)
        active.environmentsDidChange([staging, production])

        active.environmentsDidChange([production])

        #expect(active.id == nil)
        #expect(try ActiveEnvironment(defaults: defaults).id == nil)
    }

    @Test("Deleting another environment leaves the active one")
    func otherDeleteKeeps() throws {
        let active = try ActiveEnvironment(defaults: defaults)
        active.select(staging)
        active.environmentsDidChange([staging, production])

        active.environmentsDidChange([staging])

        #expect(active.id == staging)
    }

    @Test("A launch's first list keeps a choice it does not hold, because that row may not have synced yet")
    func firstListKeepsTheChoice() throws {
        let active = try ActiveEnvironment(defaults: defaults)
        active.select(staging)

        active.environmentsDidChange([production])

        #expect(active.id == staging)
    }

    @Test("An in-memory choice starts from its seed and clears the same way")
    func inMemoryChoice() {
        let active = ActiveEnvironment(inMemory: staging)
        active.environmentsDidChange([staging])

        active.environmentsDidChange([])

        #expect(active.id == nil)
    }

}
