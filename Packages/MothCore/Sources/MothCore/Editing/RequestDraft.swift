//  RequestDraft.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

/// What the editor shows, which can run ahead of the store until Save. `url` holds the query that the store keeps in
/// rows, because `RequestBuilder` appends rows to a template's own query and would send it twice.
public nonisolated struct RequestDraft: Sendable {

    public var method: HTTPMethod
    public var headers: [KeyValue]
    public private(set) var pathParameters: [KeyValue]
    private var composedURL: String
    private var queryRows: [KeyValue]

    public init(_ request: Request) {
        self.init(RequestEdit(request))
    }

    public init(_ edit: RequestEdit) {
        let text = URLTemplateText(edit.urlTemplate)
        let rows = text.queryPairs.map { KeyValue(key: $0.key, value: $0.value) } + edit.queryParameters
        self.method = edit.method
        self.headers = edit.headers
        self.pathParameters = Self.pathRows(in: text, keeping: edit.pathParameters)
        self.queryRows = rows
        self.composedURL = text.replacingQuery(with: rows)
    }

    public var edit: RequestEdit {
        RequestEdit(
            method: method,
            urlTemplate: URLTemplateText(composedURL).withoutQuery,
            queryParameters: queryRows,
            pathParameters: pathParameters,
            headers: headers
        )
    }

    /// Ignores row identifiers, because removing a row and typing it back changes nothing there is to save.
    public func hasSameContent(as other: RequestDraft) -> Bool {
        method == other.method
            && url == other.url
            && queryRows.hasSameContent(as: other.queryRows)
            && pathParameters.hasSameContent(as: other.pathParameters)
            && headers.hasSameContent(as: other.headers)
    }

    public mutating func setPathValue(_ value: String, for id: KeyValue.ID) {
        if let index = pathParameters.firstIndex(where: { $0.id == id }) {
            pathParameters[index].value = value
        }
    }

    /// Setting this keeps the text as typed, so the field never rewrites itself under the cursor.
    public var url: String {
        get { composedURL }
        set {
            let text = URLTemplateText(newValue)
            composedURL = newValue
            queryRows = Self.filling(queryRows, from: text.queryPairs)
            pathParameters = Self.pathRows(in: text, keeping: pathParameters)
        }
    }

    public var queryParameters: [KeyValue] {
        get { queryRows }
        set {
            queryRows = newValue
            composedURL = URLTemplateText(composedURL).replacingQuery(with: newValue)
        }
    }

    /// Only a sent row is in the URL, so the rest stay put. The rows that are take the pairs by position, because that
    /// keeps their identities while the person types in the URL.
    private static func filling(
        _ rows: [KeyValue],
        from pairs: [(key: String, value: String)]
    ) -> [KeyValue] {
        var remaining = pairs[...]
        let filled = rows.compactMap { row -> KeyValue? in
            guard row.isSent else {
                return row
            }
            guard let pair = remaining.popFirst() else {
                return nil
            }
            var filled = row
            filled.key = pair.key
            filled.value = pair.value
            return filled
        }
        return filled + remaining.map { KeyValue(key: $0.key, value: $0.value) }
    }

    private static func pathRows(in text: URLTemplateText, keeping rows: [KeyValue]) -> [KeyValue] {
        text.pathVariableNames.map { name in
            rows.first { $0.key == name } ?? KeyValue(key: name, value: "")
        }
    }

}

private nonisolated extension [KeyValue] {

    func hasSameContent(as other: [KeyValue]) -> Bool {
        elementsEqual(other) { $0.key == $1.key && $0.value == $1.value && $0.isEnabled == $1.isEnabled }
    }

}
