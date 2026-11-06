//  VariableScope.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated enum VariableScope: Hashable, Sendable {

    case globals
    case environment(UUID)
    case collection(UUID)

}
