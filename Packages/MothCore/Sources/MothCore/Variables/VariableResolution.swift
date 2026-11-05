//  VariableResolution.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

nonisolated struct VariableResolution {

    private static let maximumDepth = 10

    /// Ten levels of values that each repeat the next ten times pass the depth and cycle checks, as ten billion
    /// expansions from one imported file. Each expansion spends its value's size, and a flat cost for empty values.
    private static let expansionBudget = 64 * 1024 * 1024
    private static let expansionCost = 1024

    private let scopes: [[Variable]]
    private let secretStore: any SecretStore
    private let dynamicVariables: DynamicVariables

    private var remainingExpansionBudget = Self.expansionBudget

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
        guard text.contains("{{") else {
            return []
        }

        return text.matches(of: /\{\{([^{}]*)\}\}/)
    }

    private mutating func expand(_ template: String, chain: [String]) async throws -> String {
        try Task.checkCancellation()

        var expanded = ""
        var remainder = template[...]

        for reference in references(in: template) {
            expanded += remainder[..<reference.range.lowerBound]
            remainder = remainder[reference.range.upperBound...]

            let name = String(reference.output.1)
            expanded += try await substitution(for: name, chain: chain) ?? String(reference.output.0)
        }

        return expanded + remainder
    }

    private mutating func substitution(for name: String, chain: [String]) async throws -> String? {
        if chain.contains(name) {
            report(name, .cycle)
            return nil
        }

        guard let variable = variable(named: name) else {
            let dynamicValue = dynamicVariables.value(named: name)

            if dynamicValue == nil {
                report(name, .undefined)
            }

            return dynamicValue
        }

        if chain.count == Self.maximumDepth {
            report(name, .tooDeep)
            return nil
        }

        guard let value = try await value(of: variable) else {
            report(name, .missingSecret)
            return nil
        }

        guard spendExpansionBudget(on: value) else {
            report(name, .tooLarge)
            return nil
        }

        return try await expand(value, chain: chain + [name])
    }

    private func variable(named name: String) -> Variable? {
        scopes.lazy.compactMap { scope in
            scope.last { $0.isEnabled && $0.name == name }
        }
        .first
    }

    private func value(of variable: Variable) async throws -> String? {
        switch variable.value {
        case .plain(let initial, let current):
            current.isEmpty ? initial : current
        case .secret(let reference):
            try await secretStore.value(for: reference.identifier)
        }
    }

    private mutating func spendExpansionBudget(on value: String) -> Bool {
        remainingExpansionBudget -= value.utf8.count + Self.expansionCost

        return remainingExpansionBudget >= 0
    }

    private mutating func report(_ name: String, _ reason: UnresolvedReason) {
        guard !unresolved.contains(where: { $0.name == name }) else {
            return
        }

        unresolved.append(UnresolvedVariable(name: name, reason: reason))
    }

}
