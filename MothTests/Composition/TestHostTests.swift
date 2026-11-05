//  TestHostTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import AppKit
@testable import Moth
import Testing

@MainActor
struct TestHostTests {

    @Test("The unit test plan selects the test host")
    func planSetsTestHostVariable() {
        #expect(ProcessInfo.processInfo.environment["MOTH_TEST_HOST"] == "1")
    }

    @Test("The process hosting these tests resolved to the test host")
    func processResolvedToTestHost() {
        #expect(DependencyProvider.current.launchMode == .testHost)
    }

    @Test("The test host's graph is a seeded one")
    func hostGraphIsSeeded() {
        #expect(DependencyProvider.current.dependencies is SeededAppDependencies)
    }

    @Test("The process keeps one graph across reads of the current provider")
    func currentProviderKeepsItsGraph() {
        #expect(DependencyProvider.current.dependencies === DependencyProvider.current.dependencies)
    }

    @Test("The test host opens no windows")
    func hostOpensNoWindows() {
        #expect(NSApplication.shared.windows.isEmpty)
    }

}
