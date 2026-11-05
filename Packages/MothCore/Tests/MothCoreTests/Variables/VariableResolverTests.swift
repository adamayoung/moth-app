//  VariableResolverTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import MothCore
import Testing

struct VariableResolverTests {

    private let resolver = VariableResolver(secretStore: InMemorySecretStore())

    @Test("A request variable beats a collection variable of the same name")
    func requestScopeWins() async throws {
        let request = Request(name: "Request", urlTemplate: "{{host}}", variables: [.plain("host", "request")])

        let resolved = try await resolver.resolve(
            request,
            collection: [.plain("host", "collection")],
            environment: [],
            globals: []
        )

        #expect(resolved.url == "request")
    }

    @Test("A collection variable beats an environment variable of the same name")
    func collectionScopeBeatsEnvironment() async throws {
        let resolved = try await resolver.resolve(
            Request(name: "Request", urlTemplate: "{{host}}"),
            collection: [.plain("host", "collection")],
            environment: [.plain("host", "environment")],
            globals: []
        )

        #expect(resolved.url == "collection")
    }

    @Test("An environment variable beats a global of the same name")
    func environmentScopeBeatsGlobals() async throws {
        let resolved = try await resolver.resolve(
            Request(name: "Request", urlTemplate: "{{host}}"),
            collection: [],
            environment: [.plain("host", "environment")],
            globals: [.plain("host", "global")]
        )

        #expect(resolved.url == "environment")
    }

    @Test("A global resolves when no other scope has the name")
    func globalsAreTheLastScope() async throws {
        let resolved = try await resolver.resolve(
            Request(name: "Request", urlTemplate: "{{host}}"),
            collection: [],
            environment: [],
            globals: [.plain("host", "global")]
        )

        #expect(resolved.url == "global")
    }

    @Test("A disabled variable is skipped and the search carries on to the next scope")
    func disabledVariableIsSkipped() async throws {
        let disabled = Variable(name: "host", value: .plain(initial: "off", current: "off"), isEnabled: false)

        let resolved = try await resolver.resolve(
            Request(name: "Request", urlTemplate: "{{host}}", variables: [disabled]),
            collection: [],
            environment: [.plain("host", "environment")],
            globals: []
        )

        #expect(resolved.url == "environment")
    }

    @Test("An empty current value falls back to the initial value")
    func emptyCurrentValueFallsBackToInitial() async throws {
        let variable = Variable(name: "host", value: .plain(initial: "initial", current: ""))

        let resolved = try await resolver.resolve(
            Request(name: "Request", urlTemplate: "{{host}}", variables: [variable]),
            collection: [],
            environment: [],
            globals: []
        )

        #expect(resolved.url == "initial")
    }

    @Test("A variable with both values empty resolves to nothing and ends the search")
    func bothValuesEmptyStopsTheSearch() async throws {
        let variable = Variable(name: "host", value: .plain(initial: "", current: ""))

        let resolved = try await resolver.resolve(
            Request(name: "Request", urlTemplate: "[{{host}}]", variables: [variable]),
            collection: [.plain("host", "collection")],
            environment: [],
            globals: []
        )

        #expect(resolved.url == "[]")
    }

    @Test("A name is matched exactly, so spaces inside the braces are part of it")
    func spacesInsideTheBracesAreNotTrimmed() async throws {
        let request = Request(name: "Request", urlTemplate: "{{ host }}", variables: [.plain("host", "request")])

        let resolved = try await resolver.resolve(request, collection: [], environment: [], globals: [])

        #expect(resolved.url == "{{ host }}")
    }

    @Test("A value that holds a reference resolves too, restarting at the request scope")
    func nestedLookupRestartsAtTheRequestScope() async throws {
        let request = Request(name: "Request", urlTemplate: "{{url}}", variables: [.plain("host", "request")])

        let resolved = try await resolver.resolve(
            request,
            collection: [],
            environment: [.plain("url", "https://{{host}}/v1")],
            globals: [.plain("host", "global")]
        )

        #expect(resolved.url == "https://request/v1")
        #expect(resolved.unresolved.isEmpty)
    }

    @Test("A chain through ten variables resolves")
    func aChainOfTenResolves() async throws {
        let resolved = try await resolve("{{level1}}", with: chain(length: 10))

        #expect(resolved.url == "end")
        #expect(resolved.unresolved.isEmpty)
    }

    @Test("The eleventh variable in a chain stays as written and is reported as too deep")
    func aChainOfElevenStops() async throws {
        let resolved = try await resolve("{{level1}}", with: chain(length: 11))

        #expect(resolved.url == "{{level11}}")
        #expect(resolved.unresolved == [UnresolvedVariable(name: "level11", reason: .tooDeep)])
    }

    @Test("A cycle ends with the re-entered reference as written, and is reported")
    func aCycleEndsAndIsReported() async throws {
        let resolved = try await resolve("{{a}}", with: [.plain("a", "x{{b}}"), .plain("b", "y{{a}}")])

        #expect(resolved.url == "xy{{a}}")
        #expect(resolved.unresolved == [UnresolvedVariable(name: "a", reason: .cycle)])
    }

    @Test("A variable that names itself ends and is reported")
    func aSelfReferenceEndsAndIsReported() async throws {
        let resolved = try await resolve("{{a}}", with: [.plain("a", "x{{a}}")])

        #expect(resolved.url == "x{{a}}")
        #expect(resolved.unresolved == [UnresolvedVariable(name: "a", reason: .cycle)])
    }

    @Test("A variable used twice along different paths is not a cycle")
    func repeatedUseIsNotACycle() async throws {
        let resolved = try await resolve(
            "{{a}}{{b}}",
            with: [.plain("a", "{{c}}-{{c}}"), .plain("b", "{{c}}"), .plain("c", "1")]
        )

        #expect(resolved.url == "1-11")
        #expect(resolved.unresolved.isEmpty)
    }

    @Test("A name with no match stays as written and is reported")
    func undefinedNameIsReported() async throws {
        let resolved = try await resolve("https://{{host}}/v1", with: [])

        #expect(resolved.url == "https://{{host}}/v1")
        #expect(resolved.unresolved == [UnresolvedVariable(name: "host", reason: .undefined)])
    }

    @Test("A name with no match inside a value stays as written and is reported")
    func undefinedNameInsideAValueIsReported() async throws {
        let resolved = try await resolve("{{url}}", with: [.plain("url", "https://{{host}}")])

        #expect(resolved.url == "https://{{host}}")
        #expect(resolved.unresolved == [UnresolvedVariable(name: "host", reason: .undefined)])
    }

    @Test("A repeated unresolved name is reported once, in first-seen order")
    func unresolvedNamesAreReportedOnce() async throws {
        let resolved = try await resolve("{{b}}{{a}}{{b}}", with: [])

        #expect(resolved.unresolved.map(\.name) == ["b", "a"])
    }

    @Test("Empty braces are reported, as nothing can match them")
    func emptyBracesAreReported() async throws {
        let resolved = try await resolve("{{}}", with: [])

        #expect(resolved.url == "{{}}")
        #expect(resolved.unresolved == [UnresolvedVariable(name: "", reason: .undefined)])
    }

    @Test("A request resolves, and its result can be read and compared, off the main actor")
    func resolvesOffTheMainActor() async throws {
        try await verifyOffTheMainActor()
    }

    /// A type left on the main actor fails to compile here, which is what this test proves.
    @concurrent
    private func verifyOffTheMainActor() async throws {
        let request = Request(name: "Request", urlTemplate: "{{missing}}")
        let dynamicVariables = DynamicVariables.live

        let resolved = try await VariableResolver(
            secretStore: InMemorySecretStore(),
            dynamicVariables: dynamicVariables
        )
        .resolve(request, collection: [], environment: [], globals: [])

        #expect(resolved.unresolved == [UnresolvedVariable(name: "missing", reason: UnresolvedReason.undefined)])
        #expect(Set([resolved, resolved]).count == 1)
    }

    @Test("A name built from a variable is not resolved, and is reported as written")
    func aNameBuiltFromAVariableIsReported() async throws {
        let resolved = try await resolve("{{a{{b}}}}", with: [.plain("b", "X"), .plain("aX", "composed")])

        #expect(resolved.url == "{{aX}}")
        #expect(resolved.unresolved == [UnresolvedVariable(name: "aX", reason: .undefined)])
    }

    @Test(
        "Braces around a reference stay, whatever sits beside it",
        arguments: [
            ("{{{id}}}", "{1}"),
            (#"{"user":{"id":{{id}}}}"#, #"{"user":{"id":1}}"#),
            ("{{id}}}}", "1}}"),
            ("{{id", "{{id"),
            ("id}}", "id}}")
        ]
    )
    func bracesBesideAReferenceStay(template: String, expected: String) async throws {
        let resolved = try await resolve(template, with: [.plain("id", "1")])

        #expect(resolved.url == expected)
    }

    private func resolve(_ template: String, with variables: [Variable]) async throws -> ResolvedRequest {
        let request = Request(name: "Request", urlTemplate: template)

        return try await resolver.resolve(request, collection: variables, environment: [], globals: [])
    }

    private func chain(length: Int) -> [Variable] {
        (1 ... length).map { level in
            .plain("level\(level)", level == length ? "end" : "{{level\(level + 1)}}")
        }
    }

}
