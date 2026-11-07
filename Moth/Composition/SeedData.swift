//  SeedData.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
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
        let staging = WorkspaceEnvironment(
            id: identifier(12),
            name: "Staging",
            variables: ["host", "port", "scheme", "version", "region", "timeout"].enumerated().map { index, name in
                Variable(
                    id: identifier(13 + UInt8(index)),
                    name: name,
                    value: .plain(initial: "staging", current: "staging")
                )
            }
        )
        let admins = Folder(
            id: identifier(9),
            name: "Admins",
            children: [
                CollectionItem(
                    sortOrder: 0,
                    node: .request(Request(id: identifier(10), name: "Delete Admin", method: .delete))
                )
            ]
        )
        let users = Folder(
            id: identifier(6),
            name: "Users",
            children: [
                CollectionItem(
                    sortOrder: 0,
                    node: .request(listUsers)
                ),
                CollectionItem(
                    sortOrder: 1,
                    node: .request(Request(
                        id: identifier(7),
                        name: "Create User",
                        method: .post,
                        body: .formData([
                            FormDataField(id: identifier(26), key: "name", value: .text("Ada")),
                            FormDataField(id: identifier(27), key: "photo", value: .file(paths: ["/tmp/photo.png"]))
                        ])
                    ))
                ),
                CollectionItem(
                    sortOrder: 2,
                    node: .request(Request(
                        id: identifier(8),
                        name: "Update User",
                        method: .patch,
                        urlTemplate: "{{host}}/users/:id",
                        pathParameters: [KeyValue(id: identifier(25), key: "id", value: "42")],
                        body: .graphQL(query: "{ user { id } }", variables: ""),
                        auth: .digest(DigestAuth(
                            username: "ada",
                            password: SecretReference(identifier: "seeded-digest-password")
                        ))
                    ))
                ),
                CollectionItem(sortOrder: 3, node: .folder(admins))
            ]
        )
        let collection = RequestCollection(
            id: identifier(2),
            name: "Seeded Collection",
            variables: [
                Variable(id: identifier(19), name: "apiVersion", value: .plain(initial: "v1", current: "v1"))
            ],
            children: [
                CollectionItem(sortOrder: 0, node: .folder(users)),
                CollectionItem(sortOrder: 1, node: .request(Request(
                    id: identifier(11),
                    name: "Health",
                    body: .binary(filePath: "/tmp/health.bin"),
                    auth: .apiKey(APIKeyAuth(
                        name: "X-Key",
                        value: SecretReference(identifier: "seeded-api-key"),
                        location: .header
                    ))
                )))
            ]
        )

        return Workspace(
            id: identifier(1),
            collections: [collection],
            environments: [environment, staging],
            activeEnvironmentID: environment.id
        )
    }()

    /// Two domains, one holding two cookies, so the Cookies sheet can delete one cookie and one domain apart.
    static let cookies = [
        Cookie(
            name: "session",
            value: "seeded-session-value",
            domain: "api.example.com",
            isHostOnly: true,
            path: "/",
            expiresAt: nil,
            isSecure: true,
            isHTTPOnly: true,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        ),
        Cookie(
            name: "csrf",
            value: "seeded-csrf-value",
            domain: "api.example.com",
            isHostOnly: true,
            path: "/v1",
            expiresAt: Date(timeIntervalSince1970: 2_051_222_400),
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        ),
        Cookie(
            name: "theme",
            value: "seeded-theme-value",
            domain: "example.org",
            isHostOnly: false,
            path: "/",
            expiresAt: nil,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    ]

    private static let listUsers = Request(
        id: identifier(3),
        name: "List Users",
        urlTemplate: "{{host}}/users",
        queryParameters: [
            KeyValue(id: identifier(21), key: "limit", value: "10"),
            KeyValue(id: identifier(22), key: "offset", value: "0", isEnabled: false)
        ],
        headers: [
            KeyValue(id: identifier(23), key: "Accept", value: "application/json"),
            KeyValue(id: identifier(24), key: "X-Debug", value: "1", isEnabled: false)
        ]
    )

    private static func identifier(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }

}
