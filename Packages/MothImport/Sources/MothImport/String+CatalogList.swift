//  String+CatalogList.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import Foundation

nonisolated extension [String] {

    /// Follows the catalog's language, not the Mac's region, or one sentence could mix two styles of English.
    var catalogList: String {
        let locale = Locale(identifier: Bundle.module.preferredLocalizations.first ?? "en-GB")
        return formatted(.list(type: .and).locale(locale))
    }

}
