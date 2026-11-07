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
        case .secretWithNoValue(let name): String(localized: "RESPONSE_NOTE_SECRET_WITHOUT_VALUE_\(name)")
        case .variableCycle(let name): String(localized: "RESPONSE_NOTE_VARIABLE_CYCLE_\(name)")
        case .variableNotExpanded(let name): String(localized: "RESPONSE_NOTE_VARIABLE_NOT_EXPANDED_\(name)")
        case .undefinedVariables(let count): String(localized: "RESPONSE_NOTE_UNDEFINED_VARIABLES_\(count)")
        case .unresolvedVariables(let count): String(localized: "RESPONSE_NOTE_UNRESOLVED_VARIABLES_\(count)")
        case .pathVariableWithoutValue(let name):
            String(localized: "RESPONSE_NOTE_PATH_VARIABLE_WITHOUT_VALUE_\(name)")
        case .pathVariablesWithoutValues(let count):
            String(localized: "RESPONSE_NOTE_PATH_VARIABLES_WITHOUT_VALUES_\(count)")
        case .unsendableHeader(let name): String(localized: "RESPONSE_NOTE_UNSENDABLE_HEADER_\(name)")
        case .unsendableHeaders(let count): String(localized: "RESPONSE_NOTE_UNSENDABLE_HEADERS_\(count)")
        case .emptyHeaderName(let name): String(localized: "RESPONSE_NOTE_EMPTY_HEADER_NAME_\(name)")
        case .emptyHeaderNames(let count): String(localized: "RESPONSE_NOTE_EMPTY_HEADER_NAMES_\(count)")
        case .emptyQueryParameterName(let name): String(localized: "RESPONSE_NOTE_EMPTY_QUERY_PARAMETER_NAME_\(name)")
        case .emptyQueryParameterNames(let count):
            String(localized: "RESPONSE_NOTE_EMPTY_QUERY_PARAMETER_NAMES_\(count)")
        case .missingCredential: String(localized: "RESPONSE_NOTE_MISSING_CREDENTIAL")
        case .unsupportedAuth: String(localized: "RESPONSE_NOTE_UNSUPPORTED_AUTH")
        case .bodyNotSent(let method): String(localized: "RESPONSE_NOTE_BODY_NOT_SENT_\(method.rawValue.uppercased())")
        case .unsupportedBody: String(localized: "RESPONSE_NOTE_UNSUPPORTED_BODY")
        case .emptyFieldName(let name): String(localized: "RESPONSE_NOTE_EMPTY_FIELD_NAME_\(name)")
        case .emptyFieldNames(let count): String(localized: "RESPONSE_NOTE_EMPTY_FIELD_NAMES_\(count)")
        case .unsupportedFile(let key): String(localized: "RESPONSE_NOTE_UNSUPPORTED_FILE_\(key)")
        case .unsupportedFiles(let count): String(localized: "RESPONSE_NOTE_UNSUPPORTED_FILES_\(count)")
        case .formDataBoundaryReplaced: String(localized: "RESPONSE_NOTE_FORM_DATA_BOUNDARY_REPLACED")
        case .sentAgainForDigestChallenge: String(localized: "RESPONSE_NOTE_DIGEST_SENT_AGAIN")
        case .digestChallengeUnsupported: String(localized: "RESPONSE_NOTE_DIGEST_CHALLENGE_UNSUPPORTED")
        case .digestChallengeAfterRedirect: String(localized: "RESPONSE_NOTE_DIGEST_CHALLENGE_AFTER_REDIRECT")
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
