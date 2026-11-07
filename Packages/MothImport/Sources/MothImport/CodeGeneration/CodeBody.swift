//  CodeBody.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore

nonisolated enum CodeBody {

    case none
    case text(String)
    case file(String)
    case form([CodeFormPart])

    struct Written {

        let content: CodeBody
        let contentType: String?

    }

    var isEmpty: Bool {
        switch self {
        case .none: true
        case .text(let text): text.isEmpty
        case .file: false
        case .form(let parts): parts.isEmpty
        }
    }

}

nonisolated struct CodeFormPart {

    enum Content {

        case text(String)
        case file(String)

    }

    let name: String
    let contentType: String?
    let content: Content

    init(name: String, contentType: String?, content: Content) {
        self.name = name
        self.contentType = contentType.flatMap { type in
            type.isEmpty ? nil : type.components(separatedBy: .newlines).joined()
        }
        self.content = content
    }

}

nonisolated extension CodeBody.Written {

    init(_ body: RequestBody) throws {
        switch body {
        case .none:
            self.init(content: .none, contentType: nil)
        case .raw(let content, let contentType):
            self.init(content: .text(content), contentType: contentType.isEmpty ? nil : contentType)
        case .urlEncoded(let rows):
            let pairs = rows.filter(\.isSent).map { "\($0.key.urlDisplayEncoded)=\($0.value.urlDisplayEncoded)" }
            self.init(
                content: pairs.isEmpty ? .none : .text(pairs.joined(separator: "&")),
                contentType: pairs.isEmpty ? nil : "application/x-www-form-urlencoded"
            )
        case .formData(let fields):
            let parts = fields.filter(\.isSent).flatMap(\.codeParts)
            self.init(content: parts.isEmpty ? .none : .form(parts), contentType: nil)
        case .binary(let filePath):
            self.init(content: .file(filePath ?? "<file>"), contentType: "application/octet-stream")
        case .graphQL(let query, let variables):
            try self.init(content: .text(Self.graphQLJSON(query, variables)), contentType: "application/json")
        }
    }

    /// `variables` stays as written, because a `{{variable}}` left in it makes it no JSON to parse.
    private static func graphQLJSON(_ query: String, _ variables: String) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        let encodedQuery = try String(bytes: encoder.encode(query), encoding: .utf8) ?? ""
        let trimmedVariables = variables.trimmingCharacters(in: .whitespacesAndNewlines)

        return trimmedVariables.isEmpty
            ? #"{"query":\#(encodedQuery)}"#
            : #"{"query":\#(encodedQuery),"variables":\#(trimmedVariables)}"#
    }

}

private nonisolated extension FormDataField {

    var codeParts: [CodeFormPart] {
        switch value {
        case .text(let text):
            [CodeFormPart(name: key, contentType: contentType, content: .text(text))]
        case .file(let paths):
            paths.map { CodeFormPart(name: key, contentType: contentType, content: .file($0)) }
        }
    }

}
