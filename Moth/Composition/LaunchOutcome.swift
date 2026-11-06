//  LaunchOutcome.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

enum LaunchOutcome {
    case ready(DependencyProvider)
    case storeFailure(StoreFailureAlert)
}
