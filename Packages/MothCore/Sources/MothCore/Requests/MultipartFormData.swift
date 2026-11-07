//  MultipartFormData.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

nonisolated struct MultipartFormData {

    let boundary: String
    let fields: [FormDataField]

    var encoded: EncodedBody {
        var body = ""
        let sentFields = fields.filter(\.isSent)
        var omissions = BuildOmissions()
        omissions.leftOut = Set(fields.filter { !$0.isSent }.map { .row($0.id) })

        for field in sentFields {
            switch field.value {
            case .text(let text):
                body += part(for: field, text: text)
            case .file:
                omissions.notices.append(.unsupportedFormDataFile(key: field.key))
                omissions.leftOut.insert(.row(field.id))
            }
        }

        body += "--\(boundary)--\r\n"

        return EncodedBody(
            data: Data(body.utf8),
            contentType: "multipart/form-data; boundary=\(boundary)",
            omissions: omissions,
            needsItsContentType: true,
            isFormWithNoRows: sentFields.isEmpty
        )
    }

    private func part(for field: FormDataField, text: String) -> String {
        var headers = [#"Content-Disposition: form-data; name="\#(field.key.multipartNameEscaped)""#]

        if let contentType = field.contentType, !contentType.isEmpty {
            headers.append("Content-Type: \(contentType.components(separatedBy: .newlines).joined())")
        }

        return "--\(boundary)\r\n\(headers.joined(separator: "\r\n"))\r\n\r\n\(text)\r\n"
    }

}

public nonisolated extension String {

    /// The WHATWG form encoding's escapes. Works on scalars, because `\r\n` is one `Character`.
    var multipartNameEscaped: String {
        unicodeScalars.reduce(into: "") { escaped, scalar in
            switch scalar {
            case "\"": escaped += "%22"
            case "\r": escaped += "%0D"
            case "\n": escaped += "%0A"
            default: escaped.unicodeScalars.append(scalar)
            }
        }
    }

}
