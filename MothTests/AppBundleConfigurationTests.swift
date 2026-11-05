//  AppBundleConfigurationTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
import Testing

struct AppBundleConfigurationTests {

    private let appInfo = Bundle.main.infoDictionary ?? [:]

    @Test("The iCloud container comes from the build setting and is empty when none is configured")
    func iCloudContainerIsResolved() throws {
        let container = try #require(appInfo["MothICloudContainer"] as? String)

        #expect(container.isEmpty || container.hasPrefix("iCloud."))
    }

    @Test("App Transport Security allows plain-HTTP hosts")
    func appTransportSecurityAllowsPlainHTTP() throws {
        let transportSecurity = try #require(appInfo["NSAppTransportSecurity"] as? [String: Any])

        #expect(transportSecurity["NSAllowsArbitraryLoads"] as? Bool == true)
    }

    @Test("The development region is British English")
    func developmentRegionIsBritishEnglish() {
        #expect(appInfo["CFBundleDevelopmentRegion"] as? String == "en-GB")
    }

}
