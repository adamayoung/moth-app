//  AppBundleConfigurationTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
import Testing

struct AppBundleConfigurationTests {

    private let appInfo = Bundle.main.infoDictionary ?? [:]

    @Test
    func `The iCloud container comes from the build setting and is empty when none is configured`() throws {
        let container = try #require(appInfo["MothICloudContainer"] as? String)

        #expect(container.isEmpty || container.hasPrefix("iCloud."))
    }

    @Test
    func `App Transport Security allows plain-HTTP hosts`() throws {
        let transportSecurity = try #require(appInfo["NSAppTransportSecurity"] as? [String: Any])

        #expect(transportSecurity["NSAllowsArbitraryLoads"] as? Bool == true)
    }

    @Test
    func `The development region is British English`() {
        #expect(appInfo["CFBundleDevelopmentRegion"] as? String == "en-GB")
    }

}
