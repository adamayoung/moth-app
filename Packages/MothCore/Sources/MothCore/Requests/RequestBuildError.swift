//  RequestBuildError.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated enum RequestBuildError: LocalizedError, Equatable {

    case invalidURL

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            String(localized: "REQUEST_BUILD_INVALID_URL", bundle: .module)
        }
    }

}
