//  BodyDraft.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

public nonisolated enum BodyKind: Sendable, Hashable {

    case none
    case formData
    case urlEncoded
    case raw
    case binary
    case graphQL

    public static let editable: [BodyKind] = [.none, .formData, .urlEncoded, .raw]

}

public nonisolated enum RawContentType: String, CaseIterable, Sendable {

    case json = "application/json"
    case text = "text/plain"
    case xml = "application/xml"
    case html = "text/html"

}

/// Holds every kind's fields while a draft is open, so trying another kind doesn't lose what was typed. A binary or
/// GraphQL body is held as it came, because the editor can't show its fields yet.
public nonisolated struct BodyDraft: Sendable {

    public var kind: BodyKind
    public var rawContent = ""
    public var rawContentType = RawContentType.json.rawValue
    public var urlEncodedRows: [KeyValue] = []
    public var formDataFields: [FormDataField] = []
    private var unsupportedBody: RequestBody?

    public init(_ body: RequestBody) {
        switch body {
        case .none:
            self.kind = .none
        case .formData(let fields):
            self.kind = .formData
            self.formDataFields = fields
        case .urlEncoded(let rows):
            self.kind = .urlEncoded
            self.urlEncodedRows = rows
        case .raw(let content, let contentType):
            self.kind = .raw
            self.rawContent = content
            self.rawContentType = contentType
        case .binary:
            self.kind = .binary
            self.unsupportedBody = body
        case .graphQL:
            self.kind = .graphQL
            self.unsupportedBody = body
        }
    }

    public var requestBody: RequestBody {
        switch kind {
        case .none: .none
        case .formData: .formData(formDataFields)
        case .urlEncoded: .urlEncoded(urlEncodedRows)
        case .raw: .raw(content: rawContent, contentType: rawContentType)
        case .binary, .graphQL: unsupportedBody ?? .none
        }
    }

    /// A body the editor can't change keeps its own entry, so choosing another kind can be undone before Save.
    public var kinds: [BodyKind] {
        switch unsupportedBody {
        case .binary: BodyKind.editable + [.binary]
        case .graphQL: BodyKind.editable + [.graphQL]
        default: BodyKind.editable
        }
    }

    /// Ignores row identifiers, because removing a row and typing it back changes nothing there is to save.
    public func hasSameContent(as other: BodyDraft) -> Bool {
        switch (requestBody, other.requestBody) {
        case (.urlEncoded(let rows), .urlEncoded(let otherRows)):
            rows.hasSameContent(as: otherRows)
        case (.formData(let fields), .formData(let otherFields)):
            fields.elementsEqual(otherFields) {
                $0.key == $1.key && $0.value == $1.value && $0.contentType == $1.contentType
                    && $0.isEnabled == $1.isEnabled
            }
        case (let body, let otherBody):
            body == otherBody
        }
    }

}
