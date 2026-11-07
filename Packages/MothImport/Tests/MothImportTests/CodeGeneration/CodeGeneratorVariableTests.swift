//  CodeGeneratorVariableTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore
import MothImport
import Testing

struct CodeGeneratorVariableTests {

    private let dynamicVariables = DynamicVariables(guid: { "the-guid" }, timestamp: { "0" }, randomInt: { "7" })

    private func code(for urlTemplate: String, environment: [Variable]) async throws -> GeneratedCode {
        try await CodeGenerator(dynamicVariables: dynamicVariables).code(
            for: Request(name: "Users", urlTemplate: urlTemplate),
            scopes: VariableScopes(environment: environment)
        )
    }

    @Test("A plain variable resolves against the environment")
    func plainVariable() async throws {
        let code = try await code(
            for: "{{host}}/users",
            environment: [Variable(name: "host", value: .plain(initial: "", current: "https://example.com"))]
        )

        #expect(code.curl == "curl --url 'https://example.com/users'")
        #expect(code.swift.contains(#"URL(string: "https://example.com/users")!"#))
    }

    @Test("A secret variable stays as written")
    func secretVariable() async throws {
        let code = try await code(
            for: "https://example.com/{{token}}",
            environment: [Variable(name: "token", value: .secret(SecretReference()))]
        )

        #expect(code.curl.contains("'https://example.com/{{token}}'"))
        #expect(code.swift.contains("https://example.com/{{token}}"))
    }

    @Test("A plain variable that holds a secret one resolves as far as the secret")
    func chainToASecret() async throws {
        let code = try await code(
            for: "{{path}}",
            environment: [
                Variable(name: "path", value: .plain(initial: "", current: "https://example.com/{{token}}")),
                Variable(name: "token", value: .secret(SecretReference()))
            ]
        )

        #expect(code.curl.contains("'https://example.com/{{token}}'"))
    }

    @Test("An undefined variable stays as written")
    func undefinedVariable() async throws {
        let code = try await code(for: "https://example.com/{{nothing}}", environment: [])

        #expect(code.curl.contains("'https://example.com/{{nothing}}'"))
        #expect(code.swift.contains("https://example.com/{{nothing}}"))
    }

    @Test("A dynamic variable resolves, as Send does")
    func dynamicVariable() async throws {
        let code = try await code(for: "https://example.com/{{$guid}}", environment: [])

        #expect(code.curl == "curl --url 'https://example.com/the-guid'")
    }

}
