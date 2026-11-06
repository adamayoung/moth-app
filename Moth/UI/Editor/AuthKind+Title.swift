//  AuthKind+Title.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftUI

extension AuthKind {

    var title: LocalizedStringKey {
        switch self {
        case .inherit: "AUTH_KIND_INHERIT"
        case .none: "AUTH_KIND_NONE"
        case .basic: "AUTH_KIND_BASIC"
        case .bearer: "AUTH_KIND_BEARER"
        case .apiKey: "AUTH_KIND_API_KEY"
        case .digest: "AUTH_KIND_DIGEST"
        case .oauth2: "AUTH_KIND_OAUTH2"
        case .awsSigV4: "AUTH_KIND_AWS_SIGV4"
        }
    }

}
