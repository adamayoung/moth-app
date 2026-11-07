//  ImportReport.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothImport

struct ImportReport: Identifiable {

    let id = UUID()
    let message: String
    let skipped: String?

    static var rejected: ImportReport {
        ImportReport(message: String(localized: "IMPORT_REJECTED"), skipped: nil)
    }

    static var failed: ImportReport {
        ImportReport(message: String(localized: "IMPORT_FAILED"), skipped: nil)
    }

}

extension ImportReport {

    init(_ result: PostmanImportResult) {
        self.init(message: result.importedSummary, skipped: result.skippedSummary)
    }

}

extension ImportReport {

    /// Nil with nothing ignored, because the new tab says everything else.
    init?(_ result: CurlImportResult) {
        guard let ignored = result.ignoredSummary else {
            return nil
        }
        self.init(message: result.importedSummary, skipped: ignored)
    }

}
