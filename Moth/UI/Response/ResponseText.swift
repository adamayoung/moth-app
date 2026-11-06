//  ResponseText.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore

extension SendFailure.Kind {

    var title: String {
        switch self {
        case .couldNotConnect: String(localized: "RESPONSE_FAILED_CONNECT")
        case .timedOut: String(localized: "RESPONSE_FAILED_TIMEOUT")
        case .notSent: String(localized: "RESPONSE_FAILED_NOT_SENT")
        }
    }

}

extension ResponseNote {

    var message: String {
        switch self {
        case .undefinedVariable(let name): String(localized: "RESPONSE_NOTE_UNDEFINED_VARIABLE_\(name)")
        case .undefinedVariables(let count): String(localized: "RESPONSE_NOTE_UNDEFINED_VARIABLES_\(count)")
        case .unsupportedAuth: String(localized: "RESPONSE_NOTE_UNSUPPORTED_AUTH")
        case .unsupportedBody: String(localized: "RESPONSE_NOTE_UNSUPPORTED_BODY")
        }
    }

}

extension TimingPhase {

    var title: String {
        switch self {
        case .dns: String(localized: "RESPONSE_TIMING_DNS")
        case .connect: String(localized: "RESPONSE_TIMING_CONNECT")
        case .tls: String(localized: "RESPONSE_TIMING_TLS")
        case .firstByte: String(localized: "RESPONSE_TIMING_FIRST_BYTE")
        case .download: String(localized: "RESPONSE_TIMING_DOWNLOAD")
        }
    }

}
