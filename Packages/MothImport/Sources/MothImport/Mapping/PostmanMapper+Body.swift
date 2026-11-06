//  PostmanMapper+Body.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore
import PostmanKit

nonisolated extension PostmanMapper {

    mutating func body(_ postman: PostmanBody?) -> RequestBody {
        guard let postman else {
            return .none
        }

        switch postman {
        case .empty:
            return .none
        case .raw(let text, let language):
            return .raw(content: text ?? "", contentType: Self.contentType(ofLanguage: language))
        case .urlencoded(let rows):
            return .urlEncoded(keyValues(rows))
        case .formdata(let rows):
            return .formData(formFields(rows))
        case .file(let source, let inlineContent):
            if inlineContent != nil {
                skipped.bodies += 1
            }
            return .binary(filePath: source)
        case .graphql(let query, let variables):
            return .graphQL(query: query ?? "", variables: variables?.text ?? "")
        case .unknown:
            skipped.bodies += 1
            return .none
        }
    }

    /// An empty type adds no header, so with no language, or an unknown one, a request's own header carries it.
    private static func contentType(ofLanguage language: String?) -> String {
        switch language {
        case "json": "application/json"
        case "xml": "application/xml"
        case "html": "text/html"
        case "javascript": "application/javascript"
        case "text": "text/plain"
        default: ""
        }
    }

    private mutating func formFields(_ rows: [PostmanFormDataRow]) -> [FormDataField] {
        var fields: [FormDataField] = []
        for row in rows {
            countDescription(row.description)
            fields.append(FormDataField(
                key: row.key ?? "",
                value: row.type == "file" ? .file(paths: row.sources) : .text(row.value ?? ""),
                contentType: row.contentType,
                isEnabled: row.isEnabled
            ))
        }
        return fields
    }

}
