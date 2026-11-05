//  FormDataField.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated struct FormDataField: Identifiable, Sendable, Hashable, Codable {

    public let id: UUID
    public var key: String
    public var value: FormDataValue
    public var contentType: String?
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        key: String,
        value: FormDataValue,
        contentType: String? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.contentType = contentType
        self.isEnabled = isEnabled
    }

}

public nonisolated enum FormDataValue: Sendable, Hashable, Codable {

    case text(String)
    case file(paths: [String])

}
