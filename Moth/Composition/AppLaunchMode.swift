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

    init(arguments: [String], defaults: UserDefaults, environment: [String: String]) throws {
        let launchArguments = Array(arguments.dropFirst())
        let isUITesting = try Self.selects("-UITesting", in: launchArguments)
        let isDemo = try Self.selects("-DemoMode", in: launchArguments)

        if try Self.isTestHost(environment) {
            self = .testHost
            return
        }

        switch (isUITesting, isDemo) {
        case (true, true): throw LaunchConfigurationError.conflictingModes
        case (true, false): self = .uiTesting
        case (false, true): self = .demo
        case (false, false): self = try Self.storesDemoMode(defaults) ? .demo : .live
        }
    }

    private static func isTestHost(_ environment: [String: String]) throws -> Bool {
        if let value = environment["MOTH_TEST_HOST"] {
            guard value == "1" else {
                throw LaunchConfigurationError.invalidEnvironment(key: "MOTH_TEST_HOST", value: value)
            }
            return true
        }
        return environment["XCTestConfigurationFilePath"]?.isEmpty == false
    }

    private static func storesDemoMode(_ defaults: UserDefaults) throws -> Bool {
        switch defaults.string(forKey: "DemoMode") {
        case nil, "0": false
        case "1": true
        case let value?: throw LaunchConfigurationError.invalidDefault(key: "DemoMode", value: value)
        }
    }

    private static func selects(_ flag: String, in arguments: [String]) throws -> Bool {
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
