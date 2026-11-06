//  ImportedName.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import Foundation

nonisolated enum ImportedName {

    static func given(_ name: String?) -> String {
        guard let name, !name.isBlank else {
            return String(localized: "IMPORT_UNTITLED_NAME", bundle: .module)
        }
        return name
    }

    static func unique(_ name: String, avoiding existingNames: Set<String>) -> String {
        guard existingNames.contains(name) else {
            return name
        }

        var suffix = 2
        while existingNames.contains("\(name) \(suffix)") {
            suffix += 1
        }
        return "\(name) \(suffix)"
    }

}

nonisolated extension String {

    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

}
