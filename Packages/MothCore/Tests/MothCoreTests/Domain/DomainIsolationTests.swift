//  DomainIsolationTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import MothCore
import Testing

struct DomainIsolationTests {

    private nonisolated static let reference = SecretReference(identifier: "isolation")

    @Test("Every domain type can be built, read, compared and hashed off the main actor")
    func domainTypesWorkOffTheMainActor() async {
        await verifyOffTheMainActor()
    }

    /// A type left on the main actor fails to compile here, which is what this test proves.
    @concurrent
    private func verifyOffTheMainActor() async {
        let auths = allAuthKinds()
        let bodies = allBodyKinds()
        let plain = Variable(name: "host", value: .plain(initial: "a", current: "b"))
        let secret = Variable(name: "apiKey", value: VariableValue.secret(Self.reference))
        var request = Request(
            name: "List Users",
            method: HTTPMethod(rawValue: "PROPFIND"),
            queryParameters: [KeyValue(key: "page", value: "1")],
            body: .raw(content: "{}", contentType: "application/json"),
            settings: RequestSettings(),
            variables: [plain]
        )
        request.method = .post
        let folder = Folder(name: "Users", children: [CollectionItem(sortOrder: 0, node: .request(request))])
        var collection = RequestCollection(name: "API")
        collection.setChildren([CollectionItem(sortOrder: 0, node: CollectionNode.folder(folder))])
        let environment = WorkspaceEnvironment(name: "Staging", variables: [plain, secret])
        let workspace = Workspace(collections: [collection], environments: [environment], globals: [secret])

        #expect(auths.count == 8)
        #expect(bodies.count == 6)
        #expect(secret.isSecret)
        #expect(plain.initialValue == "a")
        #expect(collection.children.first?.id == folder.id)
        #expect(Set([workspace, workspace]).count == 1)
    }

    private nonisolated func allAuthKinds() -> Set<Auth> {
        let oauth2 = OAuth2Auth(
            grantType: OAuth2GrantType.clientCredentials,
            authorizationURL: "",
            accessTokenURL: "",
            callbackURL: "",
            clientID: "",
            clientSecret: Self.reference,
            scope: "",
            username: "",
            password: Self.reference,
            accessToken: Self.reference,
            refreshToken: Self.reference
        )
        let sigV4 = AWSSigV4Auth(
            accessKeyID: Self.reference,
            secretAccessKey: Self.reference,
            sessionToken: Self.reference,
            region: "",
            service: ""
        )

        return [
            .inherit,
            .none,
            .basic(BasicAuth(username: "", password: Self.reference)),
            .bearer(BearerAuth(token: Self.reference)),
            .apiKey(APIKeyAuth(name: "", value: Self.reference, location: APIKeyLocation.header)),
            .digest(DigestAuth(username: "", password: Self.reference)),
            .oauth2(oauth2),
            .awsSigV4(sigV4)
        ]
    }

    private nonisolated func allBodyKinds() -> Set<RequestBody> {
        [
            .none,
            .formData([FormDataField(key: "", value: FormDataValue.text(""))]),
            .urlEncoded([KeyValue(key: "", value: "")]),
            .raw(content: "", contentType: ""),
            .binary(filePath: nil),
            .graphQL(query: "", variables: "")
        ]
    }

}
