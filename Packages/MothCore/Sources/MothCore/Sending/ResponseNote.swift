//  ResponseNote.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

public nonisolated enum ResponseNote: Sendable, Hashable {

    case undefinedVariable(String)
    case undefinedVariables(Int)
    case unsupportedAuth
    case unsupportedBody

    public static func notes(unresolved: [UnresolvedVariable], notices: [RequestBuildNotice]) -> [ResponseNote] {
        var notes: [ResponseNote] = []

        if unresolved.count == 1, let variable = unresolved.first {
            notes.append(.undefinedVariable(variable.name))
        } else if unresolved.count > 1 {
            notes.append(.undefinedVariables(unresolved.count))
        }
        if notices.contains(where: \.isUnsupportedAuth) {
            notes.append(.unsupportedAuth)
        }
        if notices.contains(where: \.isUnsupportedBody) {
            notes.append(.unsupportedBody)
        }

        return notes
    }

}

private nonisolated extension RequestBuildNotice {

    var isUnsupportedAuth: Bool {
        if case .unsupportedAuth = self {
            return true
        }
        return false
    }

    var isUnsupportedBody: Bool {
        if case .unsupportedBody = self {
            return true
        }
        return false
    }

}
