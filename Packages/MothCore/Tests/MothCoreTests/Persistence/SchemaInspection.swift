//  SchemaInspection.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import SwiftData

enum SchemaInspection {

    /// Leaves out `defaultValue`, because a `UUID()` default is a new value on each read.
    static func fingerprint(of schema: Schema) -> String {
        let lines = schema.entities.flatMap { entity in
            attributeLines(of: entity) + relationshipLines(of: entity)
        }
        return (["version \(schema.version)"] + lines.sorted()).joined(separator: "\n")
    }

    static func cloudKitViolations(in schema: Schema) -> [String] {
        schema.entities
            .flatMap { attributeViolations(in: $0) + relationshipViolations(in: $0) }
            .sorted()
    }

    private static func attributeLines(of entity: Schema.Entity) -> [String] {
        entity.attributes.map { attribute in
            let options = attribute.options.isEmpty ? "" : " \(attribute.options)"
            return "\(entity.name).\(attribute.name): \(attribute.valueType)\(options)"
        }
    }

    private static func relationshipLines(of entity: Schema.Entity) -> [String] {
        entity.relationships.map { relationship in
            let cardinality = relationship.isToOneRelationship ? "to-one" : "to-many"
            let inverse = relationship.inverseName ?? "none"
            return "\(entity.name).\(relationship.name) -> \(relationship.destination) "
                + "\(cardinality) \(relationship.deleteRule) inverse \(inverse)"
        }
    }

    private static func attributeViolations(in entity: Schema.Entity) -> [String] {
        entity.attributes.flatMap { attribute in
            var violations: [String] = []
            if attribute.isUnique {
                violations.append("\(entity.name).\(attribute.name) is unique")
            }
            if !attribute.isOptional, attribute.defaultValue == nil {
                violations.append("\(entity.name).\(attribute.name) has no default")
            }
            return violations
        }
    }

    private static func relationshipViolations(in entity: Schema.Entity) -> [String] {
        entity.relationships.flatMap { relationship in
            var violations: [String] = []
            if !relationship.isOptional {
                violations.append("\(entity.name).\(relationship.name) is required")
            }
            if relationship.inverseName == nil {
                violations.append("\(entity.name).\(relationship.name) has no inverse")
            }
            if relationship.deleteRule == .deny {
                violations.append("\(entity.name).\(relationship.name) denies deletes")
            }
            return violations
        }
    }

}
