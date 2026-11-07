//  ResponseNote.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

public nonisolated enum ResponseNote: Sendable, Hashable {

    case undefinedVariable(String)
    case secretWithNoValue(String)
    case variableCycle(String)
    case variableNotExpanded(String)
    case undefinedVariables(Int)
    case unresolvedVariables(Int)
    case unsendableHeader(String)
    case unsendableHeaders(Int)
    case missingCredential
    case unsupportedAuth
    case bodyNotSent(HTTPMethod)
    case unsupportedBody
    case unsupportedFile(String)
    case unsupportedFiles(Int)
    case formDataBoundaryReplaced

    public static func notes(
        unresolved: [UnresolvedVariable],
        notices: [RequestBuildNotice],
        unresolvedCredentials: [SecretReference] = []
    ) -> [ResponseNote] {
        let notes: [ResponseNote?] = [
            variableNote(for: unresolved),
            headerNote(for: notices),
            authNote(for: notices, unresolvedCredentials: unresolvedCredentials),
            notices.lazy.compactMap(\.methodThatLeftBodyOff).first.map(ResponseNote.bodyNotSent),
            notices.contains(where: \.isUnsupportedBody) ? .unsupportedBody : nil,
            fileNote(for: notices),
            notices.contains(.formDataBoundaryNotDeclared) ? .formDataBoundaryReplaced : nil
        ]

        return notes.compactMap(\.self)
    }

    private static func variableNote(for unresolved: [UnresolvedVariable]) -> ResponseNote? {
        if unresolved.count == 1, let variable = unresolved.first {
            return note(for: variable)
        }
        if unresolved.isEmpty {
            return nil
        }
        return unresolved.allSatisfy { $0.reason == .undefined }
            ? .undefinedVariables(unresolved.count)
            : .unresolvedVariables(unresolved.count)
    }

    private static func authNote(
        for notices: [RequestBuildNotice],
        unresolvedCredentials: [SecretReference]
    ) -> ResponseNote? {
        if notices.contains(where: \.isUnsupportedAuth) {
            return .unsupportedAuth
        }
        return unresolvedCredentials.isEmpty ? nil : .missingCredential
    }

    private static func headerNote(for notices: [RequestBuildNotice]) -> ResponseNote? {
        namedOrCounted(
            Set(notices.compactMap(\.unsendableHeaderName)),
            named: ResponseNote.unsendableHeader,
            counted: ResponseNote.unsendableHeaders
        )
    }

    private static func fileNote(for notices: [RequestBuildNotice]) -> ResponseNote? {
        namedOrCounted(
            Set(notices.compactMap(\.unsupportedFileKey)),
            named: ResponseNote.unsupportedFile,
            counted: ResponseNote.unsupportedFiles
        )
    }

    private static func namedOrCounted(
        _ names: Set<String>,
        named: (String) -> ResponseNote,
        counted: (Int) -> ResponseNote
    ) -> ResponseNote? {
        names.count > 1 ? counted(names.count) : names.first.map(named)
    }

    private static func note(for variable: UnresolvedVariable) -> ResponseNote {
        switch variable.reason {
        case .undefined: .undefinedVariable(variable.name)
        case .missingSecret: .secretWithNoValue(variable.name)
        case .cycle: .variableCycle(variable.name)
        case .tooDeep, .tooLarge: .variableNotExpanded(variable.name)
        }
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

    var methodThatLeftBodyOff: HTTPMethod? {
        if case .bodyNotSent(let method) = self {
            return method
        }
        return nil
    }

    var unsendableHeaderName: String? {
        if case .unsendableHeader(let name) = self {
            return name
        }
        return nil
    }

    var unsupportedFileKey: String? {
        if case .unsupportedFormDataFile(let key) = self {
            return key
        }
        return nil
    }

}
