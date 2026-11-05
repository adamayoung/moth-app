//  DomainFixtures.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import MothCore

/// Every case and every optional is populated, so a field the mapping drops fails a round trip.
nonisolated enum DomainFixtures {

    static let reference = SecretReference(identifier: "secret-reference")

    static let auths: [Auth] = [
        .inherit,
        .none,
        .basic(BasicAuth(username: "ada", password: reference)),
        .bearer(BearerAuth(token: reference)),
        .apiKey(APIKeyAuth(name: "X-Key", value: reference, location: .query)),
        .digest(DigestAuth(username: "ada", password: reference)),
        .oauth2(OAuth2Auth(
            grantType: .authorizationCodeWithPKCE,
            authorizationURL: "https://example.com/auth",
            accessTokenURL: "https://example.com/token",
            callbackURL: "moth://callback",
            clientID: "client",
            clientSecret: reference,
            scope: "read",
            username: "ada",
            password: reference,
            accessToken: reference,
            refreshToken: reference
        )),
        .awsSigV4(AWSSigV4Auth(
            accessKeyID: reference,
            secretAccessKey: reference,
            sessionToken: reference,
            region: "eu-west-2",
            service: "s3"
        ))
    ]

    static let bodies: [RequestBody] = [
        .none,
        .formData([
            FormDataField(key: "name", value: .text("Ada"), contentType: "text/plain", isEnabled: false),
            FormDataField(key: "photo", value: .file(paths: ["/tmp/a.png", "/tmp/b.png"]))
        ]),
        .urlEncoded([KeyValue(key: "page", value: "1", isEnabled: false)]),
        .raw(content: "{}", contentType: "application/json"),
        .binary(filePath: "/tmp/a.bin"),
        .binary(filePath: nil),
        .graphQL(query: "{ me }", variables: "{}")
    ]

    static let variableValues: [VariableValue] = [
        .plain(initial: "a", current: "b"),
        .secret(reference)
    ]

    static func request(
        named name: String = "List Users",
        auth: Auth = .inherit,
        body: RequestBody = .none
    ) -> Request {
        Request(
            name: name,
            method: HTTPMethod(rawValue: "PROPFIND"),
            urlTemplate: "{{host}}/users/:id",
            queryParameters: [KeyValue(key: "page", value: "1", isEnabled: false)],
            pathParameters: [KeyValue(key: "id", value: "7")],
            headers: [KeyValue(key: "Accept", value: "text/plain")],
            body: body,
            auth: auth,
            settings: RequestSettings(
                timeout: .seconds(5) + .milliseconds(250),
                followsRedirects: false,
                verifiesTLS: false
            ),
            variables: [variable(named: "id")]
        )
    }

    static func variable(named name: String) -> Variable {
        Variable(name: name, value: .plain(initial: "a", current: "b"), isEnabled: false)
    }

    static func collection(named name: String = "API") -> RequestCollection {
        let innerFolder = Folder(
            name: "Inner",
            auth: .bearer(BearerAuth(token: reference)),
            children: [CollectionItem(sortOrder: 4, node: .request(request(named: "Deep")))]
        )
        let folder = Folder(
            name: "Users",
            auth: .none,
            children: [
                CollectionItem(sortOrder: 2, node: .folder(innerFolder)),
                CollectionItem(sortOrder: 3, node: .request(request(named: "Nested", body: .raw(
                    content: "{}",
                    contentType: "application/json"
                ))))
            ]
        )
        return RequestCollection(
            name: name,
            auth: .basic(BasicAuth(username: "ada", password: reference)),
            variables: [
                variable(named: "first"),
                Variable(name: "second", value: .secret(reference))
            ],
            children: [
                CollectionItem(sortOrder: 0, node: .folder(folder)),
                CollectionItem(sortOrder: 1, node: .request(request(named: "Top")))
            ]
        )
    }

    static func environment(named name: String = "Staging") -> WorkspaceEnvironment {
        WorkspaceEnvironment(
            name: name,
            variables: [
                variable(named: "host"),
                Variable(name: "apiKey", value: .secret(reference))
            ]
        )
    }

    static func workspace() -> Workspace {
        let staging = environment(named: "Staging")
        return Workspace(
            collections: [collection(named: "First"), collection(named: "Second")],
            environments: [staging, environment(named: "Production")],
            globals: [variable(named: "global"), Variable(name: "globalKey", value: .secret(reference))],
            activeEnvironmentID: staging.id
        )
    }

    static func historyEntry() -> HistoryEntry {
        HistoryEntry(
            request: request(auth: .bearer(BearerAuth(token: reference))),
            sentAt: Date(timeIntervalSinceReferenceDate: 1000),
            duration: .seconds(1) + .nanoseconds(250),
            response: HistoryResponse(
                status: 201,
                headers: [KeyValue(key: "Content-Type", value: "text/plain")],
                body: Data("created".utf8)
            ),
            failure: "The connection was lost."
        )
    }

}
