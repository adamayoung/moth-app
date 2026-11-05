//  VariableResolution.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

nonisolated struct VariableResolution {

    private static let maximumDepth = 10

    private let scopes: [[Variable]]
    private let secretStore: any SecretStore
    private let dynamicVariables: DynamicVariables

    private(set) var unresolved: [UnresolvedVariable] = []
    private(set) var credentials: [SecretReference: String] = [:]
    private(set) var unresolvedCredentials: [SecretReference] = []

    init(scopes: [[Variable]], secretStore: any SecretStore, dynamicVariables: DynamicVariables) {
        self.scopes = scopes
        self.secretStore = secretStore
        self.dynamicVariables = dynamicVariables
    }

    /// Expansion never rescans its own output, so a name built from a variable is left for this sweep to report.
    mutating func resolve(_ template: String) async throws -> String {
        let expanded = try await expand(template, chain: [])

        for reference in references(in: expanded) {
            report(String(reference.output.1), .undefined)
        }

        return expanded
    }

    mutating func resolveCredentials(_ references: SecretReference?...) async throws {
        for case let reference? in references {
            guard let value = try await secretStore.value(for: reference.identifier) else {
                if !unresolvedCredentials.contains(reference) {
                    unresolvedCredentials.append(reference)
                }
                continue
            }

            credentials[reference] = try await resolve(value)
        }
    }

    private func references(in text: String) -> [Regex<(Substring, Substring)>.Match] {
        text.matches(of: /\{\{([^{}]*)\}\}/)
    }

    private mutating func expand(_ template: String, chain: [String]) async throws -> String {
        var expanded = ""
        var remainder = template[...]

        for reference in references(in: template) {
            expanded += remainder[..<reference.range.lowerBound]
            remainder = remainder[reference.range.upperBound...]

            let name = String(reference.output.1)
            expanded += try await substitution(for: name, writtenAs: String(reference.output.0), chain: chain)
        }

        return expanded + remainder
    }

    private mutating func substitution(
        for name: String,
        writtenAs reference: String,
        chain: [String]
    ) async throws -> String {
        if chain.contains(name) {
            report(name, .cycle)
            return reference
        }

        if chain.count == Self.maximumDepth {
            report(name, .tooDeep)
            return reference
        }

        if let dynamicValue = dynamicVariables.value(named: name) {
            return dynamicValue
        }

        guard let variable = scopes.joined().first(where: { $0.isEnabled && $0.name == name }) else {
            report(name, .undefined)
            return reference
        }

        guard let value = try await value(of: variable) else {
            report(name, .missingSecret)
            return reference
        }

        return try await expand(value, chain: chain + [name])
    }

    private func value(of variable: Variable) async throws -> String? {
        switch variable.value {
        case .plain(let initial, let current):
            current.isEmpty ? initial : current
        case .secret(let reference):
            try await secretStore.value(for: reference.identifier)
        }
    }

    private mutating func report(_ name: String, _ reason: UnresolvedReason) {
        guard !unresolved.contains(where: { $0.name == name }) else {
            return
        }

        unresolved.append(UnresolvedVariable(name: name, reason: reason))
    }

}
