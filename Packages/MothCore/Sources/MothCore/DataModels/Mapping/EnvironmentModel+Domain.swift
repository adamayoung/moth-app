//  EnvironmentModel+Domain.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

nonisolated extension EnvironmentModel {

    convenience init(_ environment: WorkspaceEnvironment, sortOrder: Int) {
        self.init()
        self.id = environment.id
        self.name = environment.name
        self.sortOrder = sortOrder
        self.variables = environment.variables.enumerated().map { index, variable in
            VariableModel(variable, sortOrder: index)
        }
    }

    public func asDomain() -> WorkspaceEnvironment {
        WorkspaceEnvironment(id: id, name: name, variables: variables.inSortOrder.map { $0.asDomain() })
    }

}

nonisolated extension VariableModel {

    convenience init(_ variable: Variable, sortOrder: Int, isGlobal: Bool = false) {
        self.init()
        self.id = variable.id
        self.name = variable.name
        self.isEnabled = variable.isEnabled
        self.sortOrder = sortOrder
        self.isGlobal = isGlobal
        switch variable.value {
        case .plain(let initial, let current):
            self.initialValue = initial
            self.currentValue = current
        case .secret(let reference):
            self.secretIdentifier = reference.identifier
        }
    }

    func isIn(_ scope: VariableScope) -> Bool {
        switch scope {
        case .globals: isGlobal
        case .environment(let id): environment?.id == id
        case .collection(let id): collection?.id == id
        }
    }

    func apply(_ variable: Variable) {
        assign(variable.name, to: \.name)
        assign(variable.isEnabled, to: \.isEnabled)
        assign(variable.initialValue ?? "", to: \.initialValue)
        assign(variable.currentValue ?? "", to: \.currentValue)
        assign(variable.secretReference?.identifier, to: \.secretIdentifier)
    }

    /// Compares first because an equal-value assignment still rewrites the row.
    private func assign<Value: Equatable>(_ value: Value, to property: ReferenceWritableKeyPath<VariableModel, Value>) {
        if self[keyPath: property] != value {
            self[keyPath: property] = value
        }
    }

    public func asDomain() -> Variable {
        let value: VariableValue = if let secretIdentifier {
            .secret(SecretReference(identifier: secretIdentifier))
        } else {
            .plain(initial: initialValue, current: currentValue)
        }
        return Variable(id: id, name: name, value: value, isEnabled: isEnabled)
    }

}
