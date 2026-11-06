//  PostmanSecretStorageTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore
import MothImport
import Testing

struct PostmanSecretStorageTests {

    private static let helpers = "postman-collection-transformer/v2.1.0/helpers.json"
    private static let plaintexts = [
        "kane", "wkjehbxoqnunc2k3", "secretToken", "secretClientValue", "randomSecretString", "refreshToken"
    ]

    @Test("Credentials reach the store, and none of them appears in the domain values")
    func keepsCredentialsOutOfDomainValues() async throws {
        let store = RecordingSecretStore()

        let result = try await Fixture.importing(Self.helpers, secretStore: store)

        let saved = await store.values
        #expect(Set(saved.values) == Set(Self.plaintexts))
        #expect(saved.count == 7)
        #expect(Set(saved.keys) == Set(result.secrets.map(\.identifier)))

        let domainValues = String(reflecting: result.content)
        // The fixture's refresh token is the text "refreshToken", which reflection prints as a property's label.
        for plaintext in Self.plaintexts where plaintext != "refreshToken" {
            #expect(!domainValues.contains(plaintext), "\(plaintext) reached the domain values")
        }
    }

    @Test("A failed save removes what was saved and rethrows, so a failed import leaves no secret behind")
    func removesSavedSecretsWhenASaveFails() async throws {
        let store = RecordingSecretStore(refusing: "kane")

        await #expect(throws: RecordingSecretStore.Failure.refused) {
            try await Fixture.importing(Self.helpers, secretStore: store)
        }

        #expect(await store.values.isEmpty)
    }

}
