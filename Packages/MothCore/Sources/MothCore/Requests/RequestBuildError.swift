//  RequestBuildError.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated enum RequestBuildError: LocalizedError, Equatable {

    case invalidURL
    case invalidMethod
    case invalidBearerToken
    case invalidAPIKey
    case incompleteAWSSignature
    case unsendableAWSSignature

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            String(localized: "REQUEST_BUILD_INVALID_URL", bundle: .module)
        case .invalidMethod:
            String(localized: "REQUEST_BUILD_INVALID_METHOD", bundle: .module)
        case .invalidBearerToken:
            String(localized: "REQUEST_BUILD_INVALID_BEARER_TOKEN", bundle: .module)
        case .invalidAPIKey:
            String(localized: "REQUEST_BUILD_INVALID_API_KEY", bundle: .module)
        case .incompleteAWSSignature:
            String(localized: "REQUEST_BUILD_INCOMPLETE_AWS_SIGNATURE", bundle: .module)
        case .unsendableAWSSignature:
            String(localized: "REQUEST_BUILD_UNSENDABLE_AWS_SIGNATURE", bundle: .module)
        }
    }

}
