//  DynamicVariablesTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import Synchronization
import Testing

struct DynamicVariablesTests {

    private let liveResolver = VariableResolver(secretStore: InMemorySecretStore())

    @Test("{{$guid}} is a lowercase version 4 UUID")
    func guidIsALowercaseUUID() async throws {
        let resolved = try await resolve("{{$guid}}", using: liveResolver)

        #expect(resolved.url
            .wholeMatch(of: /[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/) != nil)
    }

    @Test("{{$timestamp}} is the current Unix time in seconds")
    func timestampIsUnixSeconds() async throws {
        let earliest = Int(Date.now.timeIntervalSince1970.rounded(.down))

        let resolved = try await resolve("{{$timestamp}}", using: liveResolver)

        let latest = Int(Date.now.timeIntervalSince1970.rounded(.up))
        #expect(try (earliest ... latest).contains(#require(Int(resolved.url))))
    }

    @Test("{{$randomInt}} is an integer from 0 to 1000")
    func randomIntIsInRange() async throws {
        let template = Array(repeating: "{{$randomInt}}", count: 100).joined(separator: " ")

        let resolved = try await resolve(template, using: liveResolver)

        let values = resolved.url.split(separator: " ").compactMap { Int($0) }
        #expect(values.count == 100)
        #expect(values.allSatisfy { (0 ... 1000).contains($0) })
        #expect(Set(values).count > 1)
    }

    @Test("Two live occurrences of {{$guid}} differ")
    func liveGUIDsDiffer() async throws {
        let resolved = try await resolve("{{$guid}} {{$guid}}", using: liveResolver)

        let guids = resolved.url.split(separator: " ")
        #expect(Set(guids).count == 2)
    }

    @Test("Each occurrence of a dynamic variable gets its own value", arguments: ["$guid", "$timestamp", "$randomInt"])
    func eachOccurrenceHasItsOwnValue(name: String) async throws {
        let resolved = try await resolve("{{\(name)}} {{\(name)}}", using: resolverCountingOccurrences())

        #expect(resolved.url == "1 2")
    }

    @Test("A dynamic variable resolves inside a value")
    func dynamicVariableNests() async throws {
        let request = Request(name: "Request", urlTemplate: "{{id}}", variables: [.plain("id", "id-{{$randomInt}}")])

        let resolved = try await resolverCountingOccurrences()
            .resolve(request, collection: [], environment: [], globals: [])

        #expect(resolved.url == "id-1")
    }

    @Test("A dynamic variable is not a level, so it resolves at the end of a full chain")
    func dynamicVariableEndsAFullChain() async throws {
        let chain = (1 ... 10).map { level in
            Variable.plain("level\(level)", level == 10 ? "{{$guid}}" : "{{level\(level + 1)}}")
        }

        let resolved = try await resolverCountingOccurrences().resolve(
            Request(name: "Request", urlTemplate: "{{level1}}"),
            collection: chain,
            environment: [],
            globals: []
        )

        #expect(resolved.url == "1")
        #expect(resolved.unresolved.isEmpty)
    }

    @Test("A user variable shadows a dynamic variable, as in Postman")
    func userVariableShadowsADynamicVariable() async throws {
        let request = Request(name: "Request", urlTemplate: "{{$guid}}", variables: [.plain("$guid", "mine")])

        let resolved = try await resolverCountingOccurrences()
            .resolve(request, collection: [], environment: [], globals: [])

        #expect(resolved.url == "mine")
    }

    @Test("A disabled user variable does not shadow a dynamic variable")
    func disabledUserVariableDoesNotShadow() async throws {
        let disabled = Variable(name: "$guid", value: .plain(initial: "mine", current: "mine"), isEnabled: false)
        let request = Request(name: "Request", urlTemplate: "{{$guid}}", variables: [disabled])

        let resolved = try await resolverCountingOccurrences()
            .resolve(request, collection: [], environment: [], globals: [])

        #expect(resolved.url == "1")
    }

    @Test("A dollar name Moth doesn’t know is an ordinary name")
    func unknownDollarNameIsOrdinary() async throws {
        let resolved = try await resolve("{{$randomEmail}}", using: liveResolver)

        #expect(resolved.url == "{{$randomEmail}}")
        #expect(resolved.unresolved == [UnresolvedVariable(name: "$randomEmail", reason: .undefined)])
    }

    private func resolve(_ template: String, using resolver: VariableResolver) async throws -> ResolvedRequest {
        try await resolver.resolve(
            Request(name: "Request", urlTemplate: template),
            collection: [],
            environment: [],
            globals: []
        )
    }

    private func resolverCountingOccurrences() -> VariableResolver {
        let occurrences = Mutex(0)
        let nextOccurrence: @Sendable () -> String = {
            occurrences.withLock { count in
                count += 1
                return String(count)
            }
        }
        let dynamicVariables = DynamicVariables(
            guid: nextOccurrence,
            timestamp: nextOccurrence,
            randomInt: nextOccurrence
        )

        return VariableResolver(secretStore: InMemorySecretStore(), dynamicVariables: dynamicVariables)
    }

}
