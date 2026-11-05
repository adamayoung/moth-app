//  VariableResolverSecretTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import MothCore
import Testing

struct VariableResolverSecretTests {

    private let store = InMemorySecretStore()
    private let apiKey = Variable(name: "apiKey", value: .secret(SecretReference(identifier: "api-key")))

    @Test("A secret variable resolves through the store by its identifier")
    func secretResolvesThroughTheStore() async throws {
        await store.save("s3cret", for: "api-key")

        let resolved = try await resolve("{{apiKey}}", environment: [apiKey])

        #expect(resolved.url == "s3cret")
        #expect(resolved.unresolved.isEmpty)
    }

    @Test("A secret’s value can hold a reference")
    func secretValueNests() async throws {
        await store.save("Bearer {{token}}", for: "api-key")

        let resolved = try await resolve("{{apiKey}}", environment: [apiKey, .plain("token", "abc")])

        #expect(resolved.url == "Bearer abc")
    }

    @Test("A missing secret stays as written and is reported")
    func missingSecretIsReported() async throws {
        let resolved = try await resolve("{{apiKey}}", environment: [apiKey])

        #expect(resolved.url == "{{apiKey}}")
        #expect(resolved.unresolved == [UnresolvedVariable(name: "apiKey", reason: .missingSecret)])
    }

    @Test("A missing secret is the first match, so the search does not carry on")
    func missingSecretDoesNotFallThrough() async throws {
        let resolved = try await resolve("{{apiKey}}", environment: [apiKey], globals: [.plain("apiKey", "global")])

        #expect(resolved.url == "{{apiKey}}")
    }

    @Test("A secret store failure is thrown, not reported as a missing secret")
    func storeFailureIsThrown() async {
        let resolver = VariableResolver(secretStore: FailingSecretStore())
        let request = Request(name: "Request", urlTemplate: "{{apiKey}}", variables: [apiKey])

        await #expect(throws: FailingSecretStore.Failure.self) {
            try await resolver.resolve(request, collection: [], environment: [], globals: [])
        }
    }

    private func resolve(
        _ template: String,
        environment: [Variable],
        globals: [Variable] = []
    ) async throws -> ResolvedRequest {
        try await VariableResolver(secretStore: store).resolve(
            Request(name: "Request", urlTemplate: template),
            collection: [],
            environment: environment,
            globals: globals
        )
    }

}
