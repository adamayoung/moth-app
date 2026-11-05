//  RequestTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import MothCore
import Testing

struct RequestTests {

    @Test("A new request is GET with no body, inherited auth, 60 seconds, redirects followed and TLS verified")
    func newRequestDefaults() {
        let request = Request(name: "List Users")

        #expect(request.name == "List Users")
        #expect(request.method == .get)
        #expect(request.body == .none)
        #expect(request.auth == .inherit)
        #expect(request.settings.timeout == .seconds(60))
        #expect(request.settings.followsRedirects)
        #expect(request.settings.verifiesTLS)
    }

    @Test("A new request has no URL, parameters, headers or variables")
    func newRequestIsEmpty() {
        let request = Request(name: "List Users")

        #expect(request.urlTemplate.isEmpty)
        #expect(request.queryParameters.isEmpty)
        #expect(request.pathParameters.isEmpty)
        #expect(request.headers.isEmpty)
        #expect(request.variables.isEmpty)
    }

    @Test("A request keeps a custom method")
    func keepsACustomMethod() {
        let request = Request(name: "Find", method: HTTPMethod(rawValue: "PROPFIND"))

        #expect(request.method.rawValue == "PROPFIND")
    }

    @Test("A URL template keeps its variables and path parameters as written")
    func keepsTheURLTemplateAsWritten() {
        let request = Request(name: "Get User", urlTemplate: "{{host}}/users/:id")

        #expect(request.urlTemplate == "{{host}}/users/:id")
    }

    @Test("A request keeps its query and path parameters")
    func keepsItsParameters() {
        let query = KeyValue(key: "page", value: "1", isEnabled: false)
        let path = KeyValue(key: "id", value: "42")

        let request = Request(name: "Get User", queryParameters: [query], pathParameters: [path])

        #expect(request.queryParameters == [query])
        #expect(request.pathParameters == [path])
    }

    @Test("Repeated header names are both kept, in order")
    func keepsRepeatedHeaders() {
        let first = KeyValue(key: "Accept", value: "text/plain")
        let second = KeyValue(key: "Accept", value: "text/html", isEnabled: false)

        let request = Request(name: "Get User", headers: [first, second])

        #expect(request.headers == [first, second])
    }

    @Test("A request keeps its body, auth, settings and variables")
    func keepsItsBodyAuthSettingsAndVariables() {
        let variable = Variable(name: "id", value: .plain(initial: "1", current: "2"))
        let settings = RequestSettings(timeout: .seconds(5), followsRedirects: false, verifiesTLS: false)
        let auth = Auth.bearer(BearerAuth(token: SecretReference()))
        let body = RequestBody.raw(content: "{}", contentType: "application/json")

        let request = Request(name: "Get User", body: body, auth: auth, settings: settings, variables: [variable])

        #expect(request.body == body)
        #expect(request.auth == auth)
        #expect(request.settings == settings)
        #expect(request.variables == [variable])
    }

}
