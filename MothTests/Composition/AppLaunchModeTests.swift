//  AppLaunchModeTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import Testing

@MainActor
struct AppLaunchModeTests {

    @Test("A launch with no arguments is live")
    func noArgumentsIsLive() throws {
        let mode = try AppLaunchMode(arguments: ["Moth"], defaults: emptyDefaults(), environment: [:])

        #expect(mode == .live)
    }

    @Test(
        "A launch argument pair selects its mode",
        arguments: [
            (["Moth", "-UITesting", "1"], AppLaunchMode.uiTesting),
            (["Moth", "-DemoMode", "1"], AppLaunchMode.demo),
            (["Moth", "-ApplePersistenceIgnoreState", "YES", "-UITesting", "1"], AppLaunchMode.uiTesting)
        ]
    )
    func argumentPairSelectsMode(arguments: [String], expected: AppLaunchMode) throws {
        let mode = try AppLaunchMode(arguments: arguments, defaults: emptyDefaults(), environment: [:])

        #expect(mode == expected)
    }

    @Test("Arguments the system adds for itself are ignored")
    func foreignArgumentsAreIgnored() throws {
        let arguments = ["Moth", "-NSDocumentRevisionsDebugMode", "YES", "-ApplePersistenceIgnoreState", "YES"]

        let mode = try AppLaunchMode(arguments: arguments, defaults: emptyDefaults(), environment: [:])

        #expect(mode == .live)
    }

    @Test(
        "A launch flag with no value stops the launch",
        arguments: [
            (["Moth", "-UITesting"], "-UITesting"),
            (["Moth", "-UITesting", "-ApplePersistenceIgnoreState", "YES"], "-UITesting"),
            (["Moth", "-DemoMode"], "-DemoMode"),
            (["Moth", "-DemoMode", "-UITesting", "1"], "-DemoMode")
        ]
    )
    func bareFlagStopsLaunch(arguments: [String], flag: String) {
        #expect(throws: LaunchConfigurationError.missingValue(flag: flag)) {
            try AppLaunchMode(arguments: arguments, defaults: emptyDefaults(), environment: [:])
        }
    }

    @Test(
        "A launch flag with any value but 1 stops the launch",
        arguments: [
            ("-UITesting", "0"),
            ("-UITesting", "yes"),
            ("-DemoMode", "2")
        ]
    )
    func flagValueOtherThanOneStopsLaunch(flag: String, value: String) {
        #expect(throws: LaunchConfigurationError.invalidValue(flag: flag, value: value)) {
            try AppLaunchMode(arguments: ["Moth", flag, value], defaults: emptyDefaults(), environment: [:])
        }
    }

    @Test("UI testing and demo together stop the launch")
    func conflictingFlagsStopLaunch() {
        #expect(throws: LaunchConfigurationError.conflictingModes) {
            try AppLaunchMode(
                arguments: ["Moth", "-UITesting", "1", "-DemoMode", "1"],
                defaults: emptyDefaults(),
                environment: [:]
            )
        }
    }

    @Test(
        "The test host is selected by the test plan's variable or by XCTest's",
        arguments: [
            ["MOTH_TEST_HOST": "1"],
            ["XCTestConfigurationFilePath": "/tmp/Moth.xctestconfiguration"],
            ["XCTestConfigurationFilePath": ""]
        ]
    )
    func environmentSelectsTestHost(environment: [String: String]) throws {
        let mode = try AppLaunchMode(arguments: ["Moth"], defaults: emptyDefaults(), environment: environment)

        #expect(mode == .testHost)
    }

    @Test("The test host beats UI testing, demo and a stored demo default")
    func testHostBeatsOtherModes() throws {
        let defaults = emptyDefaults()
        defaults.set(true, forKey: "DemoMode")

        let mode = try AppLaunchMode(
            arguments: ["Moth", "-UITesting", "1"],
            defaults: defaults,
            environment: ["MOTH_TEST_HOST": "1"]
        )

        #expect(mode == .testHost)
    }

    @Test("An invalid argument stops the launch even in a test host")
    func invalidArgumentStopsTestHostLaunch() {
        #expect(throws: LaunchConfigurationError.missingValue(flag: "-UITesting")) {
            try AppLaunchMode(
                arguments: ["Moth", "-UITesting"],
                defaults: emptyDefaults(),
                environment: ["MOTH_TEST_HOST": "1"]
            )
        }
    }

    @Test("Any value but 1 for the test host variable stops the launch", arguments: ["0", "true", ""])
    func testHostVariableOtherThanOneStopsLaunch(value: String) {
        let expected = LaunchConfigurationError.invalidEnvironment(key: "MOTH_TEST_HOST", value: value)

        #expect(throws: expected) {
            try AppLaunchMode(arguments: ["Moth"], defaults: emptyDefaults(), environment: ["MOTH_TEST_HOST": value])
        }
    }

    @Test("A stored demo default selects demo", arguments: StoredDemoValue.allCases)
    func storedDemoDefaultSelectsDemo(stored: StoredDemoValue) throws {
        let defaults = emptyDefaults()
        defaults.set(stored.value, forKey: "DemoMode")

        let mode = try AppLaunchMode(arguments: ["Moth"], defaults: defaults, environment: [:])

        #expect(mode == .demo)
    }

    @Test("A stored demo default of false is live")
    func storedFalseDemoDefaultIsLive() throws {
        let defaults = emptyDefaults()
        defaults.set(false, forKey: "DemoMode")

        let mode = try AppLaunchMode(arguments: ["Moth"], defaults: defaults, environment: [:])

        #expect(mode == .live)
    }

    @Test("A stored demo default that is not a boolean stops the launch")
    func storedNonBooleanDemoDefaultStopsLaunch() {
        let defaults = emptyDefaults()
        defaults.set("sometimes", forKey: "DemoMode")

        #expect(throws: LaunchConfigurationError.invalidDefault(key: "DemoMode", value: "sometimes")) {
            try AppLaunchMode(arguments: ["Moth"], defaults: defaults, environment: [:])
        }
    }

    @Test("A launch argument beats a stored demo default")
    func uiTestingArgumentBeatsStoredDemoDefault() throws {
        let defaults = emptyDefaults()
        defaults.set(true, forKey: "DemoMode")

        let mode = try AppLaunchMode(arguments: ["Moth", "-UITesting", "1"], defaults: defaults, environment: [:])

        #expect(mode == .uiTesting)
    }

    @Test(
        "Each launch error's message names what to change",
        arguments: [
            (LaunchConfigurationError.missingValue(flag: "-UITesting"), "-UITesting 1"),
            (LaunchConfigurationError.invalidValue(flag: "-DemoMode", value: "2"), "-DemoMode 1"),
            (LaunchConfigurationError.conflictingModes, "-UITesting 1 or -DemoMode 1"),
            (LaunchConfigurationError.invalidEnvironment(key: "MOTH_TEST_HOST", value: "0"), "MOTH_TEST_HOST=1"),
            (LaunchConfigurationError.invalidDefault(key: "DemoMode", value: "sometimes"), "DemoMode")
        ]
    )
    func errorMessageNamesTheFix(error: LaunchConfigurationError, fix: String) {
        #expect(error.message.contains(fix))
    }

    private func emptyDefaults() -> UserDefaults {
        UserDefaults(suiteName: "AppLaunchModeTests.\(UUID().uuidString)") ?? .standard
    }

    enum StoredDemoValue: CaseIterable {
        case boolean
        case number
        case string

        var value: Any {
            switch self {
            case .boolean: true
            case .number: 1
            case .string: "1"
            }
        }
    }

}
