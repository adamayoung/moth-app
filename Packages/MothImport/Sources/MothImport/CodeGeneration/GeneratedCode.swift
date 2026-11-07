//  GeneratedCode.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

public nonisolated enum CodeLanguage: Sendable, Hashable, CaseIterable {

    case curl
    case swiftURLSession

}

public nonisolated struct GeneratedCode: Sendable, Hashable {

    public let curl: String
    public let swift: String

    public func text(in language: CodeLanguage) -> String {
        switch language {
        case .curl: curl
        case .swiftURLSession: swift
        }
    }

}
