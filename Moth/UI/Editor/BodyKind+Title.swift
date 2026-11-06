//  BodyKind+Title.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftUI

extension BodyKind {

    var title: LocalizedStringKey {
        switch self {
        case .none: "BODY_KIND_NONE"
        case .formData: "BODY_KIND_FORM_DATA"
        case .urlEncoded: "BODY_KIND_URL_ENCODED"
        case .raw: "BODY_KIND_RAW"
        case .binary: "BODY_KIND_BINARY"
        case .graphQL: "BODY_KIND_GRAPHQL"
        }
    }

}

extension RawContentType {

    var title: LocalizedStringKey {
        switch self {
        case .json: "RAW_CONTENT_TYPE_JSON"
        case .text: "RAW_CONTENT_TYPE_TEXT"
        case .xml: "RAW_CONTENT_TYPE_XML"
        case .html: "RAW_CONTENT_TYPE_HTML"
        }
    }

}
