//  KeychainSecretStoreTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import MothCore
import Security
import Testing

struct KeychainSecretStoreTests {

    @Test("A local-only item has no synchronisable flag, access group or data protection attribute")
    func localOnlyAttributes() async throws {
        let keychain = RecordingKeychainItems()
        let store = KeychainSecretStore(service: "tests", mode: .localOnly, keychain: keychain)

        try await store.save("s3cret", for: "api-key")

        let attributes = try #require(keychain.addedAttributes)
        #expect(attributes[kSecAttrSynchronizable] as? Bool == false)
        #expect(attributes[kSecAttrAccessGroup] == nil)
        #expect(attributes[kSecUseDataProtectionKeychain] == nil)
        #expect(attributes[kSecAttrAccessible] == nil)
    }

    @Test("A synchronised item has the flag, the access group, data protection and no device-only accessibility")
    func synchronisedAttributes() async throws {
        let keychain = RecordingKeychainItems()
        let store = KeychainSecretStore(service: "tests", mode: .synchronised(accessGroup: "group"), keychain: keychain)

        try await store.save("s3cret", for: "api-key")

        let attributes = try #require(keychain.addedAttributes)
        #expect(attributes[kSecAttrSynchronizable] as? Bool == true)
        #expect(attributes[kSecAttrAccessGroup] as? String == "group")
        #expect(attributes[kSecUseDataProtectionKeychain] as? Bool == true)
        #expect(attributes[kSecAttrAccessible] as? String == kSecAttrAccessibleWhenUnlocked as String)
    }

    @Test("A device-only item is in the access group's data protection keychain, never syncs, and stays on this Mac")
    func deviceOnlyAttributes() async throws {
        let keychain = RecordingKeychainItems()
        let store = KeychainSecretStore(service: "tests", mode: .deviceOnly(accessGroup: "group"), keychain: keychain)

        try await store.save("s3cret", for: "cookie")

        let attributes = try #require(keychain.addedAttributes)
        #expect(attributes[kSecAttrSynchronizable] as? Bool == false)
        #expect(attributes[kSecAttrAccessGroup] as? String == "group")
        #expect(attributes[kSecUseDataProtectionKeychain] as? Bool == true)
        #expect(attributes[kSecAttrAccessible] as? String == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
    }

    @Test("A device-only read and removal use the same scope as the add")
    func deviceOnlyScope() async throws {
        let keychain = RecordingKeychainItems(readStatus: errSecItemNotFound)
        let store = KeychainSecretStore(service: "tests", mode: .deviceOnly(accessGroup: "group"), keychain: keychain)

        _ = try await store.value(for: "cookie")
        try await store.removeValue(for: "cookie")

        for query in try [#require(keychain.readQuery), #require(keychain.deleteQuery)] {
            #expect(query[kSecAttrSynchronizable] as? Bool == false)
            #expect(query[kSecAttrAccessGroup] as? String == "group")
            #expect(query[kSecUseDataProtectionKeychain] as? Bool == true)
        }
    }

    @Test("Saving over an existing item updates it, in the same scope as the add")
    func updatesADuplicateItem() async throws {
        let keychain = RecordingKeychainItems(addStatus: errSecDuplicateItem)
        let store = KeychainSecretStore(service: "tests", mode: .synchronised(accessGroup: "group"), keychain: keychain)

        try await store.save("s3cret", for: "api-key")

        let query = try #require(keychain.updateQuery)
        #expect(query[kSecAttrService] as? String == "tests")
        #expect(query[kSecAttrAccount] as? String == "api-key")
        #expect(query[kSecAttrSynchronizable] as? Bool == true)
        #expect(query[kSecAttrAccessGroup] as? String == "group")
        #expect(query[kSecUseDataProtectionKeychain] as? Bool == true)
    }

    @Test("A failed add is an error")
    func failedAddThrows() async {
        let keychain = RecordingKeychainItems(addStatus: errSecInteractionNotAllowed)
        let store = KeychainSecretStore(service: "tests", mode: .localOnly, keychain: keychain)

        await #expect(throws: KeychainSecretStoreError(operation: .save, status: errSecInteractionNotAllowed)) {
            try await store.save("s3cret", for: "api-key")
        }
    }

    @Test("A failed update is an error")
    func failedUpdateThrows() async {
        let keychain = RecordingKeychainItems(addStatus: errSecDuplicateItem, updateStatus: errSecAuthFailed)
        let store = KeychainSecretStore(service: "tests", mode: .localOnly, keychain: keychain)

        await #expect(throws: KeychainSecretStoreError(operation: .save, status: errSecAuthFailed)) {
            try await store.save("s3cret", for: "api-key")
        }
    }

    @Test("A read returns the saved value, in the same scope as the add")
    func readsAValue() async throws {
        let keychain = RecordingKeychainItems(readData: Data("s3cret".utf8))
        let store = KeychainSecretStore(service: "tests", mode: .synchronised(accessGroup: "group"), keychain: keychain)

        let value = try await store.value(for: "api-key")

        #expect(value == "s3cret")
        let query = try #require(keychain.readQuery)
        #expect(query[kSecAttrAccount] as? String == "api-key")
        #expect(query[kSecAttrSynchronizable] as? Bool == true)
        #expect(query[kSecAttrAccessGroup] as? String == "group")
        #expect(query[kSecUseDataProtectionKeychain] as? Bool == true)
    }

    @Test("A missing item reads as nothing")
    func readsNothingForAMissingItem() async throws {
        let keychain = RecordingKeychainItems(readStatus: errSecItemNotFound)
        let store = KeychainSecretStore(service: "tests", mode: .localOnly, keychain: keychain)

        #expect(try await store.value(for: "missing") == nil)
    }

    @Test(
        "A failed read is an error, not a missing value",
        arguments: [errSecInteractionNotAllowed, errSecAuthFailed, errSecMissingEntitlement]
    )
    func failedReadThrows(status: OSStatus) async {
        let keychain = RecordingKeychainItems(readStatus: status)
        let store = KeychainSecretStore(service: "tests", mode: .localOnly, keychain: keychain)

        await #expect(throws: KeychainSecretStoreError(operation: .read, status: status)) {
            try await store.value(for: "api-key")
        }
    }

    @Test("An item that is not text is an error, not a missing value")
    func undecodableItemThrows() async {
        let keychain = RecordingKeychainItems(readData: Data([0xFF, 0xFE]))
        let store = KeychainSecretStore(service: "tests", mode: .localOnly, keychain: keychain)

        await #expect(throws: KeychainSecretStoreError(operation: .read, status: errSecDecode)) {
            try await store.value(for: "api-key")
        }
    }

    @Test("A removal uses the same scope as the add")
    func removesAValue() async throws {
        let keychain = RecordingKeychainItems()
        let store = KeychainSecretStore(service: "tests", mode: .synchronised(accessGroup: "group"), keychain: keychain)

        try await store.removeValue(for: "api-key")

        let query = try #require(keychain.deleteQuery)
        #expect(query[kSecAttrAccount] as? String == "api-key")
        #expect(query[kSecAttrSynchronizable] as? Bool == true)
        #expect(query[kSecAttrAccessGroup] as? String == "group")
        #expect(query[kSecUseDataProtectionKeychain] as? Bool == true)
    }

    @Test("Removing a missing item does not throw")
    func removesAMissingItem() async {
        let keychain = RecordingKeychainItems(deleteStatus: errSecItemNotFound)
        let store = KeychainSecretStore(service: "tests", mode: .localOnly, keychain: keychain)

        await #expect(throws: Never.self) {
            try await store.removeValue(for: "missing")
        }
    }

    @Test("A failed removal is an error")
    func failedRemovalThrows() async {
        let keychain = RecordingKeychainItems(deleteStatus: errSecInvalidOwnerEdit)
        let store = KeychainSecretStore(service: "tests", mode: .localOnly, keychain: keychain)

        await #expect(throws: KeychainSecretStoreError(operation: .remove, status: errSecInvalidOwnerEdit)) {
            try await store.removeValue(for: "api-key")
        }
    }

    @Test("A failed save's error names the operation and status, and holds no secret value")
    func errorHoldsNoSecret() async throws {
        let secret = "correct-horse-battery-staple"
        let keychain = RecordingKeychainItems(addStatus: errSecAuthFailed)
        let store = KeychainSecretStore(service: "tests", mode: .localOnly, keychain: keychain)

        let error = try #require(await #expect(throws: KeychainSecretStoreError.self) {
            try await store.save(secret, for: "api-key")
        })

        let descriptions = [String(describing: error), String(reflecting: error), error.localizedDescription]
        #expect(descriptions.allSatisfy { !$0.contains(secret) })
        #expect(String(describing: error).contains("save"))
        #expect(String(describing: error).contains("\(errSecAuthFailed)"))
    }

}
