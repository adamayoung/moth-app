//  LaunchConfigurationError.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

enum LaunchConfigurationError: Error, Equatable {
    case missingValue(flag: String)
    case invalidValue(flag: String, value: String)
    case conflictingModes
    case invalidEnvironment(key: String, value: String)
    case invalidDefault(key: String, value: String)
    case cloudKitSchemaNeedsContainer
    case storeUnavailable(detail: String)

    var message: String {
        switch self {
        case .missingValue(let flag):
            "\(flag) needs a value. Pass \(flag) 1."
        case .invalidValue(let flag, let value):
            "\(flag) doesn’t accept “\(value)”. Pass \(flag) 1."
        case .conflictingModes:
            "Moth starts in one mode. Pass -UITesting 1 or -DemoMode 1, not both."
        case .invalidEnvironment(let key, let value):
            "\(key) doesn’t accept “\(value)”. Set \(key)=1 or unset it."
        case .invalidDefault(let key, let value):
            "The \(key) default doesn’t accept “\(value)”. Set it to a boolean or delete it."
        case .cloudKitSchemaNeedsContainer:
            "-InitializeCloudKitSchema needs an entitled iCloud container. "
                + "Set DEVELOPMENT_TEAM and MOTH_ICLOUD_CONTAINER in Local.xcconfig."
        case .storeUnavailable(let detail):
            "The data store didn’t open: \(detail)"
        }
    }

}
