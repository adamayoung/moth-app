//  AppLaunchModeTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import Testing

@MainActor
final class AppLaunchModeTests {

    private let suiteName = "AppLaunchModeTests.\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() throws {
        self.defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    isolated deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test("A launch with no arguments is live")
    func noArgumentsIsLive() throws {
        let mode = try AppLaunchMode(arguments: ["Moth"], defaults: defaults, environment: [:])

        #expect(mode == .live)
    }

    @Test(
        "A launch argument pair selects its mode",
        arguments: [
            (["Moth", "-UITesting", "1"], AppLaunchMode.uiTesting),
            (["Moth", "-DemoMode", "1"], AppLaunchMode.demo),
            (["Moth", "-ApplePersistenceIgnoreState", "YES", "-UITesting", "1"], AppLaunchMode.uiTesting),
            (["Moth", "-UITesting", "1", "-UITestICloudSync", "1"], AppLaunchMode.uiTestingWithICloudSync),
            (["Moth", "-UITesting", "1", "-UITestStoreFailure", "1"], AppLaunchMode.uiTestingStoreFailure),
            (["Moth", "-UITesting", "1", "-UITestRestoresTabs", "1"], AppLaunchMode.uiTestingRestoringTabs)
        ]
    )
    func argumentPairSelectsMode(arguments: [String], expected: AppLaunchMode) throws {
        let mode = try AppLaunchMode(arguments: arguments, defaults: defaults, environment: [:])

        #expect(mode == expected)
    }

    @Test(
        "A UI test launch pair stops a launch that is not a UI test",
        arguments: ["-UITestICloudSync", "-UITestStoreFailure", "-UITestRestoresTabs"]
    )
    func uiTestPairNeedsUITesting(flag: String) {
        #expect(throws: LaunchConfigurationError.needsUITesting(flag: flag)) {
            try AppLaunchMode(arguments: ["Moth", flag, "1"], defaults: defaults, environment: [:])
        }
    }

    @Test(
        "Two UI test launch pairs together stop the launch",
        arguments: [
            ("-UITestICloudSync", "-UITestStoreFailure"),
            ("-UITestICloudSync", "-UITestRestoresTabs"),
            ("-UITestStoreFailure", "-UITestRestoresTabs")
        ]
    )
    func conflictingUITestPairsStopLaunch(first: String, second: String) {
        let arguments = ["Moth", "-UITesting", "1", first, "1", second, "1"]

        #expect(throws: LaunchConfigurationError.conflictingUITestPairs) {
            try AppLaunchMode(arguments: arguments, defaults: defaults, environment: [:])
        }
    }

    @Test("Arguments the system adds for itself are ignored")
    func foreignArgumentsAreIgnored() throws {
        let arguments = ["Moth", "-NSDocumentRevisionsDebugMode", "YES", "-ApplePersistenceIgnoreState", "YES"]

        let mode = try AppLaunchMode(arguments: arguments, defaults: defaults, environment: [:])

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
            try AppLaunchMode(arguments: arguments, defaults: defaults, environment: [:])
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
            try AppLaunchMode(arguments: ["Moth", flag, value], defaults: defaults, environment: [:])
        }
    }

    @Test("UI testing and demo together stop the launch")
    func conflictingFlagsStopLaunch() {
        #expect(throws: LaunchConfigurationError.conflictingModes) {
            try AppLaunchMode(
                arguments: ["Moth", "-UITesting", "1", "-DemoMode", "1"],
                defaults: defaults,
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
        let mode = try AppLaunchMode(arguments: ["Moth"], defaults: defaults, environment: environment)

        #expect(mode == .testHost)
    }

    @Test("The test host beats UI testing, demo and a stored demo default")
    func hostBeatsOtherModes() throws {
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
                defaults: defaults,
                environment: ["MOTH_TEST_HOST": "1"]
            )
        }
    }

    @Test("Any value but 1 for the test host variable stops the launch", arguments: ["0", "true", ""])
    func hostVariableOtherThanOneStopsLaunch(value: String) {
        let expected = LaunchConfigurationError.invalidEnvironment(key: "MOTH_TEST_HOST", value: value)

        #expect(throws: expected) {
            try AppLaunchMode(arguments: ["Moth"], defaults: defaults, environment: ["MOTH_TEST_HOST": value])
        }
    }

    @Test("A stored demo default selects demo", arguments: StoredDemoValue.allCases)
    func storedDemoDefaultSelectsDemo(stored: StoredDemoValue) throws {
        defaults.set(stored.value, forKey: "DemoMode")

        let mode = try AppLaunchMode(arguments: ["Moth"], defaults: defaults, environment: [:])

        #expect(mode == .demo)
    }

    @Test("A stored demo default of false is live")
    func storedFalseDemoDefaultIsLive() throws {
        defaults.set(false, forKey: "DemoMode")

        let mode = try AppLaunchMode(arguments: ["Moth"], defaults: defaults, environment: [:])

        #expect(mode == .live)
    }

    @Test("A stored demo default that is not a boolean stops the launch")
    func storedNonBooleanDemoDefaultStopsLaunch() {
        defaults.set("sometimes", forKey: "DemoMode")

        #expect(throws: LaunchConfigurationError.invalidDefault(key: "DemoMode", value: "sometimes")) {
            try AppLaunchMode(arguments: ["Moth"], defaults: defaults, environment: [:])
        }
    }

    @Test("A stored demo default of false or no is live", arguments: ["0", "NO", "no", "false"])
    func storedFalseStringDemoDefaultIsLive(value: String) throws {
        defaults.set(value, forKey: "DemoMode")

        let mode = try AppLaunchMode(arguments: ["Moth"], defaults: defaults, environment: [:])

        #expect(mode == .live)
    }

    @Test("A stored demo default of a type UserDefaults can't read as a boolean stops the launch")
    func storedNonScalarDemoDefaultStopsLaunch() {
        defaults.set(["1"], forKey: "DemoMode")

        #expect(throws: LaunchConfigurationError.self) {
            try AppLaunchMode(arguments: ["Moth"], defaults: defaults, environment: [:])
        }
    }

    @Test("UI testing and demo together stop the launch even in a test host")
    func conflictingFlagsStopTestHostLaunch() {
        #expect(throws: LaunchConfigurationError.conflictingModes) {
            try AppLaunchMode(
                arguments: ["Moth", "-UITesting", "1", "-DemoMode", "1"],
                defaults: defaults,
                environment: ["MOTH_TEST_HOST": "1"]
            )
        }
    }

    @Test("A launch argument beats a stored demo default")
    func uiTestingArgumentBeatsStoredDemoDefault() throws {
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
            (LaunchConfigurationError.invalidDefault(key: "DemoMode", value: "sometimes"), "DemoMode"),
            (LaunchConfigurationError.needsUITesting(flag: "-UITestStoreFailure"), "-UITesting 1"),
            (LaunchConfigurationError.conflictingUITestPairs, "-UITestRestoresTabs 1"),
            (LaunchConfigurationError.cloudKitSchemaNeedsContainer, "MOTH_ICLOUD_CONTAINER"),
            (LaunchConfigurationError.storeUnavailable(detail: "disk full"), "disk full")
        ]
    )
    func errorMessageNamesTheFix(error: LaunchConfigurationError, fix: String) {
        #expect(error.message.contains(fix))
    }

    @Test("-InitializeCloudKitSchema 1 asks for the CloudKit schema")
    func schemaFlagIsRead() throws {
        let arguments = ["Moth", "-InitializeCloudKitSchema", "1"]

        #expect(try AppLaunchMode.initialisesCloudKitSchema(arguments: arguments))
    }

    @Test("With no flag, nothing touches the CloudKit schema")
    func noSchemaFlag() throws {
        #expect(try !AppLaunchMode.initialisesCloudKitSchema(arguments: ["Moth"]))
    }

    @Test("A bare schema flag stops the launch")
    func bareSchemaFlagStopsLaunch() {
        #expect(throws: LaunchConfigurationError.missingValue(flag: "-InitializeCloudKitSchema")) {
            try AppLaunchMode.initialisesCloudKitSchema(arguments: ["Moth", "-InitializeCloudKitSchema"])
        }
    }

    @Test("Any schema flag value but 1 stops the launch")
    func schemaFlagValueOtherThanOneStopsLaunch() {
        let expected = LaunchConfigurationError.invalidValue(flag: "-InitializeCloudKitSchema", value: "0")

        #expect(throws: expected) {
            try AppLaunchMode.initialisesCloudKitSchema(arguments: ["Moth", "-InitializeCloudKitSchema", "0"])
        }
    }

    enum StoredDemoValue: CaseIterable {
        case boolean
        case number
        case string
        case yes
        case trueWord

        var value: Any {
            switch self {
            case .boolean: true
            case .number: 1
            case .string: "1"
            case .yes: "YES"
            case .trueWord: "true"
            }
        }
    }

}
