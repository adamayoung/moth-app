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

    public init(curl: String, swift: String) {
        self.curl = curl
        self.swift = swift
    }

    public func text(in language: CodeLanguage) -> String {
        switch language {
        case .curl: curl
        case .swiftURLSession: swift
        }
    }

}
