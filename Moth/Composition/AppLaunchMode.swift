//  AppLaunchMode.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation

enum AppLaunchMode: Equatable {
    case live
    case uiTesting
    case demo
    case testHost

    init(
        arguments: [String],
        defaults: UserDefaults,
        environment: [String: String]
    ) throws(LaunchConfigurationError) {
        let launchArguments = Array(arguments.dropFirst())
        let isUITesting = try Self.selects("-UITesting", in: launchArguments)
        let isDemo = try Self.selects("-DemoMode", in: launchArguments)

        if isUITesting, isDemo {
            throw .conflictingModes
        }

        if try Self.isTestHost(environment) {
            self = .testHost
        } else if isUITesting {
            self = .uiTesting
        } else if isDemo {
            self = .demo
        } else {
            self = try Self.storesDemoMode(defaults) ? .demo : .live
        }
    }

    static func initialisesCloudKitSchema(arguments: [String]) throws(LaunchConfigurationError) -> Bool {
        try selects("-InitializeCloudKitSchema", in: Array(arguments.dropFirst()))
    }

    private static func isTestHost(_ environment: [String: String]) throws(LaunchConfigurationError) -> Bool {
        if let value = environment["MOTH_TEST_HOST"] {
            guard value == "1" else {
                throw LaunchConfigurationError.invalidEnvironment(key: "MOTH_TEST_HOST", value: value)
            }
            return true
        }
        // Presence is the signal: Xcode 27.2 sets this variable empty in a hosted run.
        return environment["XCTestConfigurationFilePath"] != nil
    }

    private static func storesDemoMode(_ defaults: UserDefaults) throws(LaunchConfigurationError) -> Bool {
        guard let stored = defaults.object(forKey: "DemoMode") else {
            return false
        }

        let value = String(describing: stored)
        switch value.lowercased() {
        case "1", "yes", "true": return true
        case "0", "no", "false": return false
        default: throw .invalidDefault(key: "DemoMode", value: value)
        }
    }

    private static func selects(_ flag: String, in arguments: [String]) throws(LaunchConfigurationError) -> Bool {
        var isSelected = false
        for index in arguments.indices where arguments[index] == flag {
            let valueIndex = index + 1
            guard arguments.indices.contains(valueIndex), !arguments[valueIndex].hasPrefix("-") else {
                throw LaunchConfigurationError.missingValue(flag: flag)
            }
            guard arguments[valueIndex] == "1" else {
                throw LaunchConfigurationError.invalidValue(flag: flag, value: arguments[valueIndex])
            }
            isSelected = true
        }
        return isSelected
    }

}
