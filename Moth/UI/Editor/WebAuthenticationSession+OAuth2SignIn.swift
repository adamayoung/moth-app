//  WebAuthenticationSession+OAuth2SignIn.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import AuthenticationServices
import MothCore
import SwiftUI

extension WebAuthenticationSession {

    /// Shares the browser's session, so a provider the person is already signed in to doesn't ask again. A
    /// cancelled sheet is a `CancellationError`, which leaves the token as it was and shows no error.
    var oauth2SignIn: OAuth2SignIn {
        { url, callbackScheme in
            do {
                return try await authenticate(
                    using: url,
                    callback: .customScheme(callbackScheme),
                    preferredBrowserSession: .shared,
                    additionalHeaderFields: [:]
                )
            } catch ASWebAuthenticationSessionError.canceledLogin {
                throw CancellationError()
            }
        }
    }

}
