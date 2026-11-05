//  SeedData.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore

/// Fixed identifiers and names, so a UI test can rely on them. `MothUITests` mirrors what it uses by hand.
enum SeedData {

    static let workspace: Workspace = {
        let environment = WorkspaceEnvironment(
            id: identifier(4),
            name: "Seeded Environment",
            variables: [
                Variable(
                    id: identifier(5),
                    name: "host",
                    value: .plain(initial: "https://example.com", current: "https://example.com")
                )
            ]
        )
        let request = Request(id: identifier(3), name: "List Users", urlTemplate: "{{host}}/users")
        let collection = RequestCollection(
            id: identifier(2),
            name: "Seeded Collection",
            children: [CollectionItem(sortOrder: 0, node: .request(request))]
        )

        return Workspace(
            id: identifier(1),
            collections: [collection],
            environments: [environment],
            activeEnvironmentID: environment.id
        )
    }()

    private static func identifier(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }

}
