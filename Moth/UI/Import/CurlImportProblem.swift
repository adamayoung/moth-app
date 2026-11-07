//  CurlImportProblem.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation

enum CurlImportProblem {

    case invalidCommand
    case failed

    var message: String {
        switch self {
        case .invalidCommand: String(localized: "CURL_IMPORT_INVALID")
        case .failed: String(localized: "CURL_IMPORT_FAILED")
        }
    }

}
