//  WorkspaceTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import MothCore
import Testing

struct WorkspaceTests {

    @Test("A new workspace is empty")
    func newWorkspaceIsEmpty() {
        let workspace = Workspace()

        #expect(workspace.collections.isEmpty)
        #expect(workspace.environments.isEmpty)
        #expect(workspace.globals.isEmpty)
    }

    @Test("A workspace holds its collections, environments and globals")
    func holdsItsContents() {
        let collection = RequestCollection(name: "API")
        let variable = Variable(name: "host", value: .plain(initial: "a", current: "b"))
        let environment = WorkspaceEnvironment(name: "Staging", variables: [variable])
        let global = Variable(name: "region", value: .plain(initial: "eu", current: "eu"))

        let workspace = Workspace(collections: [collection], environments: [environment], globals: [global])

        #expect(workspace.collections == [collection])
        #expect(workspace.environments == [environment])
        #expect(workspace.globals == [global])
    }

    @Test("An environment keeps its name and variables in order")
    func environmentKeepsItsVariables() {
        let first = Variable(name: "host", value: .plain(initial: "a", current: "b"))
        let second = Variable(name: "apiKey", value: .secret(SecretReference()))

        let environment = WorkspaceEnvironment(name: "Staging", variables: [first, second])

        #expect(environment.name == "Staging")
        #expect(environment.variables == [first, second])
    }

    @Test("A new environment has no variables")
    func newEnvironmentIsEmpty() {
        #expect(WorkspaceEnvironment(name: "Staging").variables.isEmpty)
    }

}
