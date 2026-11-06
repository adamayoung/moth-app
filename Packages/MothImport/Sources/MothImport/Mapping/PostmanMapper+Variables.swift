//  PostmanMapper+Variables.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore
import PostmanKit

nonisolated extension PostmanMapper {

    mutating func environment(
        _ postman: PostmanEnvironment,
        avoiding existingNames: Set<String>
    ) -> WorkspaceEnvironment {
        var variables: [Variable] = []
        for value in postman.values {
            variables.append(variable(
                name: value.key,
                value: value.value,
                isSecret: value.isSecret,
                isEnabled: value.isEnabled
            ))
        }
        return WorkspaceEnvironment(
            name: ImportedName.unique(ImportedName.given(postman.name), avoiding: existingNames),
            variables: variables
        )
    }

    mutating func variables(_ postman: [PostmanVariable]) -> [Variable] {
        var variables: [Variable] = []
        for variable in postman {
            countDescription(variable.description)
            variables.append(self.variable(
                name: variable.key ?? variable.id ?? "",
                value: variable.value,
                isSecret: variable.type == "secret",
                isEnabled: variable.isEnabled
            ))
        }
        return variables
    }

    mutating func variable(name: String, value: PostmanValue?, isSecret: Bool, isEnabled: Bool) -> Variable {
        imported.variables += 1
        let text = value?.text
        let mapped: VariableValue = isSecret
            ? .secret(secret(text))
            : .plain(initial: text ?? "", current: text ?? "")

        return Variable(name: name, value: mapped, isEnabled: isEnabled)
    }

}
