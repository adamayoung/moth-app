//  AppSignature.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import Security

struct AppSignature {

    let teamIdentifier: String?
    let keychainAccessGroup: String?
    var iCloudContainers: [String] = []

}

extension AppSignature {

    init(signingInformation: [String: Any]) {
        let entitlements = signingInformation[kSecCodeInfoEntitlementsDict as String] as? [String: Any]
        let accessGroups = entitlements?["keychain-access-groups"] as? [String]
        let containers = entitlements?["com.apple.developer.icloud-container-identifiers"] as? [String]
        self.init(
            teamIdentifier: signingInformation[kSecCodeInfoTeamIdentifier as String] as? String,
            keychainAccessGroup: accessGroups?.first,
            iCloudContainers: containers ?? []
        )
    }

    /// A signature that cannot be read counts as ad hoc, the mode that needs nothing from the Keychain.
    static func current() -> AppSignature {
        AppSignature(signingInformation: runningSigningInformation())
    }

    static func runningSigningInformation() -> [String: Any] {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var information: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard
            SecCodeCopySelf([], &code) == errSecSuccess,
            let code,
            SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess,
            let staticCode,
            SecCodeCopySigningInformation(staticCode, flags, &information) == errSecSuccess
        else {
            return [:]
        }
        return information as? [String: Any] ?? [:]
    }

}
