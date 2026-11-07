//  RequestResponsesCookieTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import Testing

@MainActor
struct RequestResponsesCookieTests: RequestResponsesTesting {

    @Test("A send uses the workspace's cookie jar, the one the Cookies sheet shows")
    func sendsWithTheWorkspacesJar() async throws {
        let transport = RecordingHTTPTransport()
        let request = Request(name: "List", urlTemplate: "https://example.com")
        let (dataModel, responses, tree) = try responses(holding: request, through: transport)

        await responses.send(request.id, draft: RequestDraft(request), tree: tree).value

        let jar = try #require(transport.cookieJars.first as? WorkspaceCookieJar)
        #expect(jar.workspaceID == dataModel.workspaceID)
    }

}
