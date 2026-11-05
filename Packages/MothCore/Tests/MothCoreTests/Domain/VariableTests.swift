//  VariableTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import MothCore
import Testing

struct VariableTests {

    @Test("A plain variable has both its values and is not secret")
    func plainVariableHasBothValues() {
        let variable = Variable(name: "host", value: .plain(initial: "example.com", current: "localhost"))

        #expect(variable.name == "host")
        #expect(variable.initialValue == "example.com")
        #expect(variable.currentValue == "localhost")
        #expect(!variable.isSecret)
        #expect(variable.secretReference == nil)
    }

    @Test("A new variable is enabled")
    func newVariableIsEnabled() {
        #expect(Variable(name: "host", value: .plain(initial: "", current: "")).isEnabled)
    }

    @Test("A disabled variable stays disabled")
    func disabledVariableStaysDisabled() {
        let variable = Variable(name: "host", value: .plain(initial: "", current: ""), isEnabled: false)

        #expect(!variable.isEnabled)
    }

    @Test("A secret variable holds its reference and carries no value")
    func secretVariableCarriesNoValue() {
        let reference = SecretReference(identifier: "api-key")

        let variable = Variable(name: "apiKey", value: .secret(reference))

        #expect(variable.isSecret)
        #expect(variable.secretReference == reference)
        #expect(variable.initialValue == nil)
        #expect(variable.currentValue == nil)
    }

    @Test("Turning a plain variable into a secret drops its values")
    func becomingSecretDropsTheValues() {
        var variable = Variable(name: "apiKey", value: .plain(initial: "s3cret", current: "s3cret"))

        variable.value = .secret(SecretReference())

        #expect(variable.initialValue == nil)
        #expect(variable.currentValue == nil)
    }

}
