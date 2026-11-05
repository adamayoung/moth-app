//  AppSignatureTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

@testable import Moth
import Security
import Testing

@MainActor
struct AppSignatureTests {

    @Test("A team and its first keychain access group are read from signing information")
    func readsTeamAndAccessGroup() {
        let signature = AppSignature(signingInformation: [
            kSecCodeInfoTeamIdentifier as String: "ABCDE12345",
            kSecCodeInfoEntitlementsDict as String: [
                "keychain-access-groups": ["ABCDE12345.uk.co.adam-young.Moth", "ABCDE12345.other"]
            ]
        ])

        #expect(signature.teamIdentifier == "ABCDE12345")
        #expect(signature.keychainAccessGroup == "ABCDE12345.uk.co.adam-young.Moth")
    }

    @Test("Entitled iCloud containers are read from signing information")
    func readsICloudContainers() {
        let signature = AppSignature(signingInformation: [
            kSecCodeInfoEntitlementsDict as String: [
                "com.apple.developer.icloud-container-identifiers": ["iCloud.moth"]
            ]
        ])

        #expect(signature.iCloudContainers == ["iCloud.moth"])
    }

    @Test("Signing information with no iCloud entitlement has no containers")
    func noICloudEntitlementHasNoContainers() {
        let signature = AppSignature(signingInformation: [:])

        #expect(signature.iCloudContainers.isEmpty)
    }

    @Test("Ad hoc signing information has no team or access group")
    func adHocHasNeither() {
        let signature = AppSignature(signingInformation: [
            kSecCodeInfoEntitlementsDict as String: ["com.apple.security.app-sandbox": true]
        ])

        #expect(signature.teamIdentifier == nil)
        #expect(signature.keychainAccessGroup == nil)
    }

    @Test("The running app's signing information agrees with the entitlements the system gives it")
    func runningSigningInformationHoldsEntitlements() {
        let sandbox = "com.apple.security.app-sandbox"
        let task = SecTaskCreateFromSelf(nil)
        let granted = task.flatMap { SecTaskCopyValueForEntitlement($0, sandbox as CFString, nil) } as? Bool

        let information = AppSignature.runningSigningInformation()
        let entitlements = information[kSecCodeInfoEntitlementsDict as String] as? [String: Any]

        #expect(entitlements?[sandbox] as? Bool == granted)
    }

    @Test("Empty signing information has no team or access group")
    func emptyHasNeither() {
        let signature = AppSignature(signingInformation: [:])

        #expect(signature.teamIdentifier == nil)
        #expect(signature.keychainAccessGroup == nil)
    }

}
