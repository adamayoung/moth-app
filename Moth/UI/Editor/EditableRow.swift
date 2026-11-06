//  EditableRow.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore

protocol EditableRow: Identifiable where ID == UUID {

    var key: String { get set }
    var isEnabled: Bool { get set }
    var isEditable: Bool { get }
    var editableText: String { get set }

}

extension KeyValue: EditableRow {

    var isEditable: Bool {
        true
    }

    var editableText: String {
        get { value }
        set { value = newValue }
    }

}

extension FormDataField: EditableRow {

    /// A file row can't change until a file can be chosen, which needs security-scoped bookmarks.
    var isEditable: Bool {
        if case .text = value {
            true
        } else {
            false
        }
    }

    var editableText: String {
        get {
            if case .text(let text) = value {
                text
            } else {
                ""
            }
        }
        set {
            if isEditable {
                value = .text(newValue)
            }
        }
    }

}
