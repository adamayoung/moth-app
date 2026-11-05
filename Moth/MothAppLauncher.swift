//  MothAppLauncher.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftUI

@main
enum MothAppLauncher {

    static func main() {
        switch DependencyProvider.current.launchMode {
        case .testHost: TestHostApp.main()
        case .live, .uiTesting, .demo: MothApp.main()
        }
    }

    static func resolveLaunchMode() -> AppLaunchMode {
        let process = ProcessInfo.processInfo
        do {
            return try AppLaunchMode(
                arguments: process.arguments,
                defaults: .standard,
                environment: process.environment
            )
        } catch {
            stopLaunch(error)
        }
    }

    /// `fatalError` would leave a crash dialog on screen, which blocks every UI test run on the machine.
    private static func stopLaunch(_ error: LaunchConfigurationError) -> Never {
        FileHandle.standardError.write(Data("Moth: \(error.message)\n".utf8))
        exit(EX_USAGE)
    }

}
